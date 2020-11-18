//
//  HLTKeychainQuery.h
//  bite
//
//  Created by nscribble on 2018/5/22
//  keychain的操作(查询、存储、删除)封装

#import <Foundation/Foundation.h>

//! iCloud同步配置
typedef NS_ENUM(NSInteger, HLTKeychainSynchronizable)
{
    HLTKeychainSynchronizableAny,
    HLTKeychainSynchronizableYES,
    HLTKeychainSynchronizableNO,
};

//! keychain访问权限设置(暂仅支持这两个)
typedef NS_ENUM(NSInteger, HLTKeychainAccessible)
{
    HLTKeychainAccessibleWhenUnlocked,
    HLTKeychainAccessibleAfterFirstUnlock,
};

//! keychain的操作(查询、存储、删除)封装
@interface HLTKeychainQuery : NSObject

//! 账户
@property (nonatomic,copy) NSString *account;
//! 服务
@property (nonatomic,copy) NSString *service;
//! 访问分组
@property (nonatomic,copy) NSString *accessGroup;

//! 密码数据(以下最终转为passwordData存储)
@property (nonatomic,copy) NSData *passwordData;
//! 密码
@property (nonatomic,copy) NSString *password;
//! 密码对象
@property (nonatomic,copy) id<NSCoding> passwordObject;

//! 同步性
@property (nonatomic,assign) HLTKeychainSynchronizable synchronizable;
//! 访问权限
@property (nonatomic,assign) HLTKeychainAccessible accessible;

/**
 *  @brief 保存|更新
 *
 *  @param error 错误信息(若有)
 *
 *  @return 是否成功
 */
- (BOOL)saved:(NSError **)error;

/**
 *  @brief 查询(限定单个)
 *  @note  返回结果写到passwordData中，可通过password或passwordObject获取
 *  @param error 错误信息(若有)
 *
 *  @return 是否成功
 */
- (BOOL)fetched:(NSError **)error;

/**
 *  @brief 查询所有匹配的结果
 *
 *  @param error 错误信息(若有)
 *
 *  @return 结果数组<字典>
 */
- (NSArray *)fetchedAll:(NSError **)error;

/**
 *  @brief 删除匹配的items
 *
 *  @param error 错误信息(若存在)
 *
 *  @return 是否成功
 */
- (BOOL)deleted:(NSError **)error;



@end
