//
//  HLTRefreshReceiptTask.h
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLTRefreshReceiptTask : NSOperation

- (instancetype)initWithCompletion:(HLTReceiptRefreshCompletion)completion;

@end

NS_ASSUME_NONNULL_END
