//
//  HLTViewController.m
//  HLTStoreKit
//
//  Created by nscribble on 03/18/2019.
//  Copyright (c) 2019 nscribble. All rights reserved.
//

#import "HLTViewController.h"
#import <HLTStoreKit/HLTStoreKit.h>
#import <HLTStoreKit/HLTOrderDefaultGenerator.h>
#import <HLTStoreKit/HLTOrderDefaultVerifier.h>

@interface HLTViewController ()

@end

@implementation HLTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"测试IAP" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(onTapBtn:) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(60, 100, 200, 68);
    button.center = CGPointMake(CGRectGetWidth(self.view.bounds) / 2, CGRectGetHeight(self.view.bounds)/2);
    button.backgroundColor = [UIColor lightGrayColor];
    button.layer.cornerRadius = 6;
    button.layer.masksToBounds = YES;
    [self.view addSubview:button];
    
    [self initConfiguration];
}

- (void)initConfiguration {
    
}

- (void)onTapBtn:(UIButton *)button {
    
    NSString *productId = @"com.moment.coins12";
//    productId = @"com.moment.vip1";
//    productId = @"com.moment.svip1";
    
    [[HLTStoreKit defaultStore] purchase:productId configuration:^(id<HLTOrderConfiguration> configuration) {
    } completion:^(NSString *productId, NSString *orderId, NSError *error) {
    }];
    
    [[HLTStoreKit defaultStore] refreshPaymentReceipts];
}

@end
