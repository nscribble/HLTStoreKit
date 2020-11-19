//
//  HLTOrderTransaction.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/27.
//

#import "HLTOrderTransaction.h"
#import "HLTStoreKitPredefined.h"
@import StoreKit;

@interface HLTOrderTransaction ()

@property(nonatomic, readwrite, nullable) NSError *error;
@property(nonatomic, copy) NSString *applicationUsername;

@end

@implementation HLTOrderTransaction

- (instancetype)initWithSKPaymentTransaction:(SKPaymentTransaction *)transaction {
    if (self = [super init]) {
        self.error = transaction.error;
        self.productIdentifier = transaction.payment.productIdentifier;
        self.transactionIdentifier = transaction.transactionIdentifier;
        self.transactionDate = transaction.transactionDate;
        self.applicationUsername = transaction.payment.applicationUsername;
        self.receiptData = transaction.transactionReceipt;
        self.receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[Transaction][%@][%@][%@]", self.transactionIdentifier, self.transactionDate, self.applicationUsername];
}

- (void)updateWithPaymentTransaction:(SKPaymentTransaction *)transaction {
    if (![transaction.payment.productIdentifier isEqualToString:self.productIdentifier]) {
        HLTLog(@"product Identifier not match!");
        return;
    }
    
    self.error = transaction.error;
    self.transactionIdentifier = transaction.transactionIdentifier;
    self.transactionDate = transaction.transactionDate;
    self.applicationUsername = transaction.payment.applicationUsername;
    
    if (transaction.transactionReceipt) {// !self.receiptData && 
        self.receiptData = transaction.transactionReceipt;
    }
    if (!self.receiptURL) {
        self.receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    }
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.consumed = [aDecoder decodeBoolForKey:NSStringFromSelector(@selector(consumed))];
        self.productIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(productIdentifier))];
        self.transactionIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(transactionIdentifier))];
        self.transactionDate = [aDecoder decodeObjectOfClass:[NSDate class] forKey:NSStringFromSelector(@selector(transactionDate))];
        self.error = [aDecoder decodeObjectOfClass:[NSError class] forKey:NSStringFromSelector(@selector(error))];
        self.receiptData = [aDecoder decodeObjectOfClass:[NSData class] forKey:NSStringFromSelector(@selector(receiptData))];
        self.receiptURL = [aDecoder decodeObjectOfClass:[NSURL class] forKey:NSStringFromSelector(@selector(receiptURL))];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:self.consumed forKey:NSStringFromSelector(@selector(consumed))];
    [aCoder encodeObject:self.productIdentifier forKey:NSStringFromSelector(@selector(productIdentifier))];
    [aCoder encodeObject:self.transactionIdentifier forKey:NSStringFromSelector(@selector(transactionIdentifier))];
    [aCoder encodeObject:self.transactionDate forKey:NSStringFromSelector(@selector(transactionDate))];
    [aCoder encodeObject:self.error forKey:NSStringFromSelector(@selector(error))];
    [aCoder encodeObject:self.receiptData forKey:NSStringFromSelector(@selector(receiptData))];
    [aCoder encodeObject:self.receiptURL forKey:NSStringFromSelector(@selector(receiptURL))];
}

@end
