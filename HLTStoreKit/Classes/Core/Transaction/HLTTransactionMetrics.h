//
//  HLTTransactionMetrics.h
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HLTPaymentTask;
@interface HLTTransactionMetrics : NSObject

+ (instancetype)metricWithTask:(HLTPaymentTask *)task;

@end

NS_ASSUME_NONNULL_END
