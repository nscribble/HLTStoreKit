//
//  HLTJailbreakDetect.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/28.
//

#import "HLTJailbreakDetect.h"

@implementation HLTJailbreakDetect

+ (BOOL)isJailbreak {
    return [self detectJailBreakByJailBreakFileExisted];
}

+ (BOOL)detectJailBreakByJailBreakFileExisted {
    NSArray *paths = @[@"/Applications/Cydia.app",
                       @"/Library/MobileSubstrate/MobileSubstrate.dylib",
                       @"/bin/bash",
                       @"/usr/sbin/sshd",
                       @"/etc/apt"];
    for (int i = 0; i<paths.count; i++) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:paths[i]]) {
            return YES;
        }
    }
    return NO;
}

@end
