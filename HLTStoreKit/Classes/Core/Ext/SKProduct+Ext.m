//
//  SKProduct+Ext.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/26.
//

#import "SKProduct+Ext.h"

@implementation SKProduct (Ext)

+ (NSString*)localizedPriceOfProduct:(SKProduct*)product
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    numberFormatter.locale = product.priceLocale;
    NSString *formattedString = [numberFormatter stringFromNumber:product.price];
    return formattedString;
}

@end
