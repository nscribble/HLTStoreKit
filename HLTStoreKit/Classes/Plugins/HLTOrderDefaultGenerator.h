//
//  HLTOrderDefaultGenerator.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/29.
//  默认的订单生成器

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@class HLTOrderGeneratorReq;
// 每次订单创建请求回调
typedef void(^HLTOrderGeneratorReqCompletion)(HLTOrderGeneratorReq *request, HLTOrderModel * _Nullable order,  NSError * _Nullable error);
// 订单请求流程
typedef void(^HLTOrderGenReqProcessingBlock)(HLTOrderGeneratorReq *request, HLTOrderGeneratorReqCompletion completion);

@interface HLTOrderDefaultGenerator : NSObject<HLTOrderGenerator>

+ (void)setRequestProcessingBlock:(HLTOrderGenReqProcessingBlock)processingBlock;

- (void)generateOrder:(HLTOrderModel *)voidOrder
              success:(void (^)(HLTOrderModel *order))successBlock
              failure:(void (^)(NSError *error))failureBlock;

@end

@interface HLTOrderGeneratorReq : NSObject

@property (nonatomic, copy, readonly) NSString *productId;
@property (nonatomic,strong,readonly) HLTOrderModel *voidOrder;

@end

NS_ASSUME_NONNULL_END
