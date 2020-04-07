//
//  HLTOrderTransaction.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/27.
//  商品交易信息（IAP交易）

#import <Foundation/Foundation.h>

@class SKPaymentTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface HLTOrderTransaction : NSObject<NSSecureCoding>

// 是否已交付
@property(nonatomic, assign) BOOL consumed;
// 商品ID
@property(nonatomic, copy) NSString *productIdentifier;
// 交易ID，仅成功后非nil
@property(nonatomic, copy, nullable) NSString *transactionIdentifier;
// 交易时间
@property(nonatomic, copy, nullable) NSDate *transactionDate;
// 交易错误
@property(nonatomic, readonly, nullable) NSError *error;
// 订单凭据
@property (nonatomic, strong) NSData *receiptData;
@property (nonatomic, copy) NSURL *receiptURL;

- (instancetype)initWithSKPaymentTransaction:(SKPaymentTransaction *)transaction;

/**
 更新状态等，productIdentifier必须一致
 */
- (void)updateWithPaymentTransaction:(SKPaymentTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
