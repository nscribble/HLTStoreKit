//
//  HLTOrderOnDeviceVerfier.m
//  HLTStoreKit
//
//  Created by Ryan on 2020/11/12.
//

#import "HLTOrderOnDeviceVerfier.h"
#import "HLTOrderModel.h"
#import <StoreKit/SKPaymentTransaction.h>

@interface HLTOrderOnDeviceVerfier ()

@end

@implementation HLTOrderOnDeviceVerfier

- (void)verifyOrder:(HLTOrderModel *)order success:(void (^)(HLTOrderModel * _Nonnull))successBlock failure:(void (^)(NSError * _Nonnull))failureBlock {
    SKPaymentTransaction *transaction = order.skTransaction;
    NSData *receiptData = transaction.transactionReceipt;
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    HLTLog(@".receipt: %@", receiptData);
    
    if (!receiptData && [[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
        receiptData = [NSData dataWithContentsOfURL:receiptURL];
    }
    NSString *base64Rcpt = [receiptData base64EncodedStringWithOptions:0];
    
    NSMutableDictionary *reqParams = @{}.mutableCopy;
    reqParams[@"receipt-data"] = base64Rcpt;
    reqParams[@"exclude-old-transactions"] = @(1);
    if (self.sharedCredential) {
        reqParams[@"password"] = self.sharedCredential;
    }
    
    NSError *error = nil;
    NSData *reqJSONData = [NSJSONSerialization dataWithJSONObject:reqParams options:NSJSONWritingFragmentsAllowed error:&error];
    if (reqJSONData && !error) {
        [self validateReceipt:reqJSONData order:order success:successBlock failure:failureBlock];
    }
}

- (void)validateReceipt:(NSData *)httpBody order:(HLTOrderModel *)order success:(void (^)(HLTOrderModel * _Nonnull))successBlock failure:(void (^)(NSError * _Nonnull))failureBlock  {
    NSURL *validateURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:validateURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = httpBody;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        HLTLog(@"[Store] receipt validation finished! %@", error)
        if (error) {
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *respObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments|NSJSONReadingMutableContainers error:&jsonError];
        if (jsonError) {
            HLTLog(@"jsonError: %@", jsonError);
        }
        
        NSInteger status = [respObject[@"status"] integerValue];
        if (respObject && status == 0) {// success
            !successBlock ?: successBlock(order);
        }
        else if (status == 21007) {// proceed to verify with the sandbox URL
            [self validateReceiptInSandbox:httpBody
                                     order:order
                                   success:successBlock
                                   failure:failureBlock];
        } else {
            NSError *error = (error ?: jsonError);
            if (!error) {
                error = [NSError errorWithDomain:HLTStoreKitErrorDomain
                                            code:status
                                        userInfo:@{NSLocalizedDescriptionKey: @"On-Device Validation Failed!"}];
            }
            !failureBlock ?: failureBlock(error);
        }
    }];
    [task resume];
}

- (void)validateReceiptInSandbox:(NSData *)httpBody order:(HLTOrderModel *)order success:(void (^)(HLTOrderModel * _Nonnull))successBlock failure:(void (^)(NSError * _Nonnull))failureBlock  {
    NSURL *validateURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:validateURL];
    request.HTTPMethod = @"POST";
    request.HTTPBody = httpBody;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        HLTLog(@"[Store] sandbox receipt validation finished! %@", error)
        if (error) {
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *respObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves|NSJSONReadingAllowFragments|NSJSONReadingMutableContainers error:&jsonError];
        if (jsonError) {
            HLTLog(@"jsonError: %@", jsonError);
        }
        
        NSInteger status = [respObject[@"status"] integerValue];
        if (respObject && status == 0) {// success
            !successBlock ?: successBlock(order);
        } else {
            NSError *error = (error ?: jsonError);
            if (!error) {
                error = [NSError errorWithDomain:HLTStoreKitErrorDomain
                                            code:status
                                        userInfo:@{NSLocalizedDescriptionKey: @"On-Device Validation Failed!"}];
            }
            !failureBlock ?: failureBlock(error);
        }
    }];
    [task resume];
}

@end
