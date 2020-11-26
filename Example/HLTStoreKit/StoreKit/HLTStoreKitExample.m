//
//  HLTStoreKitExample.m
//  HLTStoreKit_Example
//
//  Created by nscribble on 03/18/2019.
//  Copyright © 2019年 nscribble. All rights reserved.
//

#import "HLTStoreKitExample.h"
#import <HLTStoreKit/HLTStoreKit.h>
#import <HLTStoreKit/HLTOrderDefaultGenerator.h>
#import <HLTStoreKit/HLTOrderDefaultVerifier.h>
#import <HLTStoreKit/HLTOrderKeychainStore.h>
#import <HLTStoreKit/HLTPaymentQueue.h>
#import "HLTNetwork.h"
#import "HLTLocalReceiptVerifier.h"

@interface NSDictionary (jsonTransfer)

//! 请留意，可能字典数值本身非合法JSON对象，而输出-[NSDictionary description];
- (NSString *)transferToString;

@end

@implementation NSDictionary (jsonTransfer)

- (NSString *)transferToString {
    if (![NSJSONSerialization isValidJSONObject:self]) {
        return [self description];
    }
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error: &error];
    NSMutableString *jsonString = @"".mutableCopy;
    if (jsonData) {
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding].mutableCopy;
        [jsonString replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, jsonString.length)];
        [jsonString replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, jsonString.length)];
    }
    return jsonString;
}

@end

@implementation HLTStoreKitExample

+ (void)setupStoreKit {
    // 日志
    [HLTStoreKit setLogger:^(NSDictionary * _Nonnull params, NSString * _Nonnull format, ...) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        NSString *event = params[HLTLogEventKey];
        NSMutableDictionary *paramsM = [params mutableCopy];
        [paramsM removeObjectForKey:HLTLogEventKey];
        [paramsM removeObjectForKey:HLTLogErrorKey];
        NSLog(@"%@%@, %@", (event ? [NSString stringWithFormat:@"[%@] ", event] : @""), message, [paramsM transferToString]);
    }];
    
    [[HLTStoreKit defaultStore] setConfirmOnGoingTask:^(NSString * _Nonnull productId, NSString * _Nonnull title, void (^ _Nonnull confirmCallback)(BOOL)) {
        NSString *productDesc = title.length ? [NSString stringWithFormat:@"（%@）", title] : @"";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"购买提示" message:[NSString stringWithFormat:@"已有相同商品%@正在购买，是否继续？", productDesc] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            !confirmCallback ?: confirmCallback(YES);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            !confirmCallback ?: confirmCallback(NO);
        }]];
        
        [[UIApplication sharedApplication].delegate.window.rootViewController presentViewController:alert animated:YES completion:NULL];
    }];
    
    // 定制 订单生成、订单校验逻辑（也可自定义实现几个相关协议）
    [self setupOrderGeneratorProcessing];
    [self setupOrderVerifierProcessing];
    
    [[HLTStoreKit defaultStore] setOrderGenerator:[HLTOrderDefaultGenerator new]];
    //[[HLTStoreKit defaultStore] setOrderVerifier:[HLTOrderDefaultVerifier new]];
    [[HLTStoreKit defaultStore] setOrderVerifier:[HLTLocalReceiptVerifier new]];
    [[HLTStoreKit defaultStore] setOrderPersistence:[HLTOrderKeychainStore new]];
    [[HLTStoreKit defaultStore] startObservingTransaction];
    
    [HLTLocalReceiptVerifier injectCertificate:[[NSBundle mainBundle] URLForResource:@"StoreKitTest" withExtension:@"cer"]];
    
    // 清理异常数据 && 适配旧版数据
    [self clearInvalidOrders];
    [self mergeOldVersionRecords];
    
    //[self clearAllCacheOrders];
}

