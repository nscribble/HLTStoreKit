//
//  SKProduct+Ext.h
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/26.
//

#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKProduct (Ext)

+ (NSString*)localizedPriceOfProduct:(SKProduct*)product;

@end

NS_ASSUME_NONNULL_END
