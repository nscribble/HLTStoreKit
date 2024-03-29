//
//  HLTPaymentQueue.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "HLTPaymentQueue.h"
#import "HLTPaymentTask.h"
#import "HLTRetrievalTask.h"
#import "HLTJailbreakDetect.h"
#import "HLTTaskTransactionMetrics.h"

@import StoreKit;

static NSString * const HLTTransactionUserIdKey = @"userId";
static NSString * const HLTTransactionOrderIdKey = @"orderId";
NSString * const HLTReceiveTransactionWithNoTaskNotification = @"com.storekit.transactionwithnotask";
NSString * const HLTReceiveTransactionOrderKey = @"order";

NSString * const HLTStorageTransactionFailedCountKey = @"hltstorekit_failed_count";

#pragma mark - HLTPaymentQueue

@interface HLTPaymentQueue ()
<
SKPaymentTransactionObserver,
SKRequestDelegate,
HLTPaymentTaskDelegate
>

// 任务队列
@property (nonatomic, strong) NSOperationQueue *taskQueue;
@property (nonatomic, strong) NSOperationQueue *fetchQueue;
// 当前任务
@property (nonatomic, strong) HLTPaymentTask *currentTask;
// 队列中任务列表（所有）
@property (nonatomic, strong) NSMutableArray<HLTPaymentTask *> *tasks;
@property (nonatomic, strong) NSMutableArray<HLTPaymentTask *> *onGoingTasks;

@property (nonatomic, strong) NSMutableDictionary<NSString *, HLTTaskTransactionMetrics *> *id2TaskMetrics;

// (队列)启动时间
@property (nonatomic, assign, readwrite) NSTimeInterval launchTime;

// 不使用applicationUserName来做交易
@property (nonatomic, assign) BOOL doNotUseApplicationUsername;

@end

@implementation HLTPaymentQueue

+ (instancetype)defaultQueue {
    static HLTPaymentQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [self new];
    });
    
    return queue;
}


- (instancetype)init {
    if (self = [super init]) {
        _launchTime = [[NSDate date] timeIntervalSince1970];
    }
    
    return self;
}

- (NSOperationQueue *)taskQueue {
    if (!_taskQueue) {
        _taskQueue = [[NSOperationQueue alloc] init];
        _taskQueue.name = @"com.hltstorekit.taskqueue";
        _taskQueue.maxConcurrentOperationCount = 1;
        _taskQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    
    return _taskQueue;
}

- (NSOperationQueue *)fetchQueue {
    if (!_fetchQueue) {
        _fetchQueue = [[NSOperationQueue alloc] init];
        _fetchQueue.name = @"com.hltstorekit.fetchqueue";
        _fetchQueue.maxConcurrentOperationCount = 5;
        _fetchQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    }
    
    return _fetchQueue;
}

- (NSMutableArray<HLTPaymentTask *> *)tasks {
    if (!_tasks) {
        _tasks = [NSMutableArray<HLTPaymentTask *> array];
    }
    
    return _tasks;
}

- (NSMutableArray<HLTPaymentTask *> *)onGoingTasks {
    if (!_onGoingTasks) {
        _onGoingTasks = [NSMutableArray<HLTPaymentTask *> array];
    }
    
    return _onGoingTasks;
}

- (NSMutableDictionary<NSString *,HLTTaskTransactionMetrics *> *)id2TaskMetrics {
    if (!_id2TaskMetrics) {
        _id2TaskMetrics = [NSMutableDictionary dictionary];
    }
    
    return _id2TaskMetrics;
}

//- (HLTPaymentTask *)currentTask {
//    return self.onGoingTasks.lastObject;
//}

#pragma mark - Public

- (void)setTaskConcurrentCount:(NSInteger)count {
    NSAssert(count > 0, @"count must > 0");
    HLTLog(@"[Task] maxConcurrentCount: %@", @(count));
    self.taskQueue.maxConcurrentOperationCount = count;
}

- (NSInteger)taskMaxConcurrentCount {
    return self.taskQueue.maxConcurrentOperationCount;
}

- (void)disableApplicationUsername:(BOOL)disable {
    self.doNotUseApplicationUsername = disable;
}

#pragma mark -

- (NSArray<HLTPaymentTask *> *)paymentTasksOnGoing {
    return self.onGoingTasks;
}

- (BOOL)isOrderAlreadyInTask:(HLTOrderModel *)order {
    if (!order) {
        return NO;
    }
    if (self.currentTask && ![self.currentTask.order isEqualToOrder:order]) {
        return NO;
    }
    
    __block BOOL result = NO;
    [self.tasks enumerateObjectsUsingBlock:^(HLTPaymentTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.order isEqualToOrder:order]) {
            result = YES;
            *stop = YES;
        }
    }];
    
    return result;
}

