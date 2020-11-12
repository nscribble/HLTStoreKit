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
@import StoreKit;

static NSString * const HLTTransactionUserIdKey = @"userId";
static NSString * const HLTTransactionOrderIdKey = @"orderId";
NSString * const HLTReceiveTransactionWithNoTaskNotification = @"com.storekit.transactionwithnotask";
NSString * const HLTReceiveTransactionOrderKey = @"order";

#pragma mark - HLTPaymentQueue

@interface HLTPaymentQueue ()
<
SKPaymentTransactionObserver,
HLTPaymentTaskDelegate
>

// 任务队列
@property (nonatomic, strong) NSOperationQueue *queue;
// 当前任务
@property (nonatomic, strong) HLTPaymentTask *currentTask;
// 队列中任务列表（为多task并发做支持，如果applicationUserName稳定可用）
@property (nonatomic, strong) NSMutableArray<HLTPaymentTask *> *tasks;
// (队列)启动时间
@property (nonatomic, assign, readwrite) NSTimeInterval launchTime;

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

- (NSOperationQueue *)queue {
    if (!_queue) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.name = @"com.hltstorekit.taskqueue";
        _queue.maxConcurrentOperationCount = 1;
        _queue.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    
    return _queue;
}

- (NSMutableArray<HLTPaymentTask *> *)tasks {
    if (!_tasks) {
        _tasks = [NSMutableArray<HLTPaymentTask *> array];
    }
    
    return _tasks;
}

#pragma mark -

- (BOOL)isPaymentOrderInTask:(HLTOrderModel *)order {
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

- (void)addPaymentTask:(HLTPaymentTask *)task {
    HLTLog(@"[Payment] add PaymentTask: %@", task);
    NSAssert(task != nil, @"task should not be nil");
    if (self.currentTask != nil) {
        HLTLog(@"当前有支付任务!");
    }
    task.delegate = self;
    [self.tasks addObject:task];// 添加到队列末
    [self.queue addOperation:task];// 任务调度 suspended
    
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
    
    if (self.currentTask) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval timecost = (now - self.currentTask.startTime);
        if (timecost > 60 * 5) {// 5分钟？= fetch1 + create1 + transaction1 + verify1(3)
            weight += (1 + self.currentTask.order.receiptVerifyCount * 0.5) * (timecost / 60 / 5);
        }
    }
    
    if (weight >= 3) {
        isLikelyAbnormal = YES;
    }
    
    if (isLikelyAbnormal) {
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
    for (SKPaymentTransaction *transaction in transactions) {
        HLTLogParams(@{HLTLogEventKey: kLogEvent_SKTransaction_Update,
                       @"transactionState": @(transaction.transactionState),
                       @"transactionIdentifier": (transaction.transactionIdentifier ?: @""),
                       @"productIdentifier": (transaction.payment.productIdentifier ?: @""),
                       @"applicationUsername": (transaction.payment.applicationUsername ?: @""),
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
    HLTLog(@"[Payment] taskWillStart: %@", task);
    self.currentTask = task;
}

- (void)taskWillFetchProductInfo:(HLTPaymentTask *)task {
    HLTLog(@"[Payment] taskWillFetchProductInfo: %@", task);
}

- (void)taskDidFetchProductInfo:(HLTPaymentTask *)task {
}

- (void)taskWillCreateOrder:(HLTPaymentTask *)task {
}

- (void)taskCreateOrderFailed:(HLTPaymentTask *)task {
}

- (void)taskCreateOrderSuccess:(HLTPaymentTask *)task {
    // 订单持久化（订单创建成功前不记录）
    [self.orderPersistence storeOrder:task.order];
    
    // 开始IAP交易
    SKProduct *product = task.skProduct;
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
}

- (void)taskVerifyOrderFailed:(HLTPaymentTask *)task {
    [self.orderPersistence storeBackupOrder:task.order];// todo: 验证订单失败放到其他队列
    [self.orderPersistence removeOrder:task.order];
}

- (void)taskVerifyOrderSuccess:(HLTPaymentTask *)task {
    [self.orderPersistence removeOrder:task.order];
    
    // todo: 是否需要记录成功交易的备份？
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
                   @"transactionIdentifier": (transaction.transactionIdentifier ?: @""),
                   @"productIdentifier": (transaction.payment.productIdentifier ?: @""),
                   @"orderId": (orderId ?: @"orderIdNil"),
                   }, @"[Transaction] didPurchased: [%@|%@] %@", transaction.payment.productIdentifier, transaction.payment.productIdentifier, (orderId ?: @"orderIdNil"));
    if (transaction.error != nil) {
        HLTLog(@"交易已失败，流程错误");
        return;
    }
    
    HLTPaymentTask *task = [self searchTaskMatchingOrderId:orderId
                                                 productId:productId];
    if (task) {
        HLTLog(@"[Transaction] task matching order [%@]（potential）: %@", orderId, task);
        [self continueTask:task onTransactionPurchased:transaction];
        return;
    }
    
    // 非当前App周期发起的交易回调：检查订单队列、备份队列
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL isJailbreak = [HLTJailbreakDetect isJailbreak];
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentNoTask,
                   @"productIdentifier": (transaction.payment.productIdentifier ?: @""),
                   @"isJailbreak": @(isJailbreak),
                   @"orderId": (orderId ?: @"orderIdNil"),
                   }, @"[Transaction] No Task matched! Launch at: %@, now: %@, jailbreak: %@",  @(self.launchTime), @(now), @(isJailbreak));
    
    HLTOrderModel *order = nil;
    if (orderId) {//
        HLTLog(@"检查orderId匹配的订单（可信度高）");
        order = [self searchPendingOrderMatchingOrderId:orderId];
        if (!order) {
            HLTLog(@"[Payment] No Pending Order Matched: %@", orderId);
            order = [self searchBackupOrderMatchingOrderId:orderId];
            HLTLog(@"[Payment] Search Backup Order Matched: %@", order);
        }
    } else {// 检查队列中状态合理的订单（可信度低）
        order = [self searchPotentialOrderWithProductId:productId];
    }
    
    if (!order) {// 即时拯救 todo: 用户未登录不做处理？&& orderId
        HLTLogParams(@{HLTLogEventKey: kLogEvent_OrderLost}, @"[Payment] Transaction order lost: %@|%@", productId, orderId);
        NSString *productId = transaction.payment.productIdentifier;
        order = [[HLTOrderModel alloc] initWithProductId:productId];
        order.orderId = orderId;
        order.orderSource = HLTOrderSourceRescueOnSite;
        order.userIdentifier = [self userIdFromTransaction:transaction];
        
        [self.orderPersistence storeOrder:order];
        HLTLog(@"[Transaction] Rescue On-Site: %@", order);
    }
    
    [self continueOrder:order onTransactionPurchased:transaction];
}

