//
//  HLTNetwork.m
//  HLTStoreKit_Example
//
//  Created by nscribble on 03/18/2019.
//  Copyright © 2019年 nscribble. All rights reserved.
//

#import "HLTNetwork.h"

@implementation HLTNetwork

@end

@implementation HLTNetwork (IAP)

+ (void)createOrder:(HLTOrderGeneratorReq *)request completion:(void (^)(HLTOrderModel * _Nullable order, NSError * _Nullable error))completion {
    HLTOrderModel *order = nil;
    
    // custom network processing
    
    !completion ?: completion(order, nil);
}

+ (void)verifyOrder:(HLTOrderModel *)order completion:(void (^)(HLTOrderModel * _Nonnull, NSError * _Nullable))completion {
    // custom network processing
    
    !completion ?: completion(order, nil);
}

@end
