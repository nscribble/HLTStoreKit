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

+ (void)injectCertificate:(NSURL *)certURL {
    [RMAppReceipt setAppleRootCertificateURL:certURL];
}

- (RMStoreAppReceiptVerifier *)rm_verifier {
    if (!_rm_verifier) {
        _rm_verifier = [RMStoreAppReceiptVerifier new];
    }
    
    return _rm_verifier;
}

- (void)verifyOrder:(HLTOrderModel *)order success:(void (^)(HLTOrderModel *, NSDictionary *))successBlock failure:(void (^)(NSError *))failureBlock {
    RMAppReceipt *rcpt = [RMAppReceipt bundleReceipt];
    HLTLog(@"rcpt: %@", rcpt);
    
    BOOL result = [self.rm_verifier verifyAppReceipt];
    NSTimeInterval delay = arc4random() % 5 + 5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (result) {
            !successBlock ?: successBlock(order, nil);
        } else {
            NSError *error = [NSError errorWithDomain:@"com.hltstore.error" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"验证订单失败"}];
            !failureBlock ?: failureBlock(error);
        }
    });
}


@end
