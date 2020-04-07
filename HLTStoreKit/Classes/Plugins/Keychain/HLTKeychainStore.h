//
//  HLTKeychain.h
//  bite
//
//  Created by nscribble on 2018/5/22
//  keychain封装

#import <Foundation/Foundation.h>

//! 错误域
extern NSString * const HLTKeychainErrorDomain;
//! 帐号
extern NSString * const HLTKeychainAccountKey;

/**
 *  @brief 错误码
 */
typedef NS_ENUM(OSStatus, HLTKeychainErrorCode) {
    //! 参数错误
    HLTKeychainErrorCodeBadArguments = -1001,
};

#pragma mark - HLTKeychain

@interface HLTKeychainStore : NSObject

#pragma mark -

/**
 *  @brief 存储对象到keychain
 *
 *  @param object 支持序列化的对象，设置为nil则执行删除
 *  @param aKey   键
 *  @param accessGroup 访问分组，默认nil则为本应用
 *
 *  @return 操作是否成功
 */
+ (BOOL)setKeychainObject:(id<NSCoding>)object forKey:(NSString *)aKey accessGroup:(NSString *)accessGroup;

/**
 *  @brief 获取keychain对象
 *
 *  @param aKey 键
 *  @param accessGroup 访问分组，默认nil则为本应用
 *
 *  @return keychain对象
 */
+ (id<NSCoding>)keychainObjectForKey:(NSString *)aKey accessGroup:(NSString *)accessGroup;

@end
