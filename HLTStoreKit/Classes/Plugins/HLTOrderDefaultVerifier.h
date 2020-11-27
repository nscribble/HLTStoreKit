//
//  HLTOrderDefaultVerifier.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/29.
//

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@class HLTOrderVerifierReq;

// 每次订单校验回调
typedef void(^HLTOrderVerifyCompletion)(HLTOrderVerifierReq *request, BOOL success, NSError * _Nullable error);
// 订单校验流程
typedef void(^HLTOrderVerifyProcessingBlock)(HLTOrderVerifierReq *request, HLTOrderVerifyCompletion completion);

@interface HLTOrderDefaultVerifier : NSObject<HLTOrderVerifier>

+ (void)setRequestProcessingBlock:(HLTOrderVerifyProcessingBlock)processingBlock;

@end

@interface HLTOrderVerifierReq : NSObject

@property (nonatomic,strong,readonly) HLTOrderModel *order;
@property (nonatomic,strong) NSDictionary *responseObject;
@property (nonatomic,assign,readonly) NSInteger retryCount;
@property (nonatomic,assign) BOOL dontRetry;

@end

NS_ASSUME_NONNULL_END