- (void)addFetchTask:(NSOperation *)task {
    [self.fetchQueue addOperation:task];
}

- (void)addPaymentTask:(HLTPaymentTask *)task {
    HLTLog(@"[Payment] add PaymentTask: %@", task);
    NSAssert(task != nil, @"task should not be nil");
    if (self.currentTask != nil) {
        HLTLog(@"当前有支付任务!");
        
        [self.tasks enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(HLTPaymentTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.order.orderId isEqual:task.order.orderId]) {
                [obj addDependency:task];
                *stop = YES;
                
                HLTLog(@"[Payment] has same orderId(%@), wait until %@", task.order.orderId, obj.taskId);
            }
        }];
    }
    task.delegate = self;
    [self.tasks addObject:task];// 添加到队列末
    [self.taskQueue addOperation:task];// 任务调度 suspended
    
    [self checkAbnormalTask];
}

- (void)finishPaymentTask:(HLTPaymentTask *)task {
    [self.tasks removeObject:task];
    // 任务队列移除
    if (task.isCancelled || task.isFinished) {
        HLTLog(@"task isCancelled or isFinished");
    } else {
        [task cancel];
    }
}

- (void)checkAbnormalTask {
    if (self.taskQueue.maxConcurrentOperationCount > 1) {
        HLTLog(@"taskQueue concurrent count > 0, do not check abnormal task");
        return;
    }
    
    BOOL isLikelyAbnormal = NO;
    NSMutableDictionary *counts = @{}.mutableCopy;
    [self.tasks enumerateObjectsUsingBlock:^(HLTPaymentTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj == self.currentTask) {
            return ;
        }
        
        if (obj.productId) {
            counts[obj.productId] = @([counts[obj.productId] integerValue] + 1);
        }
    }];
    
    NSInteger productCount = MAX(1, counts.allKeys.count);
    CGFloat totoalCount = [[counts.allValues valueForKeyPath:@"@sum.integerValue"] floatValue];
    CGFloat weight = totoalCount / productCount;
    
    NSTimeInterval timecost = 0;
    if (self.currentTask) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        timecost = (now - self.currentTask.startTime);
        if (timecost > 60 * 5) {// 5分钟？= fetch1 + create1 + transaction1 + verify1(3)
            weight += (1 + self.currentTask.order.receiptVerifyCount * 0.5) * (timecost / 60 / 5);
        }
    }
    
    if (weight >= 4) {
        isLikelyAbnormal = YES;
    }
    
    if (isLikelyAbnormal && timecost > 60) {// 短时间多次回调排队处理、不检查异常
        HLTLog(@"[Payment ]may be a dead task[weight: %@], try to cancel current task", @(weight));
        HLTOrderStatus orderStatus = self.currentTask.order.orderStatus;
        if (orderStatus == HLTOrderStatusOrderFailed ||
            orderStatus == HLTOrderStatusPurchaseFailed ||
            orderStatus == HLTOrderStatusReceiptVerified) {
            [self.currentTask cancel];
        } else if (orderStatus != HLTOrderStatusPurchasing &&
                   orderStatus != HLTOrderStatusReceiptVerifying) {
            [self.currentTask cancel];
        }
    }
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    HLTLog(@"updatedTransactions (%@)", @(transactions.count));
    for (SKPaymentTransaction *transaction in transactions) {
        HLTLogParams(@{HLTLogEventKey: kLogEvent_SKTransaction_Update,
                       @"transactionState": @(transaction.transactionState),
                       @"tId": (transaction.transactionIdentifier ?: @""),
                       @"productId": (transaction.payment.productIdentifier ?: @""),
                       @"applicationUsername": (transaction.payment.applicationUsername ?: @""),
                       @"rcpt": ([self base64ReceiptsForTransaction:transaction] ?: @"")
                     }, @"[Transaction] update: %@", [self __stringTransactionState:transaction.transactionState]);
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                [self didPurchasingTransactions:transaction queue:queue];
                break;
            case SKPaymentTransactionStatePurchased: {
                [self didPurchasedTransactions:transaction queue:queue];
                break;
            }
            case SKPaymentTransactionStateFailed: {
                [self didFailTransaction:transaction queue:queue];
                break;
            }
            case SKPaymentTransactionStateRestored: {
                [self didRestoreTransaction:transaction queue:queue];
                break;
            }
            case SKPaymentTransactionStateDeferred: {
                [self didDeferTransaction:transaction];
                break;
            }
            default:
                break;
        }
    }
}

