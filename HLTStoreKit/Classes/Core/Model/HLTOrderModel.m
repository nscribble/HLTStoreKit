//
//  HLTOrderModel.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/25.
//

#import "HLTOrderModel.h"
#import "HLTStoreKitVersion.h"
@import StoreKit;

@interface HLTOrderModel ()

// 交易信息（用于备份）
@property (nonatomic,strong,readwrite) HLTOrderTransaction *transaction;
// IAP交易信息
@property (nonatomic,strong,readwrite) SKPaymentTransaction *skTransaction;
@property (nonatomic,assign,readwrite) NSTimeInterval updateTime;
@property (nonatomic,copy,readwrite) NSString *sdkVersion;
@property (nonatomic,strong,readwrite) NSError *lastError;

@end

@implementation HLTOrderModel

- (instancetype)initWithProductId:(NSString *)productId {
    if (self = [super init]) {
        _productId = productId;
        _orderId = [NSString stringWithFormat:@"temp|%@", @((NSInteger)[[NSDate date] timeIntervalSince1970])];
        _updateTime = [[NSDate date] timeIntervalSince1970];
        _createdTime = [[NSDate date] timeIntervalSince1970];
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[Order][%@][%@][%@][%@][%@][%@][count:%@]", self.productId, self.orderId, self.userIdentifier, [self orderStatusDescription], @(self.createdTime), @(self.updateTime), @(self.receiptVerifyCount)];
}

- (NSString *)orderStatusDescription {
    return [self __orderStatusDescription:self.orderStatus];
}

- (NSString *)__orderStatusDescription:(HLTOrderStatus)status {
    NSDictionary *status2desc =
    @{@(HLTOrderStatusPrepare): @"Prepare",
      @(HLTOrderStatusOrderCreating): @"OrderCreating",
      @(HLTOrderStatusOrderFailed): @"OrderFailed",
      @(HLTOrderStatusOrderCreated): @"OrderCreated",
      @(HLTOrderStatusPurchasing): @"Purchasing",
      @(HLTOrderStatusPurchaseFailed): @"PurchaseFailed",
      @(HLTOrderStatusPurchased): @"Purchased",
      @(HLTOrderStatusReceiptVerifying): @"ReceiptVerifying",
      @(HLTOrderStatusReceiptFailed): @"ReceiptFailed",
      @(HLTOrderStatusReceiptVerified): @"ReceiptVerified",
      };
    return status2desc[@(status)] ?: @"";
}

- (BOOL)isEqualToOrder:(HLTOrderModel *)other {
    if (!other || ![other isKindOfClass:[HLTOrderModel class]]) {
        return NO;
    }
    
    if (other.productId && self.productId && ![other.productId isEqualToString:self.productId]) {
        return NO;
    }
    if (other.orderId && self.orderId && ![other.orderId isEqualToString:self.orderId]) {
        return NO;
    }
    
    return YES;
}

- (void)setOrderId:(NSString *)orderId {
    NSString *oid = orderId;
    if ([orderId isKindOfClass:[NSNumber class]]) {
        oid = [(NSNumber *)orderId stringValue];
    }
    
    _orderId = oid;
}

- (void)setOrderStatus:(HLTOrderStatus)orderStatus {
    if (![self canTransToStatus:orderStatus]) {
        HLTLog(@"[Order] status is already [%@], cannot set to [%@]", [self orderStatusDescription], [self __orderStatusDescription:orderStatus]);
        return;
    }
    
    _orderStatus = orderStatus;
    _updateTime = [[NSDate date] timeIntervalSince1970];
    _sdkVersion = HLTStoreKitVersion;
}

- (BOOL)canTransToStatus:(HLTOrderStatus)status {
    if (status == self.orderStatus) {
        return YES;
    }
    
    switch (self.orderStatus) {
        case HLTOrderStatusReceiptVerified: {
            return status == HLTOrderStatusReceiptVerified;
            break;
        }
        case HLTOrderStatusOrderFailed:
        case HLTOrderStatusPurchaseFailed:
        case HLTOrderStatusReceiptFailed:{
            return status == self.orderStatus - 0b01;
            break;
        }
        case HLTOrderStatusOrderCreated:
        case HLTOrderStatusPurchased:{
            return status == self.orderStatus + 0b10;
            break;
        }
        case HLTOrderStatusOrderCreating:
        case HLTOrderStatusPurchasing:
        case HLTOrderStatusReceiptVerifying: {
            return (status == self.orderStatus + 0b01) || (status == self.orderStatus + 0b10);
            break;
        }
        case HLTOrderStatusPrepare: {
            return (status == HLTOrderStatusPrepare ||
                    status == HLTOrderStatusOrderCreating ||
                    status == HLTOrderStatusReceiptVerifying ||
                    status == HLTOrderStatusPurchasing);
            break;
        }
    }
}

#pragma mark - Public

- (NSString *)transactionIdentifier {
    return self.skTransaction.transactionIdentifier ?: self.transaction.transactionIdentifier;
}

- (NSData *)transactionReceipt {
    return self.skTransaction.transactionReceipt ?: self.transaction.receiptData;
}

- (BOOL)isOrderIdValid {
    return self.orderId != nil && self.orderId.length > 0 && ![self.orderId hasPrefix:@"temp"];
}

- (void)updateWithSKPaymentTransaction:(SKPaymentTransaction *)skTransaction {
    if (!skTransaction) {
        return;
    }
    
    self.skTransaction = skTransaction;//todo: 检查productId
    if (!self.transaction) {
        self.transaction = [[HLTOrderTransaction alloc] initWithSKPaymentTransaction:skTransaction];
    } else {
        [self.transaction updateWithPaymentTransaction:skTransaction];
    }
}

- (void)updateWithTransaction:(HLTOrderTransaction *)transaction {
    self.transaction = transaction;
}

#pragma mark - Coding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _productId = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(productId))];
        _orderId = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(orderId))];
        _userIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(userIdentifier))];
        _orderSource = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(orderSource))];
        _orderStatus = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(orderStatus))];
        _createdTime = [aDecoder decodeDoubleForKey:NSStringFromSelector(@selector(createdTime))];
        _iapBeginTime = [aDecoder decodeDoubleForKey:NSStringFromSelector(@selector(iapBeginTime))];
        _iapFinishTime = [aDecoder decodeDoubleForKey:NSStringFromSelector(@selector(iapFinishTime))];
        _receiptVerifyCount = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(receiptVerifyCount))];
        _transaction = [aDecoder decodeObjectOfClass:[HLTOrderTransaction class] forKey:NSStringFromSelector(@selector(transaction))];
        _userInfo = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:NSStringFromSelector(@selector(userInfo))];
        _updateTime = [aDecoder decodeDoubleForKey:NSStringFromSelector(@selector(updateTime))];
        _sdkVersion = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(sdkVersion))];
        //_lastError = [aDecoder decodeObjectOfClass:[NSError class] forKey:NSStringFromSelector(@selector(lastError))];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.productId forKey:NSStringFromSelector(@selector(productId))];
    [aCoder encodeObject:self.orderId forKey:NSStringFromSelector(@selector(orderId))];
    [aCoder encodeObject:self.userIdentifier forKey:NSStringFromSelector(@selector(userIdentifier))];
    [aCoder encodeInteger:self.orderSource forKey:NSStringFromSelector(@selector(orderSource))];
    [aCoder encodeInteger:self.orderStatus forKey:NSStringFromSelector(@selector(orderStatus))];
    [aCoder encodeDouble:self.createdTime forKey:NSStringFromSelector(@selector(createdTime))];
    [aCoder encodeDouble:self.iapBeginTime forKey:NSStringFromSelector(@selector(iapBeginTime))];
    [aCoder encodeDouble:self.iapFinishTime forKey:NSStringFromSelector(@selector(iapFinishTime))];
    [aCoder encodeInteger:self.receiptVerifyCount forKey:NSStringFromSelector(@selector(receiptVerifyCount))];
    [aCoder encodeObject:self.transaction forKey:NSStringFromSelector(@selector(transaction))];
    [aCoder encodeObject:self.userInfo forKey:NSStringFromSelector(@selector(userInfo))];
    [aCoder encodeDouble:self.updateTime forKey:NSStringFromSelector(@selector(updateTime))];
    [aCoder encodeObject:self.sdkVersion forKey:NSStringFromSelector(@selector(sdkVersion))];
    //[aCoder encodeObject:self.lastError forKey:NSStringFromSelector(@selector(lastError))];
}

@end
