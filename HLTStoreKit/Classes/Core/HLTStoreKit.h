//
//  HLTStoreKit.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "HLTStoreKitPredefined.h"
#import "HLTOrderModel.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const HLTLogEventKey;
extern NSString * const HLTLogErrorKey;
extern NSString * const HLTLogErrCodeKey;

@interface HLTStoreKit : NSObject

// 订单生成器
@property (nonatomic,strong) id<HLTOrderGenerator> orderGenerator;
// 订单校验器
@property (nonatomic,strong) id<HLTOrderVerifier> orderVerifier;
// 持久化处理器
@property (nonatomic,strong) id<HLTOrderPersistence> orderPersistence;

@property (nonatomic,copy) void(^confirmOnGoingTask)(NSString *productId, NSString *title, void(^confirmCallback)(BOOL confirmed));

+ (instancetype)defaultStore;

+ (NSString *)sdkVersion;

- (NSTimeInterval)launchTime;

#pragma mark - Configuration

/**
 设置日志处理器
 
 @param logger 日志处理器
 */
+ (void)setLogger:(void (^)(NSDictionary *params, NSString *format, ...))logger;

#pragma mark - Transaction

/**
 开始/结束 监听IAP交易回调
 @note 建议启动后开始监听
 */
- (void)startObservingTransaction;

/// 停止监听IAP交易回调
- (void)stopObservingTransaction;

/// 获取商品实例
/// @note 这是Prefetch或之前拿到的`SKProduct`
/// @param identifier 商品id
- (SKProduct *)productForIdentifier:(NSString *)identifier;

/// 预获取商品信息
/// @param productIdentifiers 商品id列表
- (void)prefetchProducts:(NSArray<NSString *> *)productIdentifiers;

/// 获取商品信息
/// @note 可以预获取商品信息
/// @param productIdentifiers 商品id列表
- (void)fetchProducts:(NSArray<NSString *> *)productIdentifiers
           completion:(HLTProductRequestCompletion)completion;

#pragma mark -

/**
 购买商品
 @note 错误信息请见`HLTPaymentErrorCode`
 
 @param productId 商品ID
 @param completion 完成回调
 */
- (void)purchase:(NSString *)productId
   configuration:(HLTOrderConfigurationBlock __nullable)configuration
      completion:(HLTPaymentCompletion __nullable)completion;

/**
 重试订单（主要是verify）

 @param order 订单
 */
- (void)tryRetrievalOrder:(HLTOrderModel *)order;

/// 刷新凭据
/// @param completion 完成回调
- (void)refreshPaymentReceipts:(HLTReceiptRefreshCompletion)completion;

/// 恢复交易
- (void)restoreTransactions;

@end

NS_ASSUME_NONNULL_END
