//
//  HLTRefreshReceiptTask.m
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/18.
//

#import "HLTRefreshReceiptTask.h"
#import <StoreKit/SKReceiptRefreshRequest.h>

@interface HLTRefreshReceiptTask ()
<
SKRequestDelegate
>

@property (nonatomic, copy) HLTReceiptRefreshCompletion completion;

@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;

@end

@implementation HLTRefreshReceiptTask


@synthesize finished = _finished, executing = _executing;

- (instancetype)initWithCompletion:(HLTReceiptRefreshCompletion)completion {
    if (self = [super init]) {
        _completion = completion;
    }
    
    return self;
}

#pragma mark - Operation Override

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

// 这里需要实现KVO相关的方法，NSOperationQueue是通过KVO来判断任务状态的
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

#pragma mark Tasking

- (void)startTask {
    // TODO: 备份
    SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:@{SKReceiptPropertyIsExpired: @0}];
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

#pragma mark -

- (void)requestDidFinish:(SKRequest *)request {
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        HLTLog(@"凭据已刷新");
        dispatch_async(dispatch_get_main_queue(), ^{
            !self.completion ?: self.completion(nil, [[NSBundle mainBundle] appStoreReceiptURL]);
        });
        
        [self finishTask];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if ([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        HLTLog(@"⚠️凭据刷新失败");
        dispatch_async(dispatch_get_main_queue(), ^{
            !self.completion ?: self.completion(error, nil);
        });
        
        [self finishTask];
    }
}

@end