- (NSString *)__stringTransactionState:(SKPaymentTransactionState)state {
    NSString *desc = @"";
    switch (state) {
        case SKPaymentTransactionStatePurchasing:{
            desc = @"Purchasing";
            break;
        }
        case SKPaymentTransactionStatePurchased: {
            desc = @"Purchased";
            break;
        }
        case SKPaymentTransactionStateFailed: {
            desc = @"Failed";
            break;
        }
        case SKPaymentTransactionStateRestored: {
            desc = @"Restored";
            break;
        }
        case SKPaymentTransactionStateDeferred: {
            desc = @"Deferred";
            break;
        }
    }
    desc = [NSString stringWithFormat:@"%@ - %@", @(state), desc];
    
    return desc;
}

- (NSString *)base64ReceiptsForTransaction:(SKPaymentTransaction *)transaction {
    NSData *receipt = transaction.transactionReceipt;
    if (receipt) {
        NSString *receiptString = [receipt base64EncodedStringWithOptions:0];
        return receiptString;
    }
    
    return nil;
}

/* {
 // Tells an observer that one or more transactions have been removed from the queue.
 //- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
 //
 //}
 
 - (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
 
 }
 - (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
 
 }
 - (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray<SKDownload *> *)downloads {
 
 }
 
 // 促销
 //- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
 //    return YES;
 //}
 }*/


#pragma mark - HLTPaymentTaskDelegate

- (void)taskWillStart:(HLTPaymentTask *)task {// todo: 回调队列
    HLTLog(@"[Payment] taskWillStart: %@(%@)", task, task.taskId);
    self.currentTask = task;
    [self.onGoingTasks addObject:task];
    [[self metricsForPaymentTask:task] setTaskStartDate:[NSDate date]];
}

- (void)taskWillFetchProductInfo:(HLTPaymentTask *)task {
    HLTLog(@"[Payment] taskWillFetchProductInfo: %@", task);
    [[self metricsForPaymentTask:task] setFetchStartDate:[NSDate date]];
}

- (void)taskDidFetchProductInfo:(HLTPaymentTask *)task {
    [[self metricsForPaymentTask:task] setFetchFinishDate:[NSDate date]];
}

- (void)taskWillCreateOrder:(HLTPaymentTask *)task {
    [[self metricsForPaymentTask:task] setOrderStartDate:[NSDate date]];
}

- (void)taskCreateOrderFailed:(HLTPaymentTask *)task {
    [[self metricsForPaymentTask:task] setOrderFinishDate:nil];
}

- (void)taskCreateOrderSuccess:(HLTPaymentTask *)task {
    [[self metricsForPaymentTask:task] setOrderFinishDate:[NSDate date]];
    
    // 订单持久化（订单创建成功前不记录）
    [self.orderPersistence storeOrder:task.order];
    
    // 开始IAP交易
    SKProduct *product = task.skProduct;
    HLTLogParams(@{HLTLogEventKey: kLogEvent_Transaction_Start,
                   @"productId": (product.productIdentifier ?: @""),
                 }, @"[Transaction] Make Payment: %@(%@)", product.localizedTitle, product.productIdentifier);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    SKMutablePayment *payment = product ? [SKMutablePayment paymentWithProduct:product] : [SKMutablePayment paymentWithProductIdentifier:task.productId];
#pragma clang diagnostic pop
    if ([payment respondsToSelector:@selector(setApplicationUsername:)]) {
        payment.applicationUsername = [self createApplicationUsernameForTask:task];
    }
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)taskWillVerifyOrder:(HLTPaymentTask *)task {
    [self.orderPersistence storeOrder:task.order];
    
    [[self metricsForPaymentTask:task] setVerifyStartDate:[NSDate date]];
}

