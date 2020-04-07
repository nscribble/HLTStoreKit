//
//  HLTOrderDefaultVerifier.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/29.
//

#import "HLTOrderDefaultVerifier.h"
#import "NSObject+Ext.h"
#import "HLTOrderModel.h"

typedef NS_ENUM(NSInteger, HLTVerifyReqStatus) {
    HLTVerifyReqStatusPrepare,
    HLTVerifyReqStatusProcessing,
    HLTVerifyReqStatusRetrying,
    HLTVerifyReqStatusFinished,
};

static HLTOrderVerifyProcessingBlock hlt_orderVerifyProcessingBlock;
static NSInteger const kOrderVerifyMaxTryCount = 3;

@interface HLTOrderVerifierReq ()

@property (nonatomic,strong,readwrite) HLTOrderModel *order;
@property (nonatomic,copy) HLTOrderVerifyCompletion completion;
@property (nonatomic,assign) HLTVerifyReqStatus reqStatus;
@property (nonatomic,assign) NSTimeInterval   startTime;
@property (nonatomic,assign) NSTimeInterval   perReqTimeout;// 默认30s超时
@property (nonatomic,assign) NSInteger retryCount;
@property (nonatomic,assign) NSTimeInterval retryDelay;

@end

@implementation HLTOrderVerifierReq

- (instancetype)initWithOrder:(HLTOrderModel *)order completion:(HLTOrderVerifyCompletion)completion {
    if (self = [super init]) {
        _order = order;
        _completion = completion;
        _reqStatus = HLTVerifyReqStatusPrepare;
        _perReqTimeout = 61;
        _retryDelay = 5;
    }
    
    return self;
}

- (void)start {
    NSAssert(hlt_orderVerifyProcessingBlock != NULL, @" error ");
    if (!hlt_orderVerifyProcessingBlock) {
        if (self.completion) {
            NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCreateOrderFailed
                                              description:@"未接入订单验证服务，无法验证订单"];
            self.completion(self, NO, err);
        }
        return;
    }
    
    if (self.startTime <= 0) {
        self.startTime = [[NSDate date] timeIntervalSince1970];
    }
    
    __weak typeof(self) weakSelf = self;
    if (self.reqStatus < HLTVerifyReqStatusProcessing) {
        self.reqStatus = HLTVerifyReqStatusProcessing;
    } else {
        self.reqStatus = HLTVerifyReqStatusRetrying;
    }
    // 注意：最好确保超时一致，以免出现超时重试后，后续又接收到回调 todo: 
    hlt_orderVerifyProcessingBlock(self, ^(HLTOrderVerifierReq *request, BOOL success, NSError * _Nullable error) {
        if (!weakSelf) {
            return ;
        }
        
        if (!success || error != nil) {
            HLTLog(@"order verify failed: %@", error);
            if ([weakSelf shouldRetryVerifying:error]) {
                [weakSelf retryVerifyingOrderOnError:error];
                return;
            }
        }
        
        // 失败
        weakSelf.reqStatus = HLTVerifyReqStatusFinished;
        if (weakSelf.completion) {
            weakSelf.completion(request, success, error);
        }
        [weakSelf cancelTimeoutCheck];
    });
    
    // 超时处理
    [self cancelTimeoutCheck];
    if (self.perReqTimeout > 0) {
        [self performSelector:@selector(onReqTimeout) withObject:nil afterDelay:(self.perReqTimeout + self.retryDelay)];
    }
}

- (void)cancelTimeoutCheck {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onReqTimeout) object:nil];
}

- (void)onReqTimeout {
    if (self.reqStatus != HLTVerifyReqStatusFinished &&
        self.completion != NULL) {
        NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCreateOrderFailed
                                          description:@"验证订单超时"];
        self.completion(self, NO, err);
    }
}

- (BOOL)shouldRetryVerifying:(NSError *)error {
    if (self.reqStatus == HLTVerifyReqStatusFinished) {
        return NO;
    }
    
    if (self.retryCount < kOrderVerifyMaxTryCount - 1) {
        if ([error.domain isEqualToString:NSURLErrorDomain]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)retryVerifyingOrderOnError:(NSError *)error {
    self.retryCount += 1;
    if ([error.domain isEqualToString:NSURLErrorDomain] &&
        (error.code == NSURLErrorTimedOut ||
         error.code == NSURLErrorCannotConnectToHost ||
         error.code == NSURLErrorNotConnectedToInternet ||
         error.code == NSURLErrorBadServerResponse)
        ) {
        self.perReqTimeout += 5 * self.retryCount;
    }
    
    [self performSelector:@selector(start) withObject:nil afterDelay:self.retryDelay];
    self.retryDelay += 5 * self.retryCount;
}

@end

#pragma mark - HLTOrderDefaultVerifier

@interface HLTOrderDefaultVerifier ()

@property (nonatomic,strong) NSMutableArray<HLTOrderVerifierReq *> *requests;

@end

@implementation HLTOrderDefaultVerifier

+ (void)setRequestProcessingBlock:(HLTOrderVerifyProcessingBlock)processingBlock {
    hlt_orderVerifyProcessingBlock = processingBlock;
}

- (NSMutableArray<HLTOrderVerifierReq *> *)requests {
    if (!_requests) {
        _requests = [NSMutableArray<HLTOrderVerifierReq *> array];
    }
    
    return _requests;
}

- (void)verifyOrder:(HLTOrderModel *)order success:(void (^)(HLTOrderModel *))successBlock failure:(void (^)(NSError *))failureBlock {
    __weak typeof(self) weakSelf = self;
    HLTOrderVerifierReq *req = [[HLTOrderVerifierReq alloc] initWithOrder:order completion:^(HLTOrderVerifierReq * _Nonnull request, BOOL success, NSError * _Nullable error) {
        if (!success || error) {
            !failureBlock ?: failureBlock(error);
        } else {
            !successBlock ?: successBlock(order);
        }
        
        [weakSelf.requests removeObject:request];
    }];
    
    [self.requests addObject:req];
    [req start];
}

@end
