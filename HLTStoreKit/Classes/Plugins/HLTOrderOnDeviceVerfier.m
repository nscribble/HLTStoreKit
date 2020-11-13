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
    HLTLog(@"transactionReceipt: %@", receiptData);
    HLTLog(@"receiptURL: %@", receiptURL);
    
    NSData *rcptAtSandbox = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
        rcptAtSandbox = [NSData dataWithContentsOfURL:receiptURL];
    }
    NSString *base64Rcpt = [rcptAtSandbox base64EncodedStringWithOptions:0];
    NSDictionary *reqDictionary = @{@"receipt-data": base64Rcpt,
                                    @"password": @"a7818c69d3d541488f9c0adfa1ec122e",
                                    @"exclude-old-transactions": @(1)
    };
    
    HLTLog(@"receipt.b64: \n%@", base64Rcpt);
    
    !successBlock ?: successBlock(order);
    return;
    
    NSError *error = nil;
    NSData *reqJSONData = [NSJSONSerialization dataWithJSONObject:reqDictionary options:NSJSONWritingFragmentsAllowed error:&error];
    if (reqJSONData && !error) {
        NSURL *validateURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:validateURL];
        request.HTTPMethod = @"POST";
        request.HTTPBody = reqJSONData;
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
            HLTLog(@"respObject: %@", respObject);
            
            !successBlock ?: successBlock(order);
        }];
        [task resume];
    }
}

@end