- (void)taskVerifyOrderFailed:(HLTPaymentTask *)task error:(nonnull NSError *)error{
    if ((error.code == HLTPaymentErrorServiceShipped ||
         error.code == HLTPaymentErrorVerifyOrderFailedButDontRetry) &&
        [error.domain isEqual:HLTStoreKitErrorDomain]) {// 不再尝试verify
        [self.orderPersistence storeBackupOrder:task.order];
        [self.orderPersistence removeOrder:task.order];
    } else {
        [self.orderPersistence storeOrder:task.order];
    }
    
    [[self metricsForPaymentTask:task] setVerifyFinishDate:nil];
}

- (void)taskVerifyOrderSuccess:(HLTPaymentTask *)task {
    [self.orderPersistence storeBackupOrder:task.order];
    [self.orderPersistence removeOrder:task.order];
    
    [[self metricsForPaymentTask:task] setVerifyFinishDate:[NSDate date]];
}

- (void)taskDidFinish:(HLTPaymentTask *)task {
    if (task.order.skTransaction) {// 若已在交易队列中则结束交易
        HLTLog(@"[Transaction] finish Transaction: %@", task.order.skTransaction)
        [[SKPaymentQueue defaultQueue] finishTransaction:task.order.skTransaction];
    }
    if ([task isEqual:self.currentTask]) {
        self.currentTask = nil;
    }
    [self.tasks removeObject:task];
    [self.onGoingTasks removeObject:task];
    
    [[self metricsForPaymentTask:task] setTaskFinishDate:[NSDate date]];
    [self removeMetricsForTask:task];
}

- (void)taskDidCancel:(HLTPaymentTask *)task {
    if (task.order.skTransaction) {// 若已在交易队列中则结束交易
        HLTLog(@"[Transaction] finish Transaction: %@", task.order.skTransaction);
        [[SKPaymentQueue defaultQueue] finishTransaction:task.order.skTransaction];
    }
    if ([task isEqual:self.currentTask]) {
        self.currentTask = nil;
    }
    [self.tasks removeObject:task];
    [self.onGoingTasks removeObject:task];
    
    [self removeMetricsForTask:task];
}

#pragma mark -


- (void)didPurchasingTransactions:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue *)queue {
    NSString *orderId = [self orderIdFromTransaction:transaction];
    HLTPaymentTask *task = [self searchTaskMatchingOrderId:orderId productId:transaction.payment.productIdentifier];
    if (task) {
        [self continueTask:task onTransactionPurchasing:transaction];
    } else {
        HLTLog(@"[Transaction] no task matching: %@", orderId);
    }
}

- (void)didPurchasedTransactions:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue *)queue {
    NSString *productId = transaction.payment.productIdentifier;
    NSString *orderId = [self orderIdFromTransaction:transaction];// 当前App周期的任务
    
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentSuccess,
                   @"tId": (transaction.transactionIdentifier ?: @""),
                   @"productId": (transaction.payment.productIdentifier ?: @""),
                   @"orderId": (orderId ?: @"orderIdNil"),
                   @"isJailbreak": @([HLTJailbreakDetect isJailbreak]),
                   }, @"[Transaction] didPurchased: [%@|%@] %@", transaction.payment.productIdentifier, transaction.payment.productIdentifier, (orderId ?: @"orderIdNil"));
    if (transaction.error != nil) {
        HLTLog(@"交易已失败，流程错误");
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:HLTStorageTransactionFailedCountKey];
    
    HLTPaymentTask *task = [self searchTaskMatchingOrderId:orderId
                                                 productId:productId];
    if (task) {
        HLTLog(@"[Transaction] task matching order [%@]（potential）: %@", orderId, task);
        [self continueTask:task onTransactionPurchased:transaction];
        return;
    }
    
    // 非当前App周期（或多次回调）发起的交易回调：检查订单队列、备份队列
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL isJailbreak = [HLTJailbreakDetect isJailbreak];
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentNoTask,
                   @"productId": (transaction.payment.productIdentifier ?: @""),
                   @"isJailbreak": @(isJailbreak),
                   @"orderId": (orderId ?: @"orderIdNil"),
                   }, @"[Transaction] No Task matched! Launch at: %@, now: %@, jailbreak: %@",  @(self.launchTime), @(now), @(isJailbreak));
    
    HLTOrderModel *order = nil;
    if (transaction.originalTransaction) {// 自动续费
        if (orderId.length <= 0) {
            HLTOrderModel *potentialRelated =
            [self searchPotentialOrderWithProductId:productId
                                      allowedStatus:@[@(HLTOrderStatusPurchased),
                                                      @(HLTOrderStatusReceiptVerifying),
                                                      @(HLTOrderStatusReceiptVerified)
            ]];
            orderId = potentialRelated.orderId;
        }/// 注意自动续费无需订单号，后端需要清楚该流程
        order = [self _createOrderForRescue:transaction orderId:orderId];
        [self continueOrder:order onTransactionPurchased:transaction];
        return;
    }
    
    if (orderId) {// 检查orderId匹配的订单（可信度高）
        order = [self searchAllOrdersMatchingOrderId:orderId];
    }
    if (!order) {// 检查队列中状态合理的订单（可信度低）
        // Purchased的前置状态非常复杂，一般Purchasing，可能多次PurchaseFailed、Purchased，意外情况可能Verifying之后
        order = [self searchPotentialOrderWithProductId:productId
                                          allowedStatus:@[@(HLTOrderStatusPurchasing),
                                                          @(HLTOrderStatusPurchaseFailed),
                                                          @(HLTOrderStatusPurchased),
                                                          @(HLTOrderStatusReceiptVerifying),
                                                          @(HLTOrderStatusReceiptFailed),
                                                          //@(HLTOrderStatusReceiptVerified)
                                          ]];
    }
    
    if (!order) {// 即时拯救
        order = [self _createOrderForRescue:transaction orderId:orderId];
        HLTLog(@"[Transaction] Rescue On-Site: %@", order);
    }
    
    [self continueOrder:order onTransactionPurchased:transaction];
}

