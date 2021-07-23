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
#import "RMAppReceipt.h"
#import <HLTStoreKit/HLTPaymentQueue.h>

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
    
    [self testOrderSorting];
}

- (void)initConfiguration {
    [[HLTStoreKit defaultStore] prefetchProducts:@[@"com.moment.coins12", @"com.moment.vip1"]];
}

- (void)onTapBtn:(UIButton *)button {
    
    NSString *productId = @"com.moment.coins12";
//    productId = @"com.moment.vip1";
//    productId = @"com.moment.svip1";
        
    [[HLTStoreKit defaultStore] purchase:productId configuration:^(id<HLTOrderConfiguration> configuration) {
    } completion:^(NSString *productId, NSString *orderId, NSError *error) {
    }];
    
    //[[HLTStoreKit defaultStore] refreshPaymentReceipts:NULL];
//    [[HLTStoreKit defaultStore] restoreTransactions];
    
    NSArray *tids = [[[RMAppReceipt bundleReceipt] inAppPurchases] valueForKeyPath:@"transactionIdentifier"];
    HLTLog(@"tids: %@", tids);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray *tids = [[[RMAppReceipt bundleReceipt] inAppPurchases] valueForKeyPath:@"transactionIdentifier"];
        HLTLog(@"delay tids: %@", tids);
    });
}

- (void)testOrderSorting {
    NSMutableArray<HLTOrderModel *> *orderList = @[].mutableCopy;
    
    HLTOrderModel *order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.coins12"];
    order.orderId = @"1000001";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderCreated;
    order.orderStatus = HLTOrderStatusPurchasing;
    order.orderStatus = HLTOrderStatusPurchaseFailed;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.coins12"];
    order.orderId = @"1000002";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderFailed;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.coins12"];
    order.orderId = @"1000003";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderCreated;
    order.orderStatus = HLTOrderStatusPurchasing;
    order.orderStatus = HLTOrderStatusPurchased;
    order.orderStatus = HLTOrderStatusReceiptVerifying;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.coins12"];
    order.orderId = @"1000004";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderCreated;
    order.orderStatus = HLTOrderStatusPurchasing;
    order.orderStatus = HLTOrderStatusPurchaseFailed;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.coins12"];
    order.orderId = @"1000005";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderCreated;
    order.orderStatus = HLTOrderStatusPurchasing;
//    order.orderStatus = HLTOrderStatusPurchased;
//    order.orderStatus = HLTOrderStatusReceiptVerifying;
//    order.orderStatus = HLTOrderStatusReceiptFailed;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    order = [[HLTOrderModel alloc] initWithProductId:@"com.moment.svip"];
    order.orderId = @"1000006";
    order.orderStatus = HLTOrderStatusPrepare;
    order.orderStatus = HLTOrderStatusOrderCreating;
    order.orderStatus = HLTOrderStatusOrderCreated;
    order.orderStatus = HLTOrderStatusPurchasing;
    order.orderStatus = HLTOrderStatusPurchaseFailed;
    [[HLTStoreKit defaultStore].orderPersistence storeBackupOrder:order];
    [orderList addObject:order];
    
    [orderList filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLTOrderModel * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject.productId isEqual:@"com.moment.coins12"] && evaluatedObject.orderStatus > HLTOrderStatusOrderCreated;
    }]];
    
    NSLog(@"orderList: %@", orderList);
    NSArray *result = [[HLTPaymentQueue defaultQueue] sortedOrderList:orderList];
    NSLog(@"sorted: %@", result);
}

@end
