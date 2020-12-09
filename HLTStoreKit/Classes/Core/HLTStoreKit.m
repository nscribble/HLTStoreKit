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
#import "HLTPrefetchProductsTask.h"
#import "HLTRefreshReceiptTask.h"
#import "NSObject+Ext.h"
#import "HLTStoreKitVersion.h"

#ifndef HLTStoreKitVersion
#define HLTStoreKitVersion @"0.8.4"
#endif

@import StoreKit;

@interface HLTStoreKit ()
<
HLTAppleProductProvider
>

@property (nonatomic, strong) NSMutableDictionary<NSString *, SKProduct *> *id2Products;

@property (nonatomic, strong) NSMutableArray<HLTProductRequestCompletion> *fetchCallbacks;

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

+ (NSString *)sdkVersion {
    return HLTStoreKitVersion;
}

#pragma mark -

- (NSMutableDictionary<NSString *,SKProduct *> *)id2Products{
    if (!_id2Products) {
        _id2Products = [NSMutableDictionary dictionary];
    }
    
    return _id2Products;
}

- (NSMutableArray<HLTProductRequestCompletion> *)fetchCallbacks {
    if (!_fetchCallbacks) {
        _fetchCallbacks = [NSMutableArray array];
    }
    
    return _fetchCallbacks;
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
    
#if DEBUG
    [[HLTPaymentQueue defaultQueue] setTaskConcurrentCount:3];
#endif
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
    
    if (!transaction.transactionReceipt) {
        HLTLog(@"transactionReceipt is nil");
    }
    
    [self __tryRetrievalOrder:order transaction:transaction];
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

#pragma mark - Payment

- (SKProduct *)productForIdentifier:(NSString *)identifier {
    if (![identifier isKindOfClass:[NSString class]] ||
        identifier.length <= 0) {
        return nil;
    }
    
    return self.id2Products[identifier];
}

- (void)prefetchProducts:(NSArray<NSString *> *)productIdentifiers {
    [self fetchProducts:productIdentifiers completion:NULL];
}

/// 预获取商品信息
/// @param productIdentifiers 商品id列表
- (void)fetchProducts:(NSArray<NSString *> *)productIdentifiers
           completion:(HLTProductRequestCompletion)completion {
    if (productIdentifiers.count <= 0) {
        HLTLog(@"productIds.count = 0");
        !completion ?: completion(nil, nil);
        return;
    }
    
    NSMutableArray *matched = [NSMutableArray array];
    NSMutableArray *filtered = [NSMutableArray array];
    [productIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.id2Products[obj]) {
            [matched addObject:self.id2Products[obj]];
            return;
        }
        
        [filtered addObject:obj];
    }];
    
    if (filtered.count <= 0) {
        HLTLog(@"filtered productIds.count = 0");
        !completion ?: completion(matched, nil);
        return;
    }
    
    // 暂存 callbacks
    if (completion) {
        NSMutableArray *callbacks = [self.fetchCallbacks mutableCopy];
        [callbacks addObject:completion];
        self.fetchCallbacks = callbacks;
    }
    
    HLTPrefetchProductsTask *task = [[HLTPrefetchProductsTask alloc] initWithProductIdentifiers:productIdentifiers completion:^(NSArray<SKProduct *> *products, NSError *error) {
        if (products.count > 0) {
            [products enumerateObjectsUsingBlock:^(SKProduct * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                self.id2Products[obj.productIdentifier] = obj;
            }];
        }
        
        [self.fetchCallbacks enumerateObjectsUsingBlock:^(HLTProductRequestCompletion  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj(products, error);
        }];
    }];
    
    [[HLTPaymentQueue defaultQueue] addFetchTask:task];
}

