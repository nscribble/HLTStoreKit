//
//  HLTKeychain.m
//  bite
//
//  Created by nscribble on 2018/5/22
//

#import "HLTKeychainStore.h"
#import <Security/Security.h>
//#import "HLTKeychainQuery.h"

// TODO: 访问Safari共享密码
//SecRequestSharedWebCredential
//SecAddSharedWebCredential

NSString * const HLTKeychainErrorDomain = @"com.keychain.error";
NSString * const HLTKeychainAccountKey = @"com.keychain.account";
NSString * const kHLTKeychainServiceKey = @"com.keychain.service";

//! 通用存储
NSString * const kHLTKeychainServiceGenericStore = @"com.keychain.service.generic";
//! 通用存储key前缀
NSString * const kHLTKeychainServiceGenericStorePrefix = @"m3xJ#w.";

#pragma mark - Keychain

NSMutableDictionary* HLTKeychainPrepareSearchDictionary(NSString *key, NSString *service, NSString *accessGroup)
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    
    NSData *encodedIdentifier = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    dictionary[(__bridge id)kSecAttrGeneric] = encodedIdentifier;
    dictionary[(__bridge id)kSecAttrAccount] = encodedIdentifier;
    
    NSString *serviceName = service ?: [NSBundle mainBundle].bundleIdentifier;
    dictionary[(__bridge id)kSecAttrService] = serviceName;
    
    if (accessGroup) {
        dictionary[(__bridge id)kSecAttrAccessGroup] = accessGroup;
    }
    
    return dictionary;
}

BOOL HLTKeychainSetValue(NSData *value, NSString *key, NSString *service, NSString *accessGroup)
{
    NSMutableDictionary *searchDictionary = HLTKeychainPrepareSearchDictionary(key, service, accessGroup);
    OSStatus status = errSecSuccess;
    CFTypeRef ignore;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, &ignore) == errSecSuccess)
    { // Update
        if (!value)
        {
            status = SecItemDelete((__bridge CFDictionaryRef)searchDictionary);
        } else {
            NSMutableDictionary *updateDictionary = [NSMutableDictionary dictionary];
            updateDictionary[(__bridge id)kSecValueData] = value;
            status = SecItemUpdate((__bridge CFDictionaryRef)searchDictionary, (__bridge CFDictionaryRef)updateDictionary);
        }
    }
    else if (value)
    { // Add
        searchDictionary[(__bridge id)kSecValueData] = value;
        status = SecItemAdd((__bridge CFDictionaryRef)searchDictionary, NULL);
    }
    if (status != errSecSuccess)
    {
        NSLog(@"HLTStoreKeychainPersistence: failed to set key %@ with error %ld.", key, (long)status);
    }
    return status == errSecSuccess;
}

NSData* HLTKeychainGetValue(NSString *key, NSString *service, NSString *accessGroup)
{
    NSMutableDictionary *searchDictionary = HLTKeychainPrepareSearchDictionary(key, service, accessGroup);
    searchDictionary[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    searchDictionary[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
    
    CFDataRef value = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, (CFTypeRef *)&value);
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        NSLog(@"HLTStoreKeychainPersistence: failed to get key %@ with error %ld.", key, (long)status);
    }
    return (__bridge NSData*)value;
}

NSObject<NSCoding>* HLTKeychainGetObject(NSString *key)
{
    NSData *data = HLTKeychainGetValue(key, kHLTKeychainServiceGenericStore, nil);
    NSObject *object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return object;
}

BOOL HLTKeychainSetObject(NSObject<NSCoding> *object, NSString *key)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    return HLTKeychainSetValue(data, key, kHLTKeychainServiceGenericStore, nil);
}

#pragma mark -

@interface HLTKeychainStore ()


/**
 *  @brief 查询密码
 *
 *  @param service     服务名称
 *  @param account     帐户名称
 *  @param accessGroup 访问组(nil则系统默认为本应用bundleid，下同)
 *  @param error       错误信息
 *
 *  @return 查询到的密码
 */
+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account accessGroup:(NSString *)accessGroup error:(NSError **)error;

/**
 *  @brief 设置密码
 *
 *  @param password    密码，若nil则删除密码
 *  @param service     服务名称
 *  @param account     帐户名称
 *  @param accessGroup 访问组，默认nil则为本应用
 *  @param error       错误信息
 *
 *  @return 是否操作成功
 */
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account accessGroup:(NSString *)accessGroup error:(NSError **)error;

@end

@implementation HLTKeychainStore

#pragma mark
/*
+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account accessGroup:(NSString *)accessGroup error:(NSError **)error
{
    HLTKeychainQuery *query = [[HLTKeychainQuery alloc] init];
    query.service = service;
    query.account = account;
    query.accessGroup = accessGroup;
    
    [query fetched:error];
    
    return query.password;
}

+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account accessGroup:(NSString *)accessGroup error:(NSError **)error
{
    HLTKeychainQuery *query = [[HLTKeychainQuery alloc] init];
    query.service = service;
    query.account = account;
    query.accessGroup = accessGroup;
    query.password = password;
    
    BOOL success;
    if (password){
        success = [query saved:error];
    }
    else{
        success = [query deleted:error];
    }
    
    return success;
}*/

+ (id<NSCoding>)keychainObjectForKey:(NSString *)aKey accessGroup:(NSString *)accessGroup
{
    return HLTKeychainGetObject(aKey);
}

+ (BOOL)setKeychainObject:(id<NSCoding>)object forKey:(NSString *)aKey accessGroup:(NSString *)accessGroup
{
    return HLTKeychainSetObject(object, aKey);
}

@end
