//
//  NSError+Ext.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSError (Ext)

- (NSError *)errorWithUnderlying:(NSError *)underlyingError;

- (NSError *)underlyingError;

@end

NS_ASSUME_NONNULL_END
