//
//  HLTTaskTransactionMetrics.m
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import "HLTTaskTransactionMetrics.h"

@interface HLTTaskTransactionMetrics ()

@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSInteger errorCode;

@end

@implementation HLTTaskTransactionMetrics

+ (instancetype)metricWithTask:(HLTPaymentTask *)task {
    HLTTaskTransactionMetrics *metric = [self new];
    
    return metric;
}

@end
