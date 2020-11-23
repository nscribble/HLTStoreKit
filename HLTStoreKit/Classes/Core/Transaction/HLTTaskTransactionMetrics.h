//
//  HLTTaskTransactionMetrics.h
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HLTPaymentTask;
@interface HLTTaskTransactionMetrics : NSObject

@property (nonatomic, strong) NSDate *taskStartDate;
@property (nonatomic, strong) NSDate *fetchStartDate;
@property (nonatomic, strong) NSDate *fetchFinishDate;
@property (nonatomic, strong) NSDate *orderStartDate;
@property (nonatomic, strong) NSDate *orderFinishDate;
@property (nonatomic, strong) NSDate *payStartDate;
@property (nonatomic, strong) NSDate *payFinishDate;
@property (nonatomic, strong) NSDate *verifyStartDate;
@property (nonatomic, strong) NSDate *verifyFinishDate;
@property (nonatomic, strong) NSDate *taskFinishDate;

+ (instancetype)metricWithTask:(HLTPaymentTask *)task;

@end

NS_ASSUME_NONNULL_END
