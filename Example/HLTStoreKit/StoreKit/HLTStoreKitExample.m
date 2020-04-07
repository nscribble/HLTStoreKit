//
//  HLTStoreKitExample.m
//  HLTStoreKit_Example
//
//  Created by nscribble on 03/18/2019.
//  Copyright © 2019年 nscribble. All rights reserved.
//

#import "HLTStoreKitExample.h"
#import <HLTStoreKit/HLTStoreKit-umbrella.h>
#import "HLTNetwork.h"

@implementation HLTStoreKitExample

+ (void)setupStoreKit {
    // 日志
    [HLTStoreKit setLogger:^(NSDictionary * _Nonnull params, NSString * _Nonnull format, ...) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@", message);
    }];
    
    // 定制 订单生成、订单校验逻辑（也可自定义实现几个相关协议）
    [self setupOrderGeneratorProcessing];
    [self setupOrderVerifierProcessing];
    
    [[HLTStoreKit defaultStore] setOrderGenerator:[HLTOrderDefaultGenerator new]];
    [[HLTStoreKit defaultStore] setOrderVerifier:[HLTOrderDefaultVerifier new]];
    [[HLTStoreKit defaultStore] setOrderPersistence:[HLTOrderKeychainStore new]];
    
    // 清理异常数据 && 适配旧版数据
    [self clearInvalidOrders];
    [self mergeOldVersionRecords];
}

+ (void)clearInvalidOrders {
    NSArray<HLTOrderModel *> *orders =
    [[HLTStoreKit defaultStore].orderPersistence getPendingOrderList];
    HLTLog(@"PendingOrderList: %@", orders);
    
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.orderStatus < HLTOrderStatusPurchasing) {// 无效订单
            [[HLTStoreKit defaultStore].orderPersistence removeOrder:obj];
        }
        else if (obj.orderStatus < HLTOrderStatusPurchased &&// 移到备份队列
                 ![[HLTPaymentQueue defaultQueue] isPaymentOrderInTask:obj]) {
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
        
        [HLTNetwork createOrder:request completion:^(HLTOrderModel * _Nullable order, NSError * _Nullable error) {
            //iapInfo.ssn = order.orderId; //todo:
            if (completion) {
                completion(request, order, error);
            }
        }];
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
        
        [HLTNetwork verifyOrder:order completion:^(HLTOrderModel * _Nonnull order, NSError * _Nonnull error) {
            BOOL success = (error == nil);
            if (completion) {
                completion(request, success, error);
            }
        }];
    }];
}

@end