- (void)didFailTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue {
    NSString *orderId = [self orderIdFromTransaction:transaction];
    BOOL isJailbreak = [HLTJailbreakDetect isJailbreak];
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentFailed,
                   HLTLogErrorKey: (transaction.error ?: @"errorNil"),
                   @"productId": (transaction.payment.productIdentifier ?: @""),
                   @"isJailbreak": @(isJailbreak),
                   @"orderId": (orderId ?: @"orderIdNil"),
                   @"tId": (transaction.transactionIdentifier ?: @"")
                   }, @"[Payment] Transaction Failed: [%@][%@], error: %@", transaction.payment.productIdentifier, transaction.payment.applicationUsername, transaction.error);
    
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:HLTStorageTransactionFailedCountKey];
    [[NSUserDefaults standardUserDefaults] setInteger:(count + 1) forKey:HLTStorageTransactionFailedCountKey];
    
    // 当前App周期的任务（进行中）
    HLTPaymentTask *task = [self searchTaskMatchingOrderId:orderId
                                                 productId:transaction.payment.productIdentifier];
    if (task) {
        HLTLog(@"[Transaction] task matching [%@]（potential）: %@", orderId, task);
        [self continueTask:task onTransactionFailed:transaction];
        return;
    }

    HLTOrderModel *order = nil;
    if (orderId) {// 检查orderId匹配的订单（可信度高）
        order = [self searchAllOrdersMatchingOrderId:orderId];
    }
    if (!order) {// 检查队列中状态合理的订单（可信度低）
        order = [self searchPotentialOrderWithProductId:transaction.payment.productIdentifier
                                          allowedStatus:@[@(HLTOrderStatusPurchasing),
                                                          @(HLTOrderStatusPurchaseFailed),
                                          ]];
    }
    if (orderId && !order) {// 即时拯救
        HLTLog(@"[Transaction] no order matching: %@", orderId);
        order = [self _createOrderForRescue:transaction orderId:orderId];
    }
    
    if (order &&
        order.orderStatus != HLTOrderStatusPurchased &&
        order.orderStatus != HLTOrderStatusReceiptVerified) {
        [self continueOrder:order onTransactionFailed:transaction];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    HLTLog(@"[Task] finish Transaction: %@", transaction);
}

- (void)didRestoreTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentRestore,
                   @"productId": (transaction.payment.productIdentifier ?: @""),
                   @"isJailbreak": @([HLTJailbreakDetect isJailbreak]),
                 }, @"[Payment] didRestoreTransaction");
}

- (void)didDeferTransaction:(SKPaymentTransaction *)transaction {
    HLTLog(@"didDeferTransaction");
}

