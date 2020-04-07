//
//  NSObject+Ext.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import <Foundation/Foundation.h>
#import "HLTStoreKitPredefined.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Ext)

- (NSError *)ht_storeKitErrorWithCode:(HLTPaymentErrorCode)code
                          description:(NSString *)description;

- (NSData *)keyArchivedData:(BOOL)secureCoding;
+ (instancetype)keyUnarchivedObjectFromData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
