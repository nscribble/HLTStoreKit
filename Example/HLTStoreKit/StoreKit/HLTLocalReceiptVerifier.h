//
//  HLTLocalReceiptVerifier.h
//  HLTStoreKit_Example
//
//  Created by Ryan on 2020/11/13.
//  Copyright © 2020 nscribble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HLTStoreKit/HLTStoreKitPredefined.h>

NS_ASSUME_NONNULL_BEGIN

@interface HLTLocalReceiptVerifier : NSObject<HLTOrderVerifier>

- (void)verifyOrder:(HLTOrderModel *)order success:(void (^)(HLTOrderModel *))successBlock failure:(void (^)(NSError *))failureBlock;

@end

NS_ASSUME_NONNULL_END
