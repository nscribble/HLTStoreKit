//
//  HLTPaymentTask.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "HLTPaymentTask.h"
#import "SKProductsRequest+Ext.h"
#import "NSObject+Ext.h"
#import "NSError+Ext.h"
@import StoreKit;

NSString * const HLTStoreKitErrorDomain = @"com.hlt.storekit.error";

@interface HLTPaymentTask ()
<
SKProductsRequestDelegate
>

@property (nonatomic,assign,readwrite) NSTimeInterval startTime;
@property (nonatomic,strong,readwrite) HLTOrderModel *order;
@property (nonatomic,strong,readwrite,nullable) SKProduct *skProduct;
@property (nonatomic,strong) SKPaymentTransaction *transaction;

@property (nonatomic,copy) HLTPaymentCompletion completion;

@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;

@end

@implementation HLTPaymentTask
@synthesize finished = _finished, executing = _executing;

- (instancetype)initWithProductId:(NSString *)productId completion:(HLTPaymentCompletion)completion {
    if (self = [super init]) {
        _order = [[HLTOrderModel alloc] initWithProductId:productId];
        _completion = completion;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[Task][%@][%@][%@]", self.productId, self.order.orderId,self.order.orderStatusDescription];
}

- (NSString *)productId {
    return self.order.productId;
}

#pragma mark - Operation Override

- (void)start {
    @autoreleasepool {
        if (self.isCancelled) {
            self.finished = YES;
            return;
        }
        if (!self.isReady) {
            HLTLog(@"task is not ready");
            return;
        }
        
        [self startTask];
        self.executing = YES;
    }
}

- (void)cancel {
    [super cancel];
    
    if ([self.delegate respondsToSelector:@selector(taskDidCancel:)]) {
        [self.delegate taskDidCancel:self];
    }
    
    if (self.isExecuting) {
        self.finished = YES;
        self.executing = NO;
    }
}

// 这里需要实现KVO相关的方法，NSOperationQueue是通过KVO来判断任务状态的
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark Tasking

/**
 任务结束必须调用`finishTask`
 */
- (void)finishTask {
    HLTLog(@"[Payment] task finish: %@", self);
    if (self.isFinished && !self.executing) {
        HLTLog(@"Do not finishTask twice!");
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(taskDidFinish:)]) {
        [self.delegate taskDidFinish:self];
    }
    
    self.finished = YES;
    self.executing = NO;
}

- (void)startTask {
    HLTLog(@"%@ start", self);
    if (!self.productId) {
        [self callBackWithErrCode:HLTPaymentErrorProductInvalid description:@"未提供相应产品ID"];
        return;
    }
    
    // 任务开始
    //self.order = [HLTOrderModel new];// placeholder
    self.order.orderStatus = HLTOrderStatusPrepare;
    self.startTime = [[NSDate date] timeIntervalSince1970];
    if ([self.delegate respondsToSelector:@selector(taskWillStart:)]) {
        [self.delegate taskWillStart:self];
    }
    
    // 查询商品信息
    if ([self.delegate respondsToSelector:@selector(taskWillFetchProductInfo:)]) {
        [self.delegate taskWillFetchProductInfo:self];
    }
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:self.productId]];
    request.delegate = self;
    request.hlt_productIdentifier = self.productId;
    [request start];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.invalidProductIdentifiers.count > 0 &&
        [response.invalidProductIdentifiers containsObject:self.productId]) {
        [self callBackWithErrCode:HLTPaymentErrorProductInvalid
                      description:@"产品ID无效（App Store）"];
        return;
    }
    
    // 查询信息成功
    SKProduct *skProduct = [response.products lastObject];// 注：只查询了一个id
    self.skProduct = skProduct;
    if ([self.delegate respondsToSelector:@selector(taskDidFetchProductInfo:)]) {
        [self.delegate taskDidFetchProductInfo:self];
    }
    
    if (!skProduct) {
        HLTLogParams(@{HLTLogEventKey: kLogEvent_SKProductNotFound}, @"SKProductNotFound, invalid: %@, will use %@", response.invalidProductIdentifiers, self.productId);
    } else {
        HLTLogParams(@{HLTLogEventKey: kLogEvent_SKProductSuccess}, @"SKProductSuccess");
    }
    
    // 创建订单
    [self processToCreateOrder];
}

