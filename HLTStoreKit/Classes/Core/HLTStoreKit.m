//
//  HLTStoreKit.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "HLTStoreKit.h"
#import "HLTPaymentQueue.h"
#import "HLTPaymentTask.h"
#import "HLTRetrievalTask.h"
#import "NSObject+Ext.h"

@import StoreKit;

@interface HLTStoreKit ()

/**
 默认配置
 @note 默认配置了NSLog输出日志，配置了订单创建逻辑等。
 */
+ (void)setupDefaultConfiguration;

@end

void (^__HLTStoreKitLogger)(NSDictionary *params, NSString *format, ...);
NSString * const HLTLogEventKey = @"event";
NSString * const HLTLogErrorKey = @"error";
NSString * const HLTLogErrCodeKey = @"err_code";

@implementation HLTStoreKit

+ (instancetype)defaultStore {
    static HLTStoreKit *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self new];
    });
    
    return manager;
}

+ (void)initialize {
    [self setupDefaultConfiguration];
}

- (instancetype)init {
    if (self = [super init]) {
        [self addNotificationObservers];
    }
    
    return self;
}

#pragma mark -

// 默认配置
+ (void)setupDefaultConfiguration {
    [self setLogger:^(NSDictionary * _Nonnull params, NSString * _Nonnull format, ...) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@", message);
    }];
}

- (void)addNotificationObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:HLTReceiveTransactionWithNoTaskNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * _Nonnull note)
     {
         [self onNotifiedTransactionWithNoTask:note];
     }];
}

- (void)onNotifiedTransactionWithNoTask:(NSNotification *)notification {
    HLTLog(@"[Store] onTransactionNotified ButNoTask");
    SKPaymentTransaction *transaction = notification.object;
    HLTOrderModel *order = notification.userInfo[HLTReceiveTransactionOrderKey];
    if (![transaction isKindOfClass:[SKPaymentTransaction class]]) {
        HLTLog(@"note.object MUST be SKPaymentTransaction");
        return ;
    }
    if (![order isKindOfClass:[HLTOrderModel class]]) {
        HLTLog(@"order MUST be HLTOrderModel");
        return;
    }
    
    HLTRetrievalTask *task = [[HLTRetrievalTask alloc] initWithOrder:order skTransaction:transaction completion:^(NSString *productId, NSString *orderId, NSError *error) {
        HLTLog(@"恢复丢单 订单流程结束: %@ | %@ | %@", productId, orderId, error);
    }];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

#pragma mark - Public

- (NSTimeInterval)launchTime {
    return [HLTPaymentQueue defaultQueue].launchTime;
}

- (void)setOrderPersistence:(id<HLTOrderPersistence>)orderPersistence {
    _orderPersistence = orderPersistence;
    [HLTPaymentQueue defaultQueue].orderPersistence = orderPersistence;
}

+ (void)setLogger:(void (^)(NSDictionary * _Nonnull, NSString * _Nonnull, ...))logger {
    __HLTStoreKitLogger = logger;
}

- (void)startObservingTransaction {
    HLTLog(@"[Store] startObservingTransaction");
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[HLTPaymentQueue defaultQueue]];
}

- (void)stopObservingTransaction {
    HLTLog(@"[Store] stopObservingTransaction");
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:[HLTPaymentQueue defaultQueue]];
}

- (void)purchase:(NSString *)productId configuration:(HLTOrderConfigurationBlock)configuration completion:(HLTPaymentCompletion)completion {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_PurchaseStart,
                   @"productId": (productId ?: @"productIdNil")
                   }, @"[Store] purchase: %@", productId);
    if (![SKPaymentQueue canMakePayments]) {
        if (completion) {
            NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCantMakePayment
                                              description:@"设备不支持应用内购买"];
            completion(productId, nil, err);
        }
        return;
    }
    
    HLTPaymentTask *task = [[HLTPaymentTask alloc] initWithProductId:productId completion:completion];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    if (configuration) {
        configuration(task);
    }
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

- (void)tryRetrievalOrder:(HLTOrderModel *)order {
    if ([[HLTPaymentQueue defaultQueue] isPaymentOrderInTask:order]) {
        HLTLog(@"[Store] to retrieved order is already in task!");
        return;
    }
    
    HLTRetrievalTask *task = [[HLTRetrievalTask alloc] initWithOrder:order skTransaction:nil completion:^(NSString *productId, NSString *orderId, NSError *error) {
        HLTLog(@"丢单恢复流程结束: %@ | %@ | %@", productId, orderId, error);
    }];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

@end
