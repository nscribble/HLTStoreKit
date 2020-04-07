//
//  NSError+Ext.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "NSError+Ext.h"

@implementation NSError (Ext)

- (NSError *)errorWithUnderlying:(NSError *)underlyingError {
    if (!underlyingError || self.userInfo[NSUnderlyingErrorKey]) {
        return self;
    }
    
    NSMutableDictionary *mutableUserInfo = [self.userInfo mutableCopy];
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    
    return [[NSError alloc] initWithDomain:self.domain code:self.code userInfo:mutableUserInfo];
}

- (NSError *)underlyingError {
    return self.userInfo[NSUnderlyingErrorKey];
}

@end
