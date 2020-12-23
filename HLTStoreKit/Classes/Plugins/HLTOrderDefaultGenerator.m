//
//  HLTOrderDefaultGenerator.m
//  HLTStoreKit
//
//  Created by nscribble on 2018/5/29.
//

#import "HLTOrderDefaultGenerator.h"
#import "NSObject+Ext.h"
#import "HLTStoreKitPredefined.h"
#import "HLTOrderModel.h"

static NSInteger const kOrderCreateMaxTryCount = 2;

@class HLTOrderGeneratorReq;

typedef NS_ENUM(NSInteger, HLTOrderReqStatus) {
    HLTOrderReqStatusPrepare,
    HLTOrderReqStatusProcessing,
    HLTOrderReqStatusRetrying,
    HLTOrderReqStatusFinished,
    HLTOrderReqStatusTimeout,
};

static HLTOrderGenReqProcessingBlock hlt_orderGenReqProcessingBlock;

@interface HLTOrderGeneratorReq()

@property (nonatomic,strong,readwrite) HLTOrderModel *voidOrder;
@property (nonatomic,copy,readwrite) NSString *productId;
@property (nonatomic,copy) HLTOrderGeneratorReqCompletion completion;
@property (nonatomic,assign) HLTOrderReqStatus reqStatus;
@property (nonatomic,assign) NSTimeInterval   perReqTimeout;// 默认30s超时
@property (nonatomic,strong,readwrite) NSDictionary *userInfo;
@property (nonatomic,assign) NSInteger retryCount;
@property (nonatomic,assign) NSTimeInterval retryDelay;

@end

@implementation HLTOrderGeneratorReq

- (instancetype)initWithOrderPlaceholder:(HLTOrderModel *)order completion:(HLTOrderGeneratorReqCompletion)completion {
    if (self = [super init]) {
        _voidOrder = order;
        _productId =  order.productId;
        _completion = completion;
        _reqStatus = HLTOrderReqStatusPrepare;
        _perReqTimeout = 61;// http请求超时设定为60
        _retryDelay = 5;
    }
    
    return self;
}

- (void)start {
    NSAssert(hlt_orderGenReqProcessingBlock != NULL, @" error ");
    if (!hlt_orderGenReqProcessingBlock) {
        if (self.completion) {
            NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCreateOrderFailed
                                              description:@"未接入订单创建服务，无法创建订单"];
            self.completion(self, nil, err);
        }
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.reqStatus = HLTOrderReqStatusProcessing;
    hlt_orderGenReqProcessingBlock(self, ^(HLTOrderGeneratorReq *request, HLTOrderModel * _Nullable order,  NSError * _Nullable error) {
        if (!weakSelf) {
            return ;
        }
        
        if (order == nil || error != nil) {
            HLTLog(@"order create failed: %@", error);
            if ([weakSelf shouldRetryGenerating:error]) {
                [weakSelf retryGeneratingOrderOnError:error];
                return;
            }
        }
        
        if (weakSelf.reqStatus == HLTOrderReqStatusFinished) {
            HLTLog(@"order create callback after finished!");
            return;
        }
        
        weakSelf.reqStatus = HLTOrderReqStatusFinished;
        if (weakSelf.completion) {
            weakSelf.completion(request, order, error);
        }
        [weakSelf cancelTimeoutCheck];
    });
    
    // 超时处理
    [self cancelTimeoutCheck];
    if (self.perReqTimeout > 0) {
        [self performSelector:@selector(onReqTimeout) withObject:nil afterDelay:(self.perReqTimeout)];
    }
}

- (void)cancelTimeoutCheck {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onReqTimeout) object:nil];
}

- (void)onReqTimeout {
    if (self.reqStatus != HLTOrderReqStatusFinished &&
        self.completion != NULL) {
        self.reqStatus = HLTOrderReqStatusTimeout;
        NSError *err = [self ht_storeKitErrorWithCode:HLTPaymentErrorCreateOrderFailed
                                          description:@"创建订单超时"];
        self.completion(self, nil, err);
    }
}

- (BOOL)shouldRetryGenerating:(NSError *)error  {
    if (self.reqStatus == HLTOrderReqStatusFinished) {
        return NO;
    }
    
    if (self.retryCount < kOrderCreateMaxTryCount - 1) {
//        if ([error.domain isEqualToString:NSURLErrorDomain]) {
            return YES;
//        }
    }
    
    return NO;
}

- (void)retryGeneratingOrderOnError:(NSError *)error {// toast?
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


#pragma mark - HLTOrderDefaultGenerator

@interface HLTOrderDefaultGenerator ()

@property (nonatomic, strong) NSMutableArray<HLTOrderGeneratorReq *> *requests;

@end

@implementation HLTOrderDefaultGenerator

+ (void)setRequestProcessingBlock:(HLTOrderGenReqProcessingBlock)processingBlock {
    hlt_orderGenReqProcessingBlock = processingBlock;
}

- (NSMutableArray<HLTOrderGeneratorReq *> *)requests {
    if (!_requests) {
        _requests = [NSMutableArray<HLTOrderGeneratorReq *> array];
    }
    
    return _requests;
}

- (void)generateOrder:(HLTOrderModel *)voidOrder
              success:(void (^)(HLTOrderModel *order))successBlock
              failure:(void (^)(NSError *error))failureBlock; {
    __weak typeof(self) weakSelf = self;
    HLTOrderGeneratorReq *req = [[HLTOrderGeneratorReq alloc] initWithOrderPlaceholder:voidOrder completion:^(HLTOrderGeneratorReq * _Nonnull request, HLTOrderModel * _Nullable order, NSError * _Nullable error) {
        if (!order || error) {
            if (failureBlock) {
                failureBlock(error);
            }
        } else {
            if (successBlock) {
                successBlock(order);
            }
        }
        
        [weakSelf.requests removeObject:request];
    }];
    [self.requests addObject:req];
    [req start];
}

@end
