//
//  HLTKeychainQuery.m
//  bite
//
//  Created by nscribble on 2018/5/22
//

#import "HLTKeychainQuery.h"
#import "HLTKeychainStore.h"

@interface HLTKeychainQuery ()

@end


@implementation HLTKeychainQuery
{
    BOOL _dataModified;
}

@synthesize account = _account;
@synthesize service = _service;
@synthesize accessGroup = _accessGroup;
@synthesize passwordData = _passwordData;
@synthesize password = _password;
@synthesize passwordObject = _passwordObject;

#pragma mark - 外部接口

- (BOOL)saved:(NSError *__autoreleasing *)error
{
    OSStatus status = HLTKeychainErrorCodeBadArguments;
    if (!self.service || !self.account || !self.passwordData) {
        if (error){
            *error = [self errorWithKeychainErrorCode:status];
        }
        return NO;
    }
    
    NSMutableDictionary *query = [self query];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:self.passwordData forKey:(__bridge NSString *)kSecValueData];// 数据
    
    NSString *accessible = (__bridge NSString *)kSecAttrAccessibleWhenUnlocked;
    if (self.accessible == HLTKeychainAccessibleAfterFirstUnlock) {
        accessible = (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlock;
    }
    
    // 访问权限 TODO: 需要支持后台更新访问的话可能需要设置为 kSecAttrAccessibleAfterFirstUnlock
    [attributes setObject:accessible forKey:(__bridge NSString *)kSecAttrAccessible];
    
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, nil);
    if (status == errSecSuccess) {
        status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    }else{
        
        //[attributes setObject:self.label forKey:(__bridge id)kSecAttrLabel]
        [attributes addEntriesFromDictionary:query];
        
        status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    }
    
    if (status != errSecSuccess && error) {
        *error = [self errorWithKeychainErrorCode:status];
    }
    
    return status == errSecSuccess;
}

- (BOOL)fetched:(NSError **)error
{
    OSStatus status = HLTKeychainErrorCodeBadArguments;
    if (!self.account || !self.service) {
        if (error) {
            *error = [self errorWithKeychainErrorCode:status];
        }
        return NO;
    }
    
    NSMutableDictionary *query = [self query];
    [query setObject:@(YES) forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    //测试 kSecReturnAttributes
    
    NSString *accessible = (__bridge id)kSecAttrAccessibleWhenUnlocked;
    if (self.accessible == HLTKeychainAccessibleAfterFirstUnlock) {
        accessible = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    }
    // 访问权限
    [query setObject:accessible forKey:(__bridge id)kSecAttrAccessible];
    
    CFTypeRef result = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        if (error) {
            *error = [self errorWithKeychainErrorCode:status];
        }
        return NO;
    }
    
    self.passwordData = (__bridge NSData *)result;
    
    return YES;
}

- (NSArray *)fetchedAll:(NSError *__autoreleasing *)error
{
    OSStatus status = HLTKeychainErrorCodeBadArguments;
    if (!self.account || !self.service) {
        if (error) {
            *error = [self errorWithKeychainErrorCode:status];
        }
        return nil;
    }
    
    NSMutableDictionary *query = [self query];
    [query setObject:@(YES) forKey:(__bridge NSString*)kSecReturnData];
    [query setObject:(__bridge NSString*)kSecMatchLimitAll forKey:(__bridge NSString *)kSecMatchLimit];
    
    
    // 访问权限
    NSString *accessible = (__bridge NSString *)kSecAttrAccessibleWhenUnlocked;
    if (self.accessible == HLTKeychainAccessibleAfterFirstUnlock) {
        accessible = (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlock;
    }
    [query setObject:accessible forKey:(__bridge NSString *)kSecAttrAccessible];
    
    //测试 kSecReturnAttributes
    
    CFTypeRef result = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        if (error) {
            *error = [self errorWithKeychainErrorCode:status];
        }
        return nil;
    }
    
    return (__bridge_transfer NSArray *)result;
}

- (BOOL)deleted:(NSError *__autoreleasing *)error
{
    OSStatus status = HLTKeychainErrorCodeBadArguments;
    
    if (!self.service || !self.account) {
        if (error) {
            *error = [self errorWithKeychainErrorCode:status];
        }
        return NO;
    }
    
    NSMutableDictionary *query = [self query];
    status = SecItemDelete((__bridge CFDictionaryRef)query);//Mac需先查询后删除
    
    if (status != errSecSuccess && error) {
        *error =[self errorWithKeychainErrorCode:status];
    }
    
    return status == errSecSuccess;
}


#pragma mark - 属性访问

- (void)setPasswordData:(NSData *)passwordData
{
    @synchronized(self)
    {
        _passwordData = passwordData;
        _dataModified = YES;
        _password = nil;
        _passwordObject = nil;
    }
}

