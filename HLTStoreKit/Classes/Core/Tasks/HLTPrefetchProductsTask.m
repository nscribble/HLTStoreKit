//
//  HLTPrefetchProductsTask.m
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import "HLTPrefetchProductsTask.h"
#import <StoreKit/SKProductsRequest.h>
#import <StoreKit/SKProduct.h>

@interface HLTPrefetchProductsTask ()
<
SKRequestDelegate
>

@property (nonatomic, copy) NSArray<NSString *> *productIdentifiers;
@property (nonatomic, copy) HLTProductRequestCompletion completion;

@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;

@end

@implementation HLTPrefetchProductsTask

@synthesize finished = _finished, executing = _executing;

- (instancetype)initWithProductIdentifiers:(NSArray<NSString *> *)productIdentifiers completion:(HLTProductRequestCompletion)completion {
    if (self = [super init]) {
        _productIdentifiers = productIdentifiers;
        _completion = completion;
    }
    
    return self;
}

#pragma mark

- (void)start {
    @autoreleasepool {
        if (self.isCancelled) {
            self.finished = YES;
            return;
        }
        if (!self.isReady) {
            HLTLog(@"task is not ready");
            return;
        }
        
        [self startTask];
        self.executing = YES;
    }
}

- (void)startTask {
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:self.productIdentifiers]];
    request.delegate = self;
    
    [request start];
}

- (void)finishTask {
    HLTLog(@"[Payment] task finish: %@", self);
    if (self.isFinished && !self.executing) {
        HLTLog(@"Do not finishTask twice!");
        return;
    }
    
    self.finished = YES;
    self.executing = NO;
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.invalidProductIdentifiers.count > 0) {
        HLTLogParams(@{HLTLogEventKey: @"iap_product_invalid",
                       @"productIds": (self.productIdentifiers ?: @"productIdNil"),
                       }, @"[Task] Prefetch Invalid Products.IDs: %@", response.invalidProductIdentifiers);
    }
    
    HLTLogParams(@{HLTLogEventKey: kLogEvent_SKProductSuccess,
                   @"products": ([response.products valueForKeyPath:@"productIdentifier"] ?: @"")
                 }, @"SKProduct fetched");
    if (self.completion) {
        self.completion(response.products, nil);
    }
    //[self finishTask];
}


- (void)requestDidFinish:(SKRequest *)request {
    HLTLog(@"[Task] Prefetch Products Finished : %@", request);
    [self finishTask];
}

/// The requestDidFinish: method is not called after this method is called.
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    HLTLogParams(@{HLTLogEventKey: kLogEvent_PrefetchProductsFailed,
                   HLTLogErrorKey: (error ?: @"errorNil"),
                   @"productIds": (self.productIdentifiers ?: @"productIdNil"),
                   }, @"[Task] %@ failed: %@", request, error);
    
    if (self.completion) {
        self.completion(nil, error);
    }
    [self finishTask];
}

@end
