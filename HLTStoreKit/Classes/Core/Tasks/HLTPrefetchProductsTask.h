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

@property (nonatomic, copy, readonly) NSString *taskKey;// 不代表唯一性，仅代表任务等同性

- (instancetype)initWithProductIdentifiers:(NSArray <NSString *> *)productIdentifiers
                                completion:(HLTProductRequestCompletion)completion;

+ (NSString *)taskKeyForProductIdentifiers:(NSArray <NSString *> *)productIdentifiers;

@end

NS_ASSUME_NONNULL_END
