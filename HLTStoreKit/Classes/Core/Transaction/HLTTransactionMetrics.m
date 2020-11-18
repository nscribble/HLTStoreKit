//
//  HLTTransactionMetrics.m
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import "HLTTransactionMetrics.h"

@interface HLTTransactionMetrics ()

@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSInteger errorCode;

@end

@implementation HLTTransactionMetrics

+ (instancetype)metricWithTask:(HLTPaymentTask *)task {
    HLTTransactionMetrics *metric = [self new];
    
    return metric;
}

@end
