//
//  HLTPaymentQueue.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//  支付队列（主要处理任务调度、PaymentTransaction事件、可靠性处理（持久化）等）

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"
@import StoreKit;

NS_ASSUME_NONNULL_BEGIN
// 接收到无任务交易通知。object=SKPaymentTransaction，userInfo={order:HLTOrderModel}
extern NSString * const HLTReceiveTransactionWithNoTaskNotification;
extern NSString * const HLTReceiveTransactionOrderKey;
extern NSString * const HLTStorageTransactionFailedCountKey;

@class HLTPaymentTask;
@interface HLTPaymentQueue : NSObject<SKPaymentTransactionObserver>

// 持久化处理器
@property (nonatomic,weak) id<HLTOrderPersistence> orderPersistence;
@property (nonatomic,assign,readonly) NSTimeInterval launchTime;

+ (instancetype)defaultQueue;

- (NSInteger)taskMaxConcurrentCount;
- (void)setTaskConcurrentCount:(NSInteger)count;
- (void)disableApplicationUsername:(BOOL)disable;

#pragma mark -

/**
 添加 支付任务
 @param task 支付任务
 */
- (void)addPaymentTask:(HLTPaymentTask *)task;

/// 添加 信息同步任务
/// @param task 任务
- (void)addFetchTask:(NSOperation *)task;

#pragma mark

/**
 订单是否在支付任务中

 @param order 订单
 @return 是否支付任务中
 */
- (BOOL)isOrderAlreadyInTask:(HLTOrderModel *)order;

- (NSArray<HLTPaymentTask *> *)paymentTasksOnGoing;

/**
 结束 支付任务流程
 @param task 支付任务
 */
//- (void)finishPaymentTask:(HLTPaymentTask *)task;

- (NSArray<HLTOrderModel *> *)sortedOrderList:(NSArray *)orders;


@end

NS_ASSUME_NONNULL_END
