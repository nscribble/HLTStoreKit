//
//  HLTOrderKeychainStore.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/28.
//

#import "HLTOrderKeychainStore.h"
#import "HLTOrderModel.h"
#import "HLTKeychainStore.h"

static NSString * const HLTKeychainPendingOrders = @"com.hltstorekit.orders.pending";
static NSString * const HLTKeychainBackupOrders = @"com.hltstorekit.orders.backup";

@implementation HLTOrderKeychainStore

- (NSArray<HLTOrderModel *> *)getPendingOrderList {
    NSMutableArray<HLTOrderModel *> *orders =
    [HLTKeychainStore keychainObjectForKey:HLTKeychainPendingOrders accessGroup:nil];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.orderSource = HLTOrderSourcePendingQueue;
    }];
    
    return orders;
}

- (NSArray<HLTOrderModel *> *)getBackedupOrderList {
    NSMutableArray<HLTOrderModel *> *orders =
    [HLTKeychainStore keychainObjectForKey:HLTKeychainBackupOrders accessGroup:nil];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.orderSource = HLTOrderSourceBackupQueue;
    }];
    
    return orders;
}

- (NSArray<HLTOrderModel *> *)getOrderListInQueue:(NSString *)queue {
    if (!queue) {
        return nil;
    }
    
    NSMutableArray<HLTOrderModel *> *orders =
    [HLTKeychainStore keychainObjectForKey:queue accessGroup:nil];
    [orders enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.orderSource = HLTOrderSourceCustomQueue;
    }];
    
    return orders;
}

- (void)storeOrder:(HLTOrderModel *)order inQueue:(NSString *)queue {
    [self _storeOrder:order inQueue:queue];
}

- (void)storeOrder:(HLTOrderModel *)order {
    [self _storeOrder:order inQueue:HLTKeychainPendingOrders];
}

- (void)removeOrder:(HLTOrderModel *)order {
    [self _removeOrder:order inQueue:HLTKeychainPendingOrders];
}

- (void)storeBackupOrder:(HLTOrderModel *)order {
    [self _storeOrder:order inQueue:HLTKeychainBackupOrders];
}

- (void)removeBackupOrder:(HLTOrderModel *)order {
    [self _removeOrder:order inQueue:HLTKeychainBackupOrders];
}

- (void)_storeOrder:(HLTOrderModel *)order inQueue:(NSString *)keychainQueueType {
    HLTLog(@"[Keychain] store: %@ in %@", order, keychainQueueType);
    if (!order || ![order isKindOfClass:[HLTOrderModel class]]) {
        HLTLog(@"[Keychain] storing order is not kind of HLTOrderModel");
        return;
    }
    
    NSArray<HLTOrderModel *> *orderList = (NSArray *)[HLTKeychainStore keychainObjectForKey:keychainQueueType accessGroup:nil];
    if (!orderList) {
        HLTLog(@"[Keychain] orderList = nil");
    }
    if (orderList && ![orderList isKindOfClass:[NSArray class]]) {
        HLTLog(@"[Keychain] orderList not valid");
        orderList = nil;
    }
    
    orderList =
    [self inOrderList:orderList matching:order action:^(HLTOrderModel *matching, NSInteger index, NSMutableArray<HLTOrderModel *> *orderListM) {
        if (matching && index != NSNotFound) {
            [orderListM replaceObjectAtIndex:index withObject:order];
        } else {
            [orderListM addObject:order];
        }
    }];
    
    [HLTKeychainStore setKeychainObject:orderList forKey:keychainQueueType accessGroup:nil];
}

- (void)_removeOrder:(HLTOrderModel *)order inQueue:(NSString *)keychainQueueType {
    HLTLog(@"[Keychain] remove order %@ in %@", order, keychainQueueType);
    if (!order || ![order isKindOfClass:[HLTOrderModel class]]) {
        HLTLog(@"[Keychain] storing order is not kind of HLTOrderModel");
        return;
    }
    
    NSArray<HLTOrderModel *> *orderList = (NSArray *)[HLTKeychainStore keychainObjectForKey:keychainQueueType accessGroup:nil];
    if (!orderList) {
        HLTLog(@"[Keychain] orderList = nil");
        return;
    }
    if (![orderList isKindOfClass:[NSArray class]]) {
        HLTLog(@"[Keychain] orderList not valid");
        orderList = nil;
    }
    
    orderList =
    [self inOrderList:orderList matching:order action:^(HLTOrderModel *matching, NSInteger index, NSMutableArray<HLTOrderModel *> *orderListM) {
        if (matching && index != NSNotFound) {
            [orderListM removeObjectAtIndex:index];
        }
    }];
    
    [HLTKeychainStore setKeychainObject:orderList forKey:keychainQueueType accessGroup:nil];
}

/**
 检查队列中匹配的对象并处理
 
 @param orderList 订单队列
 @param order 待匹配对象
 @param action 匹配后处理
 @return 处理后的队列
 */
- (NSArray<HLTOrderModel *> *)inOrderList:(NSArray<HLTOrderModel *> *)orderList matching:(HLTOrderModel *)order action:(void(^)(HLTOrderModel *matching, NSInteger index, NSMutableArray<HLTOrderModel *> *orderListM))action {
    if (action == NULL) {
        return orderList;
    }
    
    __block BOOL found = NO;
    NSMutableArray *orderListM = [NSMutableArray arrayWithArray:orderList];
    [orderList enumerateObjectsUsingBlock:^(HLTOrderModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:[HLTOrderModel class]]) {
            return ;
        }
        
        if ([obj isEqualToOrder:order]) {
            action(obj, idx, orderListM);
            *stop = YES;
            found = YES;
        }
    }];
    
    if (!found) {
        action(nil, NSNotFound, orderListM);
    }
    
    return orderListM;
}

#pragma mark -

- (void)dropPendingQueue {
    [HLTKeychainStore setKeychainObject:nil forKey:HLTKeychainPendingOrders accessGroup:nil];
}

- (void)dropBackupQueue {
    [HLTKeychainStore setKeychainObject:nil forKey:HLTKeychainBackupOrders accessGroup:nil];
}

@end
