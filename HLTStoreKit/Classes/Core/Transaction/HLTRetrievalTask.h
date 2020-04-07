//
//  HLTRetrievalTask.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//  交易任务：丢单挽救

#import "HLTPaymentTask.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLTRetrievalTask : HLTPaymentTask

- (instancetype)initWithOrder:(HLTOrderModel *)order skTransaction:(SKPaymentTransaction *)skTransaction completion:(HLTPaymentCompletion)completion;

@end

NS_ASSUME_NONNULL_END
