//
//  HLTPrefetchProductsTask.h
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLTPrefetchProductsTask : NSOperation

- (instancetype)initWithProductIdentifiers:(NSArray <NSString *> *)productIdentifiers
                                completion:(HLTProductRequestCompletion)completion;

@end

NS_ASSUME_NONNULL_END
