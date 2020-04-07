//
//  SKProductsRequest+Ext.m
//  HLTStoreKit
//
//  Created by cc on 2018/5/26.
//

#import "SKProductsRequest+Ext.h"
#import <objc/runtime.h>

@implementation SKProductsRequest (Ext)

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p>-%@", NSStringFromClass(self.class), self,  self.hlt_productIdentifier];
}

- (NSString *)hlt_productIdentifier {
    return objc_getAssociatedObject(self, @selector(hlt_productIdentifier));
}

- (void)setHlt_productIdentifier:(NSString *)hlt_productIdentifier {
    objc_setAssociatedObject(self, @selector(hlt_productIdentifier), hlt_productIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