- (void)requestDidFinish:(SKRequest *)request {
    HLTLog(@"[Task] requestDidFinish: %@", request);
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKProductFailed,
                   HLTLogErrorKey: (error ?: @"errorNil"),
                   @"productId": (self.productId ?: @"productIdNil"),
                   }, @"[Task] %@ failed: %@", request, error);
    [self processToCreateOrder];
}

#pragma mark - Public

- (NSDictionary *)userInfo {
    return self.order.userInfo;
}

- (void)setUserInfo:(NSDictionary *)userInfo {
    self.order.userInfo = userInfo;
}

- (NSObject *)userInfoObject {
    return self.order.userInfoObject;
}

- (void)setUserInfoObject:(NSObject *)userInfoObject {
    self.order.userInfoObject = userInfoObject;
}

- (void)continueOnTransactionPurchasing:(SKPaymentTransaction *)transaction {
    self.taskStatus = HLTTaskStatusInTransaction;
    if (self.order.iapBeginTime <= 0) {
        self.order.iapBeginTime = [[NSDate date] timeIntervalSince1970];
    }
    self.order.orderStatus = HLTOrderStatusPurchasing;
    [self.order updateWithSKPaymentTransaction:transaction];
}

- (void)continueOnTransactionPurchased:(SKPaymentTransaction *)transaction {
    self.taskStatus = HLTTaskStatusOrderVerifying;
    if (self.order.iapFinishTime <= 0) {
        self.order.iapFinishTime = [[NSDate date] timeIntervalSince1970];
    }
    self.order.orderStatus = HLTOrderStatusPurchased;
    [self.order updateWithSKPaymentTransaction:transaction];
    
    [self processToVerifyOrder];
}

- (void)continueOnTransactionFailed:(SKPaymentTransaction *)transaction {
    self.taskStatus = HLTTaskStatusFailed;
    self.order.orderStatus = HLTOrderStatusPurchaseFailed;
    [self.order updateWithSKPaymentTransaction:transaction];
    
    [self callBackWithErrCode:HLTPaymentErrorIAPTransactionFailed
                  description:@"应用内购买失败"];
}

#pragma mark - Ordering Procedure
// 创建订单
- (void)processToCreateOrder {
    HLTLog(@"processToCreateOrder");
    self.taskStatus = HLTTaskStatusOrderPreparing;
    self.order.orderStatus = HLTOrderStatusOrderCreating;
    if ([self.delegate respondsToSelector:@selector(taskWillCreateOrder:)]) {
        [self.delegate taskWillCreateOrder:self];
    }
    
    NSAssert(self.orderGenerator != nil, @"orderGenerator MUST not be nil");
    if (self.orderGenerator == nil) {
        [self callBackWithErrCode:HLTPaymentErrorCreateOrderFailed description:@"尚未配置订单生成器"];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    HLTOrderModel *voidOrder = self.order;
    [self.orderGenerator generateOrder:voidOrder success:^(HLTOrderModel *order) {
        order.userIdentifier = order.userIdentifier ?: voidOrder.userIdentifier;// update with void order
        order.createdTime = voidOrder.createdTime;
        order.orderSource = voidOrder.orderSource;
        order.orderStatus = voidOrder.orderStatus;
        order.userInfo = voidOrder.userInfo;
        order.userInfoObject = voidOrder.userInfoObject;
        [weakSelf processOnOrderCreated:order];
    } failure:^(NSError *error) {
        [weakSelf failedOnCreatingOrder:error];
    }];
}

// 创建订单失败
- (void)failedOnCreatingOrder:(NSError *)error {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_OrderFailed,
                   HLTLogErrorKey: (error ?: @"errorNil"),
                   }, @"[Payment] Order(%@) failed: %@", self, error);
    self.order.orderStatus = HLTOrderStatusOrderFailed;
    
    if ([self.delegate respondsToSelector:@selector(taskCreateOrderFailed:)]) {
        [self.delegate taskCreateOrderFailed:self];
    }
    
    NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCreateOrderFailed
                                      description:@"创建订单失败"];
    [self callBackWithFatalError:[err errorWithUnderlying:error]];
}