- (HLTOrderModel *)_createOrderForRescue:(SKPaymentTransaction *)transaction orderId:(NSString *)orderId {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_OrderNotFound, @"orderId": (orderId ?: @"")}, @"[Payment] Transaction order not found: %@|%@", transaction.payment.productIdentifier, orderId);
    NSString *productId = transaction.payment.productIdentifier;
    HLTOrderModel *order = [[HLTOrderModel alloc] initWithProductId:productId];
    order.orderId = orderId;
    order.orderSource = HLTOrderSourceRescueOnSite;
    order.userIdentifier = [self userIdFromTransaction:transaction];
    
    [self.orderPersistence storeOrder:order];
    
    return order;
}

#pragma mark - Private

- (NSString *)orderIdFromTransaction:(SKPaymentTransaction *)transaction {
    NSString *orderId = nil;
    NSDictionary *orderUserInfo = [self getOrderUserInfoFromTransaction:transaction];
    if ([orderUserInfo isKindOfClass:[NSDictionary class]] &&
        orderUserInfo[HLTTransactionOrderIdKey] != nil) {
        orderId = orderUserInfo[HLTTransactionOrderIdKey];
        NSLog(@"[Transaction] has attached orderId: %@", orderId);
    } else {
        HLTLog(@"[Transaction] has no attached orderId, %@", transaction);
    }
    
    return orderId;
}

- (NSString *)userIdFromTransaction:(SKPaymentTransaction *)transaction {
    NSString *userId = nil;
    NSDictionary *orderUserInfo = [self getOrderUserInfoFromTransaction:transaction];
    if ([orderUserInfo isKindOfClass:[NSDictionary class]] &&
        orderUserInfo[HLTTransactionUserIdKey] != nil) {
        userId = orderUserInfo[HLTTransactionUserIdKey];
        HLTLog(@"[Transaction] has attached userId: %@", userId);
    } else {
        HLTLog(@"[Transaction] has no attached userId, %@", transaction);
    }
    
    return userId;
}

#pragma mark Tasking

- (void)continueTask:(HLTPaymentTask *)task onTransactionPurchasing:(SKPaymentTransaction *)transaction {
    [task continueOnTransactionPurchasing:transaction];
    [self.orderPersistence storeOrder:task.order];
}

- (void)continueTask:(HLTPaymentTask *)task onTransactionPurchased:(SKPaymentTransaction *)transaction {
    if (task == self.currentTask && task.taskStatus == HLTTaskStatusOrderVerifying) {
        return;
    }
    [task continueOnTransactionPurchased:transaction];
    [self.orderPersistence storeOrder:task.order];
}

- (void)continueTask:(HLTPaymentTask *)task onTransactionFailed:(SKPaymentTransaction *)transaction {
    [task continueOnTransactionFailed:transaction];
    [self.orderPersistence storeBackupOrder:task.order];
    [self.orderPersistence removeOrder:task.order];
}

- (void)continueOrder:(HLTOrderModel *)order onTransactionPurchased:(SKPaymentTransaction *)transaction {
    HLTLog(@"接收到交易回调，当前无交易任务，尝试恢复丢单");
    if (!order) {
        return;
    }
    
    [order updateWithSKPaymentTransaction:transaction];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:HLTReceiveTransactionWithNoTaskNotification
                          object:transaction
                        userInfo:@{HLTReceiveTransactionOrderKey: (order)}];
}

- (void)continueOrder:(HLTOrderModel *)order onTransactionFailed:(SKPaymentTransaction *)transaction {
    if (!order) {
        return;
    }
    
    [self.orderPersistence storeBackupOrder:order];
    [self.orderPersistence removeOrder:order];
}

#pragma mark Searching

- (HLTPaymentTask *)searchTaskMatchingOrderId:(NSString *)orderId productId:(NSString *)productId {
    NSAssert(productId != nil, @"productId should not be nil");
    HLTPaymentTask *task = nil;
    if (orderId) {
        task = [self searchTaskMatchingOrderId:orderId];
    } else {
        task = [self searchPotentialPendingTaskMatching:productId];
    }
    
    return task;
}

/**
 从内存中搜索orderId匹配的task
 
 @param orderId 订单id
 @return 返回匹配的task或者nil
 */
