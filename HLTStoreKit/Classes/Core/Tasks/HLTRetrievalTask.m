//
//  HLTRetrievalTask.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "HLTRetrievalTask.h"

@interface HLTRetrievalTask ()
@end

@implementation HLTRetrievalTask

- (instancetype)initWithProductId:(NSString *)productId completion:(HLTPaymentCompletion)completion {
    NSAssert(NO, @"不允许使用该方法初始化");
    return nil;
}

- (instancetype)initWithOrder:(HLTOrderModel *)order skTransaction:(SKPaymentTransaction *)skTransaction completion:(HLTPaymentCompletion)completion {
    if (self = [super init]) {
        _order = order;
        _completion = completion;
        [_order updateWithSKPaymentTransaction:skTransaction];
    }
    
    return self;
}

- (void)dealloc {
    HLTLog(@"%@ dealloc", NSStringFromClass(self.class));
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[Task.Retrival][%@][%@][%@]", self.productId, self.order.orderId,self.order.orderStatusDescription];
}

#pragma mark -

- (void)startTask {
    //self.order.orderStatus = HLTOrderStatusPrepare;
    _startTime = [[NSDate date] timeIntervalSince1970];
    if ([self.delegate respondsToSelector:@selector(taskWillStart:)]) {
        [self.delegate taskWillStart:self];
    }
    
    @try {
        [self continueOnTransactionPurchased:self.order.skTransaction];
    } @catch (NSException *exception) {
        HLTLog(@"[Payment] exception: %@", exception);
    } @finally {
    }
}

@end
