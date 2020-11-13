//
//  HLTLocalReceiptVerifier.m
//  HLTStoreKit_Example
//
//  Created by Ryan on 2020/11/13.
//  Copyright © 2020 nscribble. All rights reserved.
//

#import "HLTLocalReceiptVerifier.h"
#import <HLTStoreKit/HLTOrderModel.h>
#import "RMAppReceipt.h"
#import "RMStoreAppReceiptVerifier.h"

@interface HLTLocalReceiptVerifier ()

@property (nonatomic, strong) RMStoreAppReceiptVerifier *rm_verifier;

@end

@implementation HLTLocalReceiptVerifier

- (RMStoreAppReceiptVerifier *)rm_verifier {
    if (!_rm_verifier) {
        _rm_verifier = [RMStoreAppReceiptVerifier new];
    }
    
    return _rm_verifier;
}

- (void)verifyOrder:(HLTOrderModel *)order success:(void (^)(HLTOrderModel * _Nonnull))successBlock failure:(void (^)(NSError * _Nonnull))failureBlock {
    RMAppReceipt *rcpt = [RMAppReceipt bundleReceipt];
    HLTLog(@"rcpt: %@", rcpt);
    
    BOOL result = [self.rm_verifier verifyAppReceipt];
    if (result) {
        !successBlock ?: successBlock(order);
    } else {
        NSError *error = [NSError errorWithDomain:@"com.hltstore.error" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"验证订单失败"}];
        !failureBlock ?: failureBlock(error);
    }
}

@end