- (void)setPassword:(NSString *)thePassword
{
    self.passwordData = [thePassword dataUsingEncoding:NSUTF8StringEncoding];
    _password = thePassword;
}

- (void)setPasswordObject:(id<NSCoding>)thePasswordObject
{
    self.passwordData = [NSKeyedArchiver archivedDataWithRootObject:thePasswordObject];
    _passwordObject = thePasswordObject;
}

- (NSString *)password
{
    if (_password)
    {
        return _password;
    }
    
    if (!self.passwordData.length){
        return nil;
    }
    
    _password = [[NSString alloc] initWithData:self.passwordData encoding:NSUTF8StringEncoding];
    
    return _password;
}

- (id<NSCoding>)passwordObject
{
    if (_passwordObject)
    {
        return _passwordObject;
    }
    
    if (!self.passwordData){
        return nil;
    }
    
    _passwordObject = [NSKeyedUnarchiver unarchiveObjectWithData:self.passwordData];
    return _passwordObject;
}

#pragma mark -

- (NSMutableDictionary *)query
{
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:3];
    [query setObject:(__bridge NSString *)kSecClassGenericPassword forKey:(__bridge NSString *)kSecClassKey];
    
    if (self.service) {
        [query setObject:self.service forKey:(__bridge id)kSecAttrService];
    }
    
    if (self.account) {
        [query setObject:self.account forKey:(__bridge id)kSecAttrAccount];
        [query setObject:self.account forKey:(__bridge id)kSecAttrGeneric];
    }
    
    if (self.accessGroup) {
        [query setObject:self.accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
    }
    
    NSString *accessible = (__bridge NSString *)kSecAttrAccessibleWhenUnlocked;
    if (self.accessible == HLTKeychainAccessibleAfterFirstUnlock) {
        accessible = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    }
    [query setObject:accessible forKey:(__bridge id)kSecAttrAccessible];
    
    //! 同步的特性
    //! iOS7以及Mavericks增加了iCloud Keychain来提供密码，以及iCloud中一些敏感数据的同步。可以设置为YES或NO
    id synchronizable = @{@(HLTKeychainSynchronizableAny):(__bridge id)kSecAttrSynchronizableAny,
                          @(HLTKeychainSynchronizableYES):@YES,
                          @(HLTKeychainSynchronizableNO):@NO,
                          }[@(self.synchronizable)];
    if (synchronizable) {
        [query setObject:synchronizable
                  forKey:(__bridge id)(kSecAttrSynchronizable)];
    }
    
    return query;
}

- (NSError *)errorWithKeychainErrorCode:(OSStatus)code
{
    NSString *message;
    NSDictionary *userInfo = nil;
    
    switch (code) {
        case errSecSuccess:
            return nil;
        case HLTKeychainErrorCodeBadArguments:
            message = NSLocalizedStringFromTable(@"HLTKeychainErrorCodeBadArguments", @"HLTKeychain", nil);
            break;
            
        case errSecUnimplemented: {
            message = NSLocalizedStringFromTable(@"errSecUnimplemented", @"HLTKeychain", nil);
            break;
        }
        case errSecParam: {
            message = NSLocalizedStringFromTable(@"errSecParam", @"HLTKeychain", nil);
            break;
        }
        case errSecAllocate: {
            message = NSLocalizedStringFromTable(@"errSecAllocate", @"HLTKeychain", nil);
            break;
        }
        case errSecNotAvailable: {
            message = NSLocalizedStringFromTable(@"errSecNotAvailable", @"HLTKeychain", nil);
            break;
        }
        case errSecDuplicateItem: {
            message = NSLocalizedStringFromTable(@"errSecDuplicateItem", @"HLTKeychain", nil);
            break;
        }
        case errSecItemNotFound: {
            message = NSLocalizedStringFromTable(@"errSecItemNotFound", @"HLTKeychain", nil);
            break;
        }
        case errSecInteractionNotAllowed: {
            message = NSLocalizedStringFromTable(@"errSecInteractionNotAllowed", @"HLTKeychain", nil);
            break;
        }
        case errSecDecode: {
            message = NSLocalizedStringFromTable(@"errSecDecode", @"HLTKeychain", nil);
            break;
        }
        case errSecAuthFailed: {
            message = NSLocalizedStringFromTable(@"errSecAuthFailed", @"HLTKeychain", nil);
            break;
        }
        default: {
            message = NSLocalizedStringFromTable(@"errSecDefault", @"HLTKeychain", nil);
        }
    }
    
    if (message){
        userInfo = @{NSLocalizedDescriptionKey:message};
    }
    
    return [NSError errorWithDomain:HLTKeychainErrorDomain code:code userInfo:userInfo];
}

@end