- (HLTPaymentTask *)searchTaskMatchingOrderId:(NSString *)orderId {
    if (![orderId isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    if ([self.currentTask.order.orderId isEqualToString:orderId]) {
        return self.currentTask;
    }
    
    for (HLTPaymentTask *task in self.tasks) {
        if (![task isKindOfClass:[HLTPaymentTask class]]) {
            continue;
        }
        if ([task.order.orderId isEqualToString:orderId]) {
            return task;
        }
    }
    
    return nil;
}

/**
 从内存中查找潜在的task（一般是applicationUsername为nil）
 @note 应当进行状态检查

 @return 潜在的task
 */
- (HLTPaymentTask *)searchPotentialPendingTaskMatching:(NSString *)productId {
    HLTPaymentTask *potentialTask = nil;
    if (self.currentTask &&
        [self.currentTask.productId isEqualToString:productId] &&
        self.currentTask.order.orderStatus < HLTOrderStatusPurchased) {
        potentialTask = self.currentTask;
    } else if (self.tasks.count > 0) {
        NSArray *sortedTask = [self.tasks sortedArrayUsingComparator:^NSComparisonResult(HLTPaymentTask *  _Nonnull obj1, HLTPaymentTask *  _Nonnull obj2) {
            return obj1.startTime > obj2.startTime;
        }];
        
        for (NSInteger index = 0; index < sortedTask.count; index ++) {
            HLTPaymentTask *task = sortedTask[index];
            if (![task isKindOfClass:[HLTPaymentTask class]]) {
                continue;
            }
            if ([task.productId isEqualToString:productId] &&
                task.order.orderStatus < HLTOrderStatusPurchased) {
                potentialTask = task;
            }
        }
    }
    
    return potentialTask;
}

/**
 从持久化的订单队列中搜索orderId匹配的order

 @param orderId 订单id
 @return 返回匹配的order或者nil
 */
- (HLTOrderModel *)searchAllOrdersMatchingOrderId:(NSString *)orderId {
    HLTOrderModel *result = [self searchPendingOrderMatchingOrderId:orderId];
    if (result) {
        return result;
    }
    
    HLTLog(@"[Payment] No Pending Order Matched: %@", orderId);
    
    result = [self searchBackupOrderMatchingOrderId:orderId];
    
    HLTLog(@"[Payment] Backup Order Matched orderId: %@", result);
    
    return result;
}

- (HLTOrderModel *)searchPendingOrderMatchingOrderId:(NSString *)orderId {
    NSArray<HLTOrderModel *> *orders = [self.orderPersistence getPendingOrderList];
    return [self searchInOrderList:orders matchingOrderId:orderId];
}

- (HLTOrderModel *)searchBackupOrderMatchingOrderId:(NSString *)orderId {
    NSArray<HLTOrderModel *> *orders = [self.orderPersistence getBackedupOrderList];
    return [self searchInOrderList:orders matchingOrderId:orderId];
}

- (HLTOrderModel *)searchInOrderList:(NSArray<HLTOrderModel *> *)orders matchingOrderId:(NSString *)orderId {
    if (![orderId isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    if (orders.count <= 0) {
        return nil;
    }
    
    NSArray<HLTOrderModel *> *filtered =
    [orders filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLTOrderModel * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[HLTOrderModel class]] &&
        evaluatedObject.orderStatus >= HLTOrderStatusOrderCreated &&
        [evaluatedObject.orderId isEqual:orderId];
    }]];
    
    filtered = [self sortedOrderList:filtered];
    
    return filtered.firstObject;
}

- (HLTOrderModel *)searchInOrderList:(NSArray<HLTOrderModel *> *)orders matchingProductId:(NSString *)productId allowdStatus:(NSArray *)allowdStatus {
    if (!productId) {
        return nil;
    }
    
    NSArray<HLTOrderModel *> *filtered =
    [orders filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLTOrderModel * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:[HLTOrderModel class]] &&
        evaluatedObject.orderId.length > 0 &&
        [evaluatedObject.productId isEqual:productId] &&
        /* Purchasing、Verifying 执行中任务*/
        evaluatedObject.orderStatus >= HLTOrderStatusOrderCreated;
    }]];
    
    filtered = [self sortedOrderList:filtered];
    
    HLTOrderModel *result = nil;
    for (NSInteger index = 0; index < filtered.count; index ++) {
        HLTOrderModel *order = filtered[index];
        
        if ([allowdStatus containsObject:@(order.orderStatus)]) {
            result = order;
            break;
        }
    }
    
//    if (!result) {
//        result = filtered.firstObject;
//    }
    
    return result;
}

