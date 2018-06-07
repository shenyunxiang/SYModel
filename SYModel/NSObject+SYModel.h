//
//  NSObject+SYModel.h
//  SYModel
//
//  Created by 沈云翔 on 2018/5/16.
//  Copyright © 2018年 syx. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface NSObject (SYModel)

/**
 将JSON转成模型属性

 @param json JSON
 @return 模型
 */
+ (nullable instancetype)sy_modelWithJSON:(id)json;

/**
 将字典的键值对转成模型属性

 @param dictionary 字典
 @return 模型
 */
+ (nullable instancetype)sy_modelWithDictionary:(NSDictionary *)dictionary;

/**
 是否成功将字典的键值对转成模型属性

 @param dic 字典
 @return YES：成功 NO：失败
 */
- (BOOL)sy_modelSetWithDictionary:(NSDictionary *)dic;

/**
 是否成功将JSON转成模型属性

 @param json JSON
 @return YES：成功 NO：失败
 */
- (BOOL)sy_modelSetWithJSON:(id)json;

/**
 转换为转换为字典或者数组

 */
- (id)sy_modelToJSONObject;

/**
 转换为JSON Data
 */
- (nullable NSData *)sy_modelToJSONData;
/**
 转换为JSON 字符串
 */
- (nullable NSString *)sy_modelToJSONString;

- (nullable id)sy_modelCopy;

- (BOOL)sy_modelIsEqual:(id)model;

- (NSString *)sy_modelDescription;

@end

#pragma mark - NSArray
@interface NSArray (SYModel)

+ (nullable NSArray *)sy_modelArrayWithClass:(Class)cls json:(id)json;

@end

#pragma mark - NSDictionary
@interface NSDictionary (SYModel)

+ (nullable NSDictionary *)sy_modelDictionaryWithClass:(Class)cls json:(id)json;

@end

#pragma mark - Delegate
@protocol SYModelDelegate <NSObject>
// 将属性名换为其他key去字典中取值 （字典中的key是属性名，value是从字典中取值用的key）
+ (nullable NSDictionary<NSString *, id> *)sy_modelCustomPropertyMapper;
//属性字段 与 类 的映射
+ (nullable NSDictionary<NSString *, id> *)sy_modelContainerPropertyGenericClass;
//黑名单 这个数组中的属性名将会被忽略：不进行字典和模型的转换
+ (nullable NSArray<NSString *> *)sy_modelPropertyBlacklist;
//白名单 只有这个数组中的属性名才允许进行字典和模型的转换
+ (nullable NSArray<NSString *> *)sy_modelPropertyWhitelist;
//
+ (nullable Class)sy_modelCustomClassForDictionary:(NSDictionary *)dictionary;
//修改 源Dic
- (NSDictionary *)sy_modelCustomWillTransformFromDictionary:(NSDictionary *)dic;

- (BOOL)sy_modelCustomTransformFromDictionary:(NSDictionary *)dic;
//判断改 Json Dic 是否合法(YES：合法，dic To Model；NO：不合法，忽略此model)
- (BOOL)sy_modelCustomTransformToDictionary:(NSMutableDictionary *)dic;

@end

NS_ASSUME_NONNULL_END