- (void)didFailTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKPaymentFailed,
                   HLTLogErrorKey: (transaction.error ?: @"errorNil"),
                   }, @"[Payment] Transaction Failed: [%@][%@], error: %@", transaction.payment.productIdentifier, transaction.payment.applicationUsername, transaction.error);
    // 当前App周期的任务
    NSString *orderId = [self orderIdFromTransaction:transaction];
    HLTPaymentTask *task = [self searchTaskMatchingOrderId:orderId
                                                 productId:transaction.payment.productIdentifier];
    if (task) {
        HLTLog(@"[Transaction] task matching [%@]（potential）: %@", orderId, task);
        [self continueTask:task onTransactionFailed:transaction];
        return;
    }
    
    HLTLog(@"无任务情况的错误回调(启动后)");
    
    HLTOrderModel *order = nil;
    if (orderId) {// 检查orderId匹配的订单（可信度高）
        order = [self searchPendingOrderMatchingOrderId:orderId];
        if (order) {
            [self continueOrder:order onTransactionFailed:transaction];
        }
    } else {// 检查队列中状态合理的订单（可信度低）
        order = [self searchPotentialOrderWithProductId:transaction.payment.productIdentifier];
        if (order) {
            [self continueOrder:order onTransactionFailed:transaction];
        }
    }
    
    if (!order) {// 即时拯救 todo: 用户未登录不做处理？
        HLTLog(@"[Transaction] no order matching: %@", orderId);
        NSString *productId = transaction.payment.productIdentifier;
        order = [[HLTOrderModel alloc] initWithProductId:productId];
        order.orderId = orderId;
        order.orderSource = HLTOrderSourceRescueOnSite;
        order.userIdentifier = [self userIdFromTransaction:transaction];
        
        [self.orderPersistence storeBackupOrder:order];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    HLTLog(@"[Task] finish Transaction: %@", transaction);
}

- (void)didRestoreTransaction:(SKPaymentTransaction *)transaction queue:(SKPaymentQueue*)queue {
    
}

