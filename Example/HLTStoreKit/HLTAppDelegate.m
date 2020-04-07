//
//  HLTAppDelegate.m
//  HLTStoreKit
//
//  Created by nscribble on 03/18/2019.
//  Copyright (c) 2019 nscribble. All rights reserved.
//

#import "HLTAppDelegate.h"
#import "HLTStoreKitExample.h"

@implementation HLTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [HLTStoreKitExample setupStoreKit];
    return YES;
}

@end
