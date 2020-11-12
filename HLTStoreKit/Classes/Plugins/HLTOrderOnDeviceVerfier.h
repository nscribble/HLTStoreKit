//
//  HLTOrderOnDeviceVerfier.h
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/12.
//

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLTOrderOnDeviceVerfier : NSObject<HLTOrderVerifier>

- (void)verifyOrder:(HLTOrderModel *)order
            success:(void (^)(HLTOrderModel *order))successBlock
            failure:(void (^)(NSError *error))failureBlock;

@end

NS_ASSUME_NONNULL_END