- (HLTOrderModel *)searchPotentialOrderWithProductId:(NSString *)productId allowedStatus:(NSArray *)allowdStatus {
    NSArray<HLTOrderModel *> *pendingOrders = [self.orderPersistence getPendingOrderList];
    HLTOrderModel *candidate = [self searchInOrderList:pendingOrders matchingProductId:productId allowdStatus:allowdStatus];
    if (!candidate) {
        NSArray<HLTOrderModel *> *backupOrders = [self.orderPersistence getBackedupOrderList];
        candidate = [self searchInOrderList:backupOrders matchingProductId:productId allowdStatus:allowdStatus];
    }
    
    if (candidate) {
        [self updateOrderHint:candidate];
        HLTLog(@"[Payment] Potential Order Matched ProductId(%@) is %@", productId, candidate);
    }
    
    return candidate;
}

/// 根据订单创建时间倒序、
/// @param orders 待排序订单
- (NSArray<HLTOrderModel *> *)sortedOrderList:(NSArray *)orders {
    NSSortDescriptor *sortCreatedTime = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(createdTime)) ascending:NO comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    NSSortDescriptor *sortUpdateTime = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(updateTime)) ascending:NO comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    NSSortDescriptor *sortStatus = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(orderStatus)) ascending:NO comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSArray<HLTOrderModel *> *sorted =
    [orders sortedArrayUsingDescriptors:@[sortCreatedTime, sortUpdateTime, sortStatus]];
    
    NSLog(@"orders.sorted: %@", sorted);
    
    return sorted;
}

- (void)updateOrderHint:(HLTOrderModel *)order {
    if (order.orderStatus >= HLTOrderStatusReceiptVerified) {
        order.hint = @"嫌疑，订单已成功验证凭据";
    }
    else if (order.orderStatus < HLTOrderStatusPurchasing) {
        order.hint = @"嫌疑，订单尚未开始IAP交易";
    }
    else if (order.orderStatus == HLTOrderStatusPurchaseFailed) {
        order.hint = @"嫌疑，IAP交易已失败";
    }
    else if (order.orderStatus == HLTOrderStatusReceiptFailed) {
        order.hint = @"receipt验证已失败";
    }
    else if (order.orderStatus >= HLTOrderStatusPurchased) {
        order.hint = @"可能是receipt验证过程中断";
    }
}

#pragma mark Metrics

- (HLTTaskTransactionMetrics *)metricsForPaymentTask:(HLTPaymentTask *)task {
    return nil;
    /*
    if (!task.taskId) {
        return nil;
    }
    
    HLTTaskTransactionMetrics *metrics = self.id2TaskMetrics[task.taskId];
    if (metrics) {
        return metrics;
    }
    
    metrics = [HLTTaskTransactionMetrics metricWithTask:task];
    if (metrics) {
        self.id2TaskMetrics[task.taskId] = metrics;
    }
    
    return metrics;*/
}

- (void)removeMetricsForTask:(HLTPaymentTask *)task {
    if (task.taskId) {
        [self.id2TaskMetrics removeObjectForKey:task.taskId];
    }
}

- (void)flushMetrics {
    [self.id2TaskMetrics removeAllObjects];
}

#pragma mark 辅助

- (NSString *)createApplicationUsernameForTask:(HLTPaymentTask *)task {
    if (self.doNotUseApplicationUsername) {
        return nil;
    }
    NSString *userId = (task.order.userIdentifier ?: @"");
    NSString *orderId = (task.order.orderId ?: @"");
    return [orderId stringByAppendingFormat:@",%@", userId];
}

- (NSDictionary *)getOrderUserInfoFromTransaction:(SKPaymentTransaction *)transaction {
    SKPayment *payment = transaction.payment;
    NSString *applicationUsername = payment.applicationUsername;
    if (!applicationUsername) {
        return nil;
    }
    
    /*{ 兼容旧版*/
    NSError  *error;
    NSData *jsonData = [applicationUsername dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json =
    [NSJSONSerialization JSONObjectWithData:jsonData
                                    options:NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments
                                      error:&error];
    if (!error && json) {
        return json;
    }
    
    /*}*/
    
    NSArray *parts = [applicationUsername componentsSeparatedByString:@","];
    return @{HLTTransactionUserIdKey: (parts.lastObject ?: @""),
             HLTTransactionOrderIdKey: (parts.firstObject ?: @"")
    };
}

@end
