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

@property (nonatomic, copy) NSString *sharedCredential;

@end

NS_ASSUME_NONNULL_END
