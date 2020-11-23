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

@import StoreKit;

@interface HLTStoreKit ()
<
HLTAppleProductProvider
>

@property (nonatomic, strong) NSMutableDictionary<NSString *, SKProduct *> *id2Products;

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

- (NSMutableDictionary<NSString *,SKProduct *> *)id2Products{
    if (!_id2Products) {
        _id2Products = [NSMutableDictionary dictionary];
    }
    
    return _id2Products;
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
    
    if (!transaction.transactionReceipt) {
        BOOL isReceiptUpToDate = NO;
        if (!isReceiptUpToDate) {
            [self refreshPaymentReceipts:^(NSError *error, NSURL *receiptURL) {
                [self __tryRetrievalOrder:order transaction:transaction];
            }];
            
            return;
        }
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

/// 预获取商品信息
/// @param productIdentifiers 商品id列表
- (void)fetchProducts:(NSArray<NSString *> *)productIdentifiers
           completion:(HLTProductRequestCompletion)completion {
    if (productIdentifiers.count <= 0) {
        HLTLog(@"productIds.count = 0");
        return;
    }
    
    NSMutableArray *filtered = [NSMutableArray array];
    [productIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.id2Products[obj]) {
            return;
        }
        
        [filtered addObject:obj];
    }];
    
    if (filtered.count <= 0) {
        HLTLog(@"filtered productIds.count = 0");
        return;
    }
    
    HLTPrefetchProductsTask *task = [[HLTPrefetchProductsTask alloc] initWithProductIdentifiers:productIdentifiers completion:^(NSArray<SKProduct *> *products, NSError *error) {
        if (products.count > 0) {
            [products enumerateObjectsUsingBlock:^(SKProduct * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                self.id2Products[obj.productIdentifier] = obj;
            }];
        }
        
        !completion ?: completion(products, error);
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
    
    [[HLTPaymentQueue defaultQueue] addPaymentTask:task];
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
