//
//  HLTNetwork.h
//  HLTStoreKit_Example
//
//  Created by nscribble on 03/18/2019.
//  Copyright © 2019年 nscribble. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HLTStoreKit/HLTStoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HLTNetwork : NSObject

@end

@class HLTOrderGeneratorReq;
@interface HLTNetwork (IAP)

+ (void)createOrder:(HLTOrderGeneratorReq *)request completion:(void (^)(HLTOrderModel * _Nullable, NSError * _Nullable))completion;
+ (void)verifyOrder:(HLTOrderModel *)order completion:(void (^)(HLTOrderModel * _Nonnull, NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
