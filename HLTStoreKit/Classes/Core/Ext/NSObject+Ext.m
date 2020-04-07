//
//  NSObject+Error.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/22.
//

#import "NSObject+Ext.h"

@implementation NSObject (Ext)

- (NSError *)ht_storeKitErrorWithCode:(HLTPaymentErrorCode)code description:(NSString *)description {
    NSError *error = [NSError errorWithDomain:HLTStoreKitErrorDomain
                                         code:code
                                     userInfo:@{NSLocalizedDescriptionKey: (description ?: @"交易失败")}];
    return error;
}

- (NSData *)keyArchivedData:(BOOL)secureCoding {
    if (![self conformsToProtocol:@protocol(NSCoding)]) {
        NSLog(@"%@ do not conform to NSCoding", self);
        return nil;
    }
    if (secureCoding &&
        (![self conformsToProtocol:@protocol(NSSecureCoding)])) {
        NSLog(@"%@ do not conform to NSSecureCoding", self);
        return nil;
    }
    
    NSData *data = nil;
    if (@available(iOS 11.0, *)) {
        NSError *error = nil;
        data = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:secureCoding error:&error];
        if (error) {
            NSLog(@"keyArchived failed: %@", error);
        }
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:self];
    }
    
    return data;
}

+ (instancetype)keyUnarchivedObjectFromData:(NSData *)data {
    if (![self conformsToProtocol:@protocol(NSCoding)]) {//todo:??
        NSLog(@"%@ do not conform to NSCoding", self);
        return nil;
    }
    
    id obj = nil;
    if (@available(iOS 11.0, *)) {
        NSError *error = nil;
        obj = [NSKeyedUnarchiver unarchivedObjectOfClass:self fromData:data error:&error];
        if (error) {
            NSLog(@"keyUnarchived failed: %@", error);
        }
    } else {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return obj;
}

@end