+ (void)clearInvalidOrders {
    NSArray<HLTOrderModel *> *orders =
    [[HLTStoreKit defaultStore].orderPersistence getPendingOrderList];
    
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.orderStatus < HLTOrderStatusPurchasing) {// 无效订单
            [[HLTStoreKit defaultStore].orderPersistence removeOrder:obj];
        }
        else if (obj.orderStatus < HLTOrderStatusPurchased &&// 移到备份队列
                 ![[HLTPaymentQueue defaultQueue] isOrderAlreadyInTask:obj]) {
            [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:obj];
            [[HLTStoreKit defaultStore].orderPersistence removeOrder:obj];
        }
        else if (obj.orderStatus >= HLTOrderStatusPurchased) {
            if ((![obj isOrderIdValid]) &&
                obj.orderSource != HLTOrderSourceRescueOnSite) {// 正常订单不允许orderId为空
                [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:obj];
                [[HLTStoreKit defaultStore].orderPersistence removeOrder:obj];
            }
        }
    }];
    
    orders = [[HLTStoreKit defaultStore].orderPersistence getPendingOrderList];
    HLTLog(@"PendingOrderList（清理后）: %@", orders);
    
    orders = [[HLTStoreKit defaultStore].orderPersistence getBackedupOrderList];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.updateTime > 0 &&
            ([[NSDate date] timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:obj.updateTime]]) > 60 * 60 * 24 * 180) {// 180天未更新的订单清除
            [[HLTStoreKit defaultStore].orderPersistence removeBackupOrder:obj];
        }
    }];
}

+ (void)clearAllCacheOrders {
    NSArray<HLTOrderModel *> *orders =
    [[HLTStoreKit defaultStore].orderPersistence getPendingOrderList];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[HLTStoreKit defaultStore].orderPersistence removeOrder:obj];
    }];
    
    orders =
    [[HLTStoreKit defaultStore].orderPersistence getBackedupOrderList];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[HLTStoreKit defaultStore].orderPersistence removeBackupOrder:obj];
    }];
}

// 适配旧版数据
+ (void)mergeOldVersionRecords {
    {// 根据实际情况
        HLTOrderModel *order = [[HLTOrderModel alloc] initWithProductId:@""];
        order.orderSource = HLTOrderSourceRescueOnSite;
        order.orderId = @"";
        order.productId = @"";
        order.orderStatus = HLTOrderStatusPurchasing;
        order.userInfo = @{};// 额外信息（在订单校验中可用）
        
        HLTOrderTransaction *transaction = [[HLTOrderTransaction alloc] init];
        transaction.receiptData = [NSData data];//
        [order updateWithTransaction:transaction];
        
        [[HLTStoreKit defaultStore].orderPersistence storeOrder:order];
    }
}

#pragma mark -
// 适配订单创建逻辑
+ (void)setupOrderGeneratorProcessing {
    [HLTOrderDefaultGenerator setRequestProcessingBlock:^(HLTOrderGeneratorReq * _Nonnull request, HLTOrderGeneratorReqCompletion  _Nonnull completion) {
        NSString *productId = request.productId;
        HLTOrderModel *placeholder = request.voidOrder;
        if (!productId || !placeholder) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"com.yuehui.iap" code:-1000 userInfo:@{NSLocalizedDescriptionKey: @"没有足够的商品购买信息"}];
                completion(request, nil, error);
            }
            return ;
        }
        
        HLTOrderModel *order = [HLTOrderModel new];
        order.productId = request.productId;
        order.orderId = @"20210112dbgss1vo2vpp9jnqchgh";
        order.userIdentifier = @"-2623156657553671741";
        if (completion) {
            completion(request, order, nil);
        }
        
//        [HLTNetwork createOrder:request completion:^(HLTOrderModel * _Nullable order, NSError * _Nullable error) {
//            //iapInfo.ssn = order.orderId; //todo:
//            if (completion) {
//                completion(request, order, error);
//            }
//        }];
    }];
}

// 适配订单校验逻辑——
+ (void)setupOrderVerifierProcessing {
    [HLTOrderDefaultVerifier setRequestProcessingBlock:^(HLTOrderVerifierReq * _Nonnull request, HLTOrderVerifyCompletion  _Nonnull completion) {
        HLTOrderModel *order = request.order;
        if (!request.order) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"com.yuehui.iap" code:-1001 userInfo:@{NSLocalizedDescriptionKey: @"没有商品订单信息"}];
                completion(request, NO, error);
            }
            return ;
        }
        
        if (completion) {
            completion(request, YES, nil);
        }
        
//        [HLTNetwork verifyOrder:order completion:^(HLTOrderModel * _Nonnull order, NSError * _Nonnull error) {
//            BOOL success = (error == nil);
//            if (completion) {
//                completion(request, success, error);
//            }
//        }];
    }];
}

@end