- (void)didDeferTransaction:(SKPaymentTransaction *)transaction {
    
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
- (HLTOrderModel *)searchPendingOrderMatchingOrderId:(NSString *)orderId {
    if (![orderId isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSArray<HLTOrderModel *> *orders = [self.orderPersistence getPendingOrderList];
    if (orders.count <= 0) {
        return nil;
    }
    
    for (HLTOrderModel *obj in orders) {
        if (![obj isKindOfClass:[HLTOrderModel class]]) {
            continue;
        }
        
        if ([obj.orderId isEqualToString:orderId]) {
            return obj;
        }
    }
    
    return nil;
}

- (HLTOrderModel *)searchBackupOrderMatchingOrderId:(NSString *)orderId {
    if (![orderId isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSArray<HLTOrderModel *> *orders = [self.orderPersistence getBackedupOrderList];
    if (orders.count <= 0) {
        return nil;
    }
    
    orders = [orders sortedArrayUsingComparator:^NSComparisonResult(HLTOrderModel *  _Nonnull obj1, HLTOrderModel *  _Nonnull obj2) {
        if (obj1.createdTime > obj2.createdTime) {
            return NSOrderedAscending;
        } else if (obj1.createdTime < obj2.createdTime) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    for (NSInteger index = 0; index < orders.count; index ++) {
        HLTOrderModel *order = orders[index];
        if (![order isKindOfClass:[HLTOrderModel class]]) {
            continue;
        }
        
        if ([order.orderId isEqualToString:orderId]) {
            return order;
        }
    }
    
    return nil;
}

- (HLTOrderModel *)searchPotentialOrderWithProductId:(NSString *)productId {
    HLTOrderModel *candidate = nil;
    NSArray<HLTOrderModel *> *pendingOrders = [self.orderPersistence getPendingOrderList];
    
    // 执行中任务
    pendingOrders = [self sortedOrderList:pendingOrders];
    for (NSInteger index = 0; index < pendingOrders.count; index ++) {
        HLTOrderModel *order = pendingOrders[index];
        if (![order isKindOfClass:[HLTOrderModel class]] ||
            ![order.productId isEqualToString:productId]) {
            continue;
        }
        
        if (order.orderStatus == HLTOrderStatusPurchasing || order.orderStatus == HLTOrderStatusReceiptVerifying) {
            [self updateOrderHint:order];
            candidate = order;
            break;
        }
    }
    if (candidate) {
        HLTLog(@"[Payment] Potential of Pending Order: %@", candidate);
        return candidate;
    }
    
    // 降低条件
    for (NSInteger index = 0; index < pendingOrders.count; index ++) {
        HLTOrderModel *order = pendingOrders[index];
        if (![order isKindOfClass:[HLTOrderModel class]] ||
            ![order.productId isEqualToString:productId]) {
            continue;
        }
        
        if (order.orderStatus >= HLTOrderStatusPurchasing) {
            [self updateOrderHint:order];
            candidate = order;
            break;
        }
    }
    if (candidate) {
        HLTLog(@"[Payment] Potential of Pending Order: %@", candidate);
        return candidate;
    }
    
    NSArray<HLTOrderModel *> *backupOrders = [self.orderPersistence getBackedupOrderList];
    backupOrders = [self sortedOrderList:backupOrders];
    for (NSInteger index = 0; index < backupOrders.count; index ++) {
        HLTOrderModel *order = backupOrders[index];
        if (![order isKindOfClass:[HLTOrderModel class]] ||
            ![order.productId isEqualToString:productId]) {
            continue;
        }
        
        if (order.orderStatus == HLTOrderStatusPurchasing || order.orderStatus == HLTOrderStatusReceiptVerifying) {
            [self updateOrderHint:order];
            candidate = order;
            break;
        }
    }
    if (candidate) {
        HLTLog(@"[Payment] Potential of Backup Order: %@", candidate);
        return candidate;
    }
    
    
    for (NSInteger index = 0; index < backupOrders.count; index ++) {
        HLTOrderModel *order = backupOrders[index];
        if (![order isKindOfClass:[HLTOrderModel class]] ||
            ![order.productId isEqualToString:productId]) {
            continue;
        }
        
        if (order.orderStatus == HLTOrderStatusPurchasing ||// 可能未输入App Store密码、杀进程等
            order.orderStatus == HLTOrderStatusPurchaseFailed ||
            order.orderStatus == HLTOrderStatusReceiptFailed) {
            [self updateOrderHint:order];
            candidate = order;
            break;
        }
    }
    HLTLog(@"[Payment] Potential of Backup Order: %@", candidate);
    
    return candidate;
}

- (NSArray<HLTOrderModel *> *)sortedOrderList:(NSArray *)orders {
    NSArray<HLTOrderModel *> *sorted =
    [orders sortedArrayUsingComparator:^NSComparisonResult(HLTOrderModel *  _Nonnull obj1, HLTOrderModel *  _Nonnull obj2) {
        if (obj1.createdTime > obj2.createdTime) {
            return NSOrderedAscending;
        } else if (obj1.createdTime < obj2.createdTime) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
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

#pragma mark 辅助

- (NSString *)createApplicationUsernameForTask:(HLTPaymentTask *)task {
    NSString *userId = (task.order.userIdentifier ?: @"");
    NSString *orderId = (task.order.orderId ?: @"");
    return [orderId stringByAppendingFormat:@",%@", userId];
    
    NSDictionary *userInfo = @{HLTTransactionUserIdKey: (task.order.userIdentifier ?: @""),
                               HLTTransactionOrderIdKey: (task.order.orderId ?: @"")
                               };
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSDictionary *)getOrderUserInfoFromTransaction:(SKPaymentTransaction *)transaction {
    SKPayment *payment = transaction.payment;
    NSString *applicationUsername = payment.applicationUsername;
    if (!applicationUsername) {
        return nil;
    }
    
    
    NSArray *parts = [applicationUsername componentsSeparatedByString:@","];
    return @{HLTTransactionUserIdKey: parts.lastObject,
             HLTTransactionOrderIdKey: parts.firstObject
    };
}

- (void)restoreCompletedTransactions {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end
