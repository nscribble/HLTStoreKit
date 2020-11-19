//
//  HLTPaymentTask.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//  支付任务（主要处理订单流程）

#import <Foundation/Foundation.h>
#import <Foundation/NSOperation.h>
#import "HLTStoreKitPredefined.h"
#import "HLTOrderModel.h"
@import StoreKit;

NS_ASSUME_NONNULL_BEGIN

@protocol HLTPaymentTaskDelegate <NSObject>
@optional

- (void)taskWillStart:(HLTPaymentTask *)task;

- (void)taskWillFetchProductInfo:(HLTPaymentTask *)task;
- (void)taskDidFetchProductInfo:(HLTPaymentTask *)task;

- (void)taskWillCreateOrder:(HLTPaymentTask *)task;
- (void)taskCreateOrderFailed:(HLTPaymentTask *)task;
- (void)taskCreateOrderSuccess:(HLTPaymentTask *)task;

- (void)taskWillVerifyOrder:(HLTPaymentTask *)task;
- (void)taskVerifyOrderFailed:(HLTPaymentTask *)task;
- (void)taskVerifyOrderSuccess:(HLTPaymentTask *)task;

- (void)taskDidFinish:(HLTPaymentTask *)task;
- (void)taskDidCancel:(HLTPaymentTask *)task;

@end

@class SKProduct;
@protocol HLTAppleProductProvider <NSObject>

- (void)fetchProductOfIdentifier:(NSString *)identifier completion:(void(^)(SKProduct * _Nullable product, NSError *_Nullable error))completion;

@end

typedef void(^HLTPaymentTaskBlock)(BOOL success);
@interface HLTPaymentTask : NSOperation<HLTOrderConfiguration>
{
@protected
    HLTOrderModel *_order;
    HLTPaymentCompletion _completion;
    NSTimeInterval _startTime;
}

// 任务状态
@property (nonatomic,assign) HLTTaskStatus   taskStatus;;
// 事件代理
@property (nonatomic,weak) id<HLTPaymentTaskDelegate> delegate;
// 商品ID
@property (nonatomic,copy,readonly) NSString *productId;
// 订单信息
@property (nonatomic,strong,readonly,nullable) HLTOrderModel *order;
// 任务开始时间
@property (nonatomic,assign,readonly) NSTimeInterval startTime;
// 商品（查询到商品信息后可取）
@property (nonatomic,strong,readonly,nullable) SKProduct *skProduct;
// 商品信息提供者
@property (nonatomic,weak) id<HLTAppleProductProvider> productProvider;
// 订单生成器
@property (nonatomic,weak) id<HLTOrderGenerator> orderGenerator;
// 订单校验器
@property (nonatomic,weak) id<HLTOrderVerifier> orderVerifier;
// 用户自定义信息
@property (nonatomic,strong) NSDictionary *userInfo;
@property (nonatomic,strong) NSObject *userInfoObject;

- (instancetype)initWithProductId:(NSString *)productId completion:(HLTPaymentCompletion)completion;

/**
 内购流程状态更新

 @param transaction 内购交易信息
 */
- (void)continueOnTransactionPurchasing:(SKPaymentTransaction *)transaction;
- (void)continueOnTransactionPurchased:(SKPaymentTransaction * _Nullable)transaction;
- (void)continueOnTransactionFailed:(SKPaymentTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