- (void)purchase:(NSString *)productId configuration:(HLTOrderConfigurationBlock)configuration completion:(HLTPaymentCompletion)completion {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_PurchaseStart,
                   @"productId": (productId ?: @"productIdNil")
                   }, @"[Store] purchase: %@", productId);
    if (![SKPaymentQueue canMakePayments]) {
        if (completion) {
            NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCanNotMakePayment
                                              description:@"设备不支持应用内购买"];
            completion(productId, nil, err);
        }
        return;
    }
    
    HLTPaymentTask *task = [[HLTPaymentTask alloc] initWithProductId:productId completion:completion];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    task.productProvider = self;
    
    if (configuration) {
        configuration(task);
    }
    
    HLTPaymentTask *ongoingTask = [self ongoingPaymentTaskForProductId:productId];
    if (ongoingTask) {
        NSString *desc = ongoingTask.skProduct.localizedTitle;
        if (self.confirmOnGoingTask) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.confirmOnGoingTask(productId, desc, ^(BOOL confirmed) {
                    if (confirmed) {
                        [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
                    }
                });
            });
            return;
        }
    }
    
    NSInteger failedCount = [[NSUserDefaults standardUserDefaults] integerForKey:HLTStorageTransactionFailedCountKey];
    if (failedCount > 3) {
        HLTLog(@"暂停使用applicationUsername");
        [[HLTPaymentQueue defaultQueue] disableApplicationUsername:YES];
    }
    
    if (failedCount > 5) {
        HLTLog(@"failedCount > 5，尝试刷新receipts");
//        [self refreshPaymentReceipts:^(NSError *error, NSURL *receiptURL) {
//            [[HLTPaymentQueue defaultQueue] disableApplicationUsername:NO];
//        }];
    }
    
    HLTPaymentQueue *queue = [HLTPaymentQueue defaultQueue];
    if (queue.paymentTasksOnGoing.count >= queue.taskMaxConcurrentCount) {
        HLTLog(@"当前有支付任务，已提交，请耐心等候！");
    }
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

- (HLTPaymentTask *)ongoingPaymentTaskForProductId:(NSString *)productId {
    NSArray<HLTPaymentTask *> *paymentTasks = [[HLTPaymentQueue defaultQueue] paymentTasksOnGoing];
    paymentTasks = [paymentTasks filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLTPaymentTask *  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject.productId isEqual:productId];
    }]];
    if (paymentTasks.count > 0) {
        HLTLog(@"ongoingPaymentTaskForProductId(%@): %@", productId, paymentTasks);
    }
    
    return paymentTasks.lastObject;
}

- (void)tryRetrievalOrder:(HLTOrderModel *)order {
    if ([[HLTPaymentQueue defaultQueue] isOrderAlreadyInTask:order]) {
        HLTLog(@"[Store] to retrieved order is already in task!");
        return;
    }
    
    HLTRetrievalTask *task = [[HLTRetrievalTask alloc] initWithOrder:order skTransaction:nil completion:^(NSString *productId, NSString *orderId, NSError *error) {
        HLTLog(@"丢单恢复流程结束: %@ | %@ | %@", productId, orderId, error);
    }];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    task.productProvider = self;
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

- (void)__tryRetrievalOrder:(HLTOrderModel *)order transaction:(SKPaymentTransaction *)transaction {
    HLTRetrievalTask *task = [[HLTRetrievalTask alloc] initWithOrder:order skTransaction:transaction completion:^(NSString *productId, NSString *orderId, NSError *error) {
        HLTLog(@"恢复丢单/续费订阅 订单流程结束: %@ | %@ | %@", productId, orderId, error);
    }];
    task.orderGenerator = self.orderGenerator;
    task.orderVerifier = self.orderVerifier;
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
}

#pragma mark -

- (void)restoreTransactions {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)refreshPaymentReceipts:(HLTReceiptRefreshCompletion)completion {
    NSTimeInterval lastTime = [[NSUserDefaults standardUserDefaults] doubleForKey:@"hlt.rcpt.refresh.time"];
    if ([[NSDate date] timeIntervalSince1970] - lastTime < 5 * 60) {
        HLTLog(@"refreshPaymentReceipts cancel! lastTime: %@", @(lastTime));
        !completion ?: completion(nil, nil);
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970]
                                              forKey:@"hlt.rcpt.refresh.time"];
    HLTRefreshReceiptTask *task = [[HLTRefreshReceiptTask alloc] initWithCompletion:completion];
    [[HLTPaymentQueue defaultQueue] addFetchTask:task];
}

#pragma mark - HLTAppleProductProvider

- (void)fetchProductOfIdentifier:(NSString *)identifier completion:(nonnull void (^)(SKProduct * _Nullable, NSError * _Nullable))completion {
    if (![identifier isKindOfClass:[NSString class]] ||
        identifier.length <= 0) {
        NSError *error = [self ht_storeKitErrorWithCode:HLTPaymentErrorProductIdInvalid
                                            description:@"商品信息有误"];
        !completion ?: completion(nil, error);
        
        return;
    }
    
    SKProduct *product = [self productForIdentifier:identifier];
    if (product) {
        !completion ?: completion(product, nil);
        return;
    }
    
    [self fetchProducts:@[identifier] completion:^(NSArray<SKProduct *> *products, NSError *error) {
        !completion ?: completion(products.lastObject, error);
    }];
}

@end
