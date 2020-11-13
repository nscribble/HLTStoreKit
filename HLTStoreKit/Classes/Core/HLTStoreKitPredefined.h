//
//  HLTStoreKitPredefined.h
//  Pods
//
//  Created by nscribble on 2018/5/22.
//

#ifndef HLTStoreKitPredefined_h
#define HLTStoreKitPredefined_h

@class SKProduct, SKPaymentTransaction;
@class HLTPaymentTask;
@class HLTOrderModel;
@protocol HLTOrderConfiguration;

extern NSString * const HLTStoreKitErrorDomain;
extern NSString * const HLTLogEventKey;// value: String
extern NSString * const HLTLogErrCodeKey;// value: String
extern NSString * const HLTLogErrorKey;// value: NSError

extern void (^__HLTStoreKitLogger)(NSDictionary *params, NSString *format, ...);
#define HLTLog(format, ...) {\
    if (NULL != __HLTStoreKitLogger) {\
        __HLTStoreKitLogger(@{}, format, ## __VA_ARGS__);\
    }\
}

#define HLTLogParams(params, format, ...) {\
    if (NULL != __HLTStoreKitLogger) {\
        __HLTStoreKitLogger(params, format, ## __VA_ARGS__);\
    }\
}

static NSString * const kLogEvent_PurchaseStart    = @"iap_purchase_start";
static NSString * const kLogEvent_SKProductSuccess = @"iap_product_success";
static NSString * const kLogEvent_SKProductNotFound= @"iap_product_not_found";
static NSString * const kLogEvent_SKProductFailed  = @"iap_product_failed";
static NSString * const kLogEvent_OrderSuccess     = @"iap_order_success";
static NSString * const kLogEvent_OrderFailed      = @"iap_order_failed";
//static NSString * const kLogEvent_OrderError       = @"iap_order_error";
static NSString * const kLogEvent_OrderNotFound        = @"iap_order_notfound";
static NSString * const kLogEvent_SKTransaction_Update    = @"iap_transaction_update";
static NSString * const kLogEvent_SKPaymentSuccess = @"iap_payment_success";
static NSString * const kLogEvent_SKPaymentNoTask  = @"iap_payment_notask";
static NSString * const kLogEvent_SKPaymentFailed  = @"iap_payment_failed";
static NSString * const kLogEvent_VerifySuccess    = @"iap_verify_success";
static NSString * const kLogEvent_VerifyFailed     = @"iap_verify_failed";

//#define HLTLog NSLog

// 交易配置
typedef void(^HLTOrderConfigurationBlock)(id<HLTOrderConfiguration> configuration);
// 交易结束回调
typedef void(^HLTPaymentCompletion)(NSString *productId, NSString *orderId, NSError *error);
// 查询商品信息回调
typedef void(^HLTProductRequestCompletion)(NSString *productId, NSArray<SKProduct *> *, NSError *error);

typedef NS_ENUM(NSInteger, HLTPaymentErrorCode) {
    HLTPaymentErrorNone,
    HLTPaymentErrorNoNetwork,
    HLTPaymentErrorCantMakePayment,
    HLTPaymentErrorProductInvalid,
    HLTPaymentErrorProductNotFound,
    HLTPaymentErrorCreateOrderFailed,
    HLTPaymentErrorIAPTransactionFailed,
    HLTPaymentErrorVerifyOrderFailed,
};

// 任务状态
typedef NS_ENUM(NSInteger, HLTTaskStatus) {
    HLTTaskStatusPrepare,
    HLTTaskStatusOrderPreparing,
    HLTTaskStatusInTransaction,
    HLTTaskStatusOrderVerifying,
    HLTTaskStatusFailed,
    HLTTaskStatusSuccess,
};

// 订单状态（更细化）
typedef NS_ENUM(NSInteger, HLTOrderStatus) {
    HLTOrderStatusPrepare           = 0b0000, // 就绪
    HLTOrderStatusOrderCreating     = 0b0001, // 请求创建订单
    HLTOrderStatusOrderFailed       = 0b0010, // 订单创建失败
    HLTOrderStatusOrderCreated      = 0b0011, // 订单创建成功
    HLTOrderStatusPurchasing        = 0b0101, // IAP交易中
    HLTOrderStatusPurchaseFailed    = 0b0110, // IAP交易失败
    HLTOrderStatusPurchased         = 0b0111, // IAP交易成功
    HLTOrderStatusReceiptVerifying  = 0b1001, // 订单验证中
    HLTOrderStatusReceiptFailed     = 0b1010, // 订单验证失败
    HLTOrderStatusReceiptVerified   = 0b1011, // 订单验证成功
};

// 订单来源
typedef NS_ENUM(NSInteger, HLTOrderSource) {
    HLTOrderSourceUserInitiated,    // 用户发起
    HLTOrderSourcePendingQueue,     // 交易队列（持久化）
    HLTOrderSourceBackupQueue,      // 备份队列（持久化，原已失败）
    HLTOrderSourceRescueOnSite,     // 即时抢救
    HLTOrderSourceCustomQueue,      // 自定义队列
};

@protocol HLTOrderConfiguration <NSObject>

@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) NSObject *userInfoObject;

@end

// 订单创建
@protocol HLTOrderGenerator <NSObject>

- (void)generateOrder:(HLTOrderModel *)voidOrder
              success:(void (^)(HLTOrderModel *order))successBlock
              failure:(void (^)(NSError *error))failureBlock;

@end

// 订单校验（本地）
@protocol HLTOrderVerifier <NSObject>

- (void)verifyOrder:(HLTOrderModel *)order
            success:(void (^)(HLTOrderModel *order))successBlock
            failure:(void (^)(NSError *error))failureBlock;

@end

// 订单数据持久化
@protocol HLTOrderPersistence <NSObject>
@optional

/**
 获取持久化缓存中队列中的订单列表（及备份订单--已结束的订单）
 @return 订单列表
 */
- (NSArray<HLTOrderModel *> *)getPendingOrderList;
- (NSArray<HLTOrderModel *> *)getBackedupOrderList;

- (NSArray<HLTOrderModel *> *)getOrderListInQueue:(NSString *)queue;
- (void)storeOrder:(HLTOrderModel *)order inQueue:(NSString *)queue;
- (void)removeOrder:(HLTOrderModel *)order inQueue:(NSString *)queue;

/**
 存储订单信息（包括更新）
 @param order 订单信息
 */
- (void)storeOrder:(HLTOrderModel *)order;

/**
 移除订单信息（todo：备份到本地协助处理异常情况）
 @param order 订单信息
 */
- (void)removeOrder:(HLTOrderModel *)order;//todo: 保存最后的order？

/**
 存储备份用订单信息（未成功订单）
 @param order 订单信息
 */
- (void)storeBackupOrder:(HLTOrderModel *)order;

/**
 移除备份用订单信息（如果成功）

 @param order 订单信息
 */
- (void)removeBackupOrder:(HLTOrderModel *)order;

@end

#endif /* HLTStoreKitPredefined_h */
