//
//  HLTOrderModel.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/25.
//

#import <Foundation/Foundation.h>
#import "HLTOrderTransaction.h"
#import "HLTStoreKitPredefined.h"
@class SKPaymentTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface HLTOrderModel : NSObject <NSSecureCoding, HLTOrderConfiguration>

// 商品id
@property (nonatomic,copy) NSString *productId;
// 订单id
@property (nonatomic,copy) NSString *orderId;
// 用户标志
@property (nonatomic,copy) NSString *userIdentifier;
// 订单来源
@property (nonatomic,assign) HLTOrderSource orderSource;
// IAP交易状态
@property (nonatomic,assign) HLTOrderStatus orderStatus;
// 订单创建时间
@property (nonatomic,assign) NSTimeInterval createdTime;
// IAP交易开始时间
@property (nonatomic,assign) NSTimeInterval iapBeginTime;
// IAP交易成功时间
@property (nonatomic,assign) NSTimeInterval iapFinishTime;// todo iap transaction 超时
// 订单验证此次数
@property (nonatomic,assign) NSInteger receiptVerifyCount;
// 提示信息（预警等）
@property (nonatomic,copy) NSString *hint;
// 交易信息（用于备份）
@property (nonatomic,strong,readonly) HLTOrderTransaction *transaction;
// IAP交易信息
@property (nonatomic,strong,readonly) SKPaymentTransaction *skTransaction;

@property (nonatomic,assign,readonly) NSTimeInterval updateTime;

// 用户自定义信息
@property (nonatomic,strong) NSDictionary *userInfo;
@property (nonatomic,strong) NSObject *userInfoObject;

- (instancetype)initWithProductId:(NSString *)productId;

- (BOOL)isEqualToOrder:(HLTOrderModel *)other;

- (NSString * _Nullable)transactionIdentifier;
- (NSData * _Nullable)transactionReceipt;

#pragma mark -

- (void)updateWithSKPaymentTransaction:(SKPaymentTransaction *)skTransaction;
- (void)updateWithTransaction:(HLTOrderTransaction *)transaction;

- (NSString *)orderStatusDescription;

- (BOOL)isOrderIdValid;

@end

NS_ASSUME_NONNULL_END