// 创建订单成功
- (void)processOnOrderCreated:(HLTOrderModel *)orderModel {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_OrderSuccess,
                   @"orderId": (orderModel.orderId ?: @"orderIdNil")
                   }, @"[Payment] Order(%@) Success", self);
    self.order = orderModel;
    self.order.orderStatus = HLTOrderStatusOrderCreated;
    
    if ([self.delegate respondsToSelector:@selector(taskCreateOrderSuccess:)]) {
        [self.delegate taskCreateOrderSuccess:self];
    }
}

// 验证订单（凭据）
- (void)processToVerifyOrder {
    HLTLog(@"[Payment] processToVerifyOrder: %@", self.order);
    self.order.orderStatus = HLTOrderStatusReceiptVerifying;
    if ([self.delegate respondsToSelector:@selector(taskWillVerifyOrder:)]) {
        [self.delegate taskWillVerifyOrder:self];
    }
    
    NSAssert(self.orderVerifier != nil, @"orderVerifier should not be nil");
    if (self.orderVerifier == nil) {
        [self callBackWithErrCode:HLTPaymentErrorVerifyOrderFailed
                      description:@"尚未配置订单生成器"];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.orderVerifier verifyOrder:self.order success:^(HLTOrderModel *order) {
        [weakSelf processOnOrderVerified];
    } failure:^(NSError *error) {
        [weakSelf failedOnVerifyingOrder:error];
    }];
}

- (void)failedOnVerifyingOrder:(NSError *)error {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_VerifyFailed,
                   HLTLogErrorKey: (error ?: @"errorNil"),
                   @"orderId": (self.order.orderId ?: @"orderIdNil"),
                   }, @"[Payment] order(%@) verifying failed: %@", self.order, error);
    self.order.orderStatus = HLTOrderStatusReceiptFailed;
    self.order.receiptVerifyCount += 1;
    if ([self.delegate respondsToSelector:@selector(taskVerifyOrderFailed:)]) {
        [self.delegate taskVerifyOrderFailed:self];
    }
    
    NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorVerifyOrderFailed
                                      description:@"验证订单失败"];
    [self callBackWithFatalError:[err errorWithUnderlying:error]];
}

- (void)processOnOrderVerified {
    HLTLog(@"[Payment] order verified: %@", self.order);
    HLTLogParams(@{HLTLogEventKey: kLogEvent_VerifySuccess,
                   @"orderId": (self.order.orderId ?: @"orderIdNil")
                   }, @"[Payment] order verified: %@", self.order);
    self.order.orderStatus = HLTOrderStatusReceiptVerified;
    self.order.receiptVerifyCount += 1;
    if ([self.delegate respondsToSelector:@selector(taskVerifyOrderSuccess:)]) {
        [self.delegate taskVerifyOrderSuccess:self];
    }
    
    [self callBackSuccess];
}

#pragma mark - Callback

- (void)callBackWithErrCode:(HLTPaymentErrorCode)code description:(NSString *)description {
    NSError *error = [self ht_storeKitErrorWithCode:code
                                        description:(description ?: @"交易失败")];
    [self callBackWithFatalError:error];
}

- (void)callBackWithFatalError:(NSError *)error {
    HLTLog(@"[Task] payment failed: %@", error);
    if (self.completion) {
        self.completion(self.productId, self.order.orderId, error);
    }
    
    [self finishTask];
}

- (void)callBackSuccess {
    HLTLog(@"[Task] payment success: %@", self.order);
    if (self.completion) {
        self.completion(self.productId, self.order.orderId, nil);
    }
    
    [self finishTask];
}

@end
