//
//  NSObject+SYModel.m
//  SYModel
//
//  Created by 沈云翔 on 2018/5/16.
//  Copyright © 2018年 syx. All rights reserved.
//

#import "NSObject+SYModel.h"
#import <objc/message.h>
#import "SYClassInfo.h"

#define force_inline __inline__ __attribute__((always_inline))

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, SYEncodingNSType) {
    SYEncodingType_NSUnknown = 0,
    SYEncodingType_NSString,
    SYEncodingType_NSMutableString,
    SYEncodingType_NSValue,
    SYEncodingType_NSNumber,
    SYEncodingType_NSDecimalNumber,
    SYEncodingType_NSData,
    SYEncodingType_NSMutableData,
    SYEncodingType_NSDate,
    SYEncodingType_NSURL,
    SYEncodingType_NSArray,
    SYEncodingType_NSMutableArray,
    SYEncodingType_NSDictionary,
    SYEncodingType_NSMutableDictionary,
    SYEncodingType_NSSet,
    SYEncodingType_NSMutableSet,
};

typedef struct {
    void *modelMeta;  ///< _YYModelMeta
    void *model;      ///< id (self)
    void *dictionary; ///< NSDictionary (json)
} SY_ModelSetContext;

static force_inline SYEncodingNSType SYClassGet_NSType(Class cls) {
    if (!cls) return SYEncodingType_NSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return SYEncodingType_NSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return SYEncodingType_NSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return SYEncodingType_NSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return SYEncodingType_NSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return SYEncodingType_NSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return SYEncodingType_NSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return SYEncodingType_NSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return SYEncodingType_NSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return SYEncodingType_NSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return SYEncodingType_NSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return SYEncodingType_NSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return SYEncodingType_NSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return SYEncodingType_NSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return SYEncodingType_NSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return SYEncodingType_NSSet;
    return SYEncodingType_NSUnknown;
}

static force_inline BOOL SYEncodingTypeIsCNumber(SYEncodingType type) {
    switch (type & SYEncodingType_Mask) {
        case SYEncodingType_Bool:
        case SYEncodingType_Int8:
        case SYEncodingType_UInt8:
        case SYEncodingType_Int16:
        case SYEncodingType_UInt16:
        case SYEncodingType_Int32:
        case SYEncodingType_UInt32:
        case SYEncodingType_Int64:
        case SYEncodingType_UInt64:
        case SYEncodingType_Float:
        case SYEncodingType_Double:
        case SYEncodingType_LongDouble: return YES;
        default: return NO;
    }
}

static force_inline NSNumber *SYNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));
        }
    }
    return nil;
}

static force_inline NSDate *SYNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^SYNSDateParseBlock)(NSString *string);
#define kParserNum 34
    static SYNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             2014-01-20 12:24:48.000
             2014-01-20T12:24:48.000
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            NSDateFormatter *formatter3 = [[NSDateFormatter alloc] init];
            formatter3.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter3.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter3.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
            
            NSDateFormatter *formatter4 = [[NSDateFormatter alloc] init];
            formatter4.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter4.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter4.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                } else {
                    return [formatter2 dateFromString:string];
                }
            };
            
            blocks[23] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter3 dateFromString:string];
                } else {
                    return [formatter4 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             2014-01-20T12:24:48.000Z
             2014-01-20T12:24:48.000+0800
             2014-01-20T12:24:48.000+12:00
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
            
            blocks[20] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]?: [formatter2 dateFromString:string]; };
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[28] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
            blocks[29] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             Fri Sep 04 00:12:21.000 +0800 2015
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"EEE MMM dd HH:mm:ss.SSS Z yyyy";
            
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[34] = ^(NSString *string) { return [formatter2 dateFromString:string]; };
        }
        
    });
    
    if (!string) return nil;
    if (string.length > kParserNum) return nil;
    SYNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
#undef kParserNum
    
}

static force_inline Class SYNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}

static force_inline id SYValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    return value;
}

static force_inline id SYValueForMultiKeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        } else {
            value = SYValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}

static NSMutableString *SY_ModelDescriptionAddIndent(NSMutableString *desc, NSUInteger indent) {
    for (NSUInteger i = 0, max = desc.length; i < max; i++) {
        unichar c = [desc characterAtIndex:i];
        if (c == '\n') {
            for (NSUInteger j = 0; j < indent; j++) {
                [desc insertString:@"    " atIndex:i + 1];
            }
            i += indent * 4;
            max += indent * 4;
        }
    }
    return desc;
}

static force_inline NSDateFormatter *SY_ISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

#pragma mark - _SYModelPropertyMeta
@interface _SYModelPropertyMeta : NSObject {
    @package
    NSString *_name;
    SYEncodingType _type;
    SYEncodingNSType _nsType;
    BOOL _isCNumber;
    Class _cls;
    Class _genericCls;
    SEL _getter;
    SEL _setter;
    BOOL _isKVCCompatible;
    BOOL _isStructAvailableForKeyedArchiver;
    BOOL _hasCustomClassFromDictionary;
    
    NSString *_mappedToKey;
    NSArray *_mappedToKeyPath;
    NSArray *_mappedToKeyArray;
    
    SYClassPropertyInfo *_info;
    _SYModelPropertyMeta *_next;
}
@end
@implementation _SYModelPropertyMeta

+ (instancetype)metaWithClassInfo:(SYClassInfo *)classInfo
                     propertyInfo:(SYClassPropertyInfo *)propertyInfo
                          generic:(Class)generic {
    //
    if (!generic && propertyInfo.protocols) {
        for (NSString *protocol in propertyInfo.protocols) {
            Class cls = objc_getClass(protocol.UTF8String);
            if (cls) {
                generic = cls;
                break;
            }
        }
    }
    
    //
    _SYModelPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    meta->_genericCls = generic;
    
    if ((meta->_type & SYEncodingType_Mask) == SYEncodingType_Object) { //OC 对象
        meta->_nsType = SYClassGet_NSType(propertyInfo.cls);
    } else { // C 的基本数据类型 int ...
        meta->_isCNumber = SYEncodingTypeIsCNumber(meta->_type);
    }
    //结构体
    if ((meta->_type & SYEncodingType_Mask) == SYEncodingType_Struct) {
        
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
        
    }
    meta->_cls = propertyInfo.cls;
    
    if (generic) {
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(sy_modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == SYEncodingType_NSUnknown) {
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(sy_modelCustomClassForDictionary:)];
    }
    
    if (propertyInfo.getter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
            meta->_getter = propertyInfo.getter;
        }
    }
    if (propertyInfo.setter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
            meta->_setter = propertyInfo.setter;
        }
    }
    
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        switch (meta->_type & SYEncodingType_Mask) {
            case SYEncodingType_Bool:
            case SYEncodingType_Int8:
            case SYEncodingType_UInt8:
            case SYEncodingType_Int16:
            case SYEncodingType_UInt16:
            case SYEncodingType_Int32:
            case SYEncodingType_UInt32:
            case SYEncodingType_Int64:
            case SYEncodingType_UInt64:
            case SYEncodingType_Float:
            case SYEncodingType_Double:
            case SYEncodingType_Object:
            case SYEncodingType_Class:
            case SYEncodingType_Block:
            case SYEncodingType_Struct:
            case SYEncodingType_Union: {
                meta->_isKVCCompatible = YES;
            } break;
            default: break;
        }
    }
    
    return meta;
}

@end
#pragma mark - _SYModelMeta
@interface _SYModelMeta : NSObject {
    @package
    SYClassInfo *_classInfo;
    /// Key:mapped key and key path, Value:_SYModelPropertyMeta.
    NSDictionary *_mapper;
    /// Array<_SYModelPropertyMeta>, all property meta of this model.
    NSArray *_allPropertyMetas;
    /// Array<_SYModelPropertyMeta>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// Array<_SYModelPropertyMeta>, property meta which is mapped to multi keys.
    NSArray *_multiKeysPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    SYEncodingNSType _nsType;
    
    BOOL _hasCustomWillTransformFromDictionary;
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end

@implementation _SYModelMeta

+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    _SYModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    dispatch_semaphore_signal(lock);
    if (!meta || meta->_classInfo.needUpdate) {
        meta = [[_SYModelMeta alloc] initWithClass:cls];
        if (meta) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            dispatch_semaphore_signal(lock);
        }
    }
    return meta;
}

- (instancetype)initWithClass:(Class)cls {
    SYClassInfo *classInfo = [SYClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list
    NSSet *blacklist = nil;
    if ([cls respondsToSelector:@selector(sy_modelPropertyBlacklist)]) {
        NSArray *properties = [(id<SYModelDelegate>)cls sy_modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(sy_modelPropertyWhitelist)]) {
        NSArray *properties = [(id<SYModelDelegate>)cls sy_modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    //JSON字段的值映射的类
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(sy_modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<SYModelDelegate>)cls sy_modelContainerPropertyGenericClass];
        if (genericMapper) {
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                if (!meta) return;
                if (class_isMetaClass(meta)) {
                    tmp[key] = obj;
                } else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) {
                        tmp[key] = cls;
                    }
                }
            }];
            genericMapper = tmp;
        }
    }
    //
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    SYClassInfo *curClassInfo = classInfo;
    //获取该类的所有属性(包含父类)
    while (curClassInfo && curClassInfo.superCls != nil) {
        for (SYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            
            if (!propertyInfo.name) continue ;
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && ![whitelist containsObject:propertyInfo.name]) continue;
            
            _SYModelPropertyMeta *meta = [_SYModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                        generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    //keyPath
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    //multiKeys
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    if ([cls respondsToSelector:@selector(sy_modelCustomPropertyMapper)]) {
        
        NSDictionary *customapper = [(id<SYModelDelegate>)cls sy_modelCustomPropertyMapper];
        [customapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
            
            _SYModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (!propertyMeta) return;
            //移除
            [allPropertyMetas removeObjectForKey:propertyName];
            
            if ([mappedToKey isKindOfClass:[NSString class]]) {
                if (mappedToKey.length == 0) return;
                
                propertyMeta->_mappedToKey = mappedToKey;
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
                for (NSString *onePath in keyPath) {
                    if (onePath.length == 0) {
                        NSMutableArray *tmp = keyPath.mutableCopy;
                        [tmp removeObject:@""];
                        keyPath = tmp;
                        break;
                    }
                }
                if (keyPath.count > 1) {
                    propertyMeta->_mappedToKeyPath = keyPath;
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
                
            } else if ([mappedToKey isKindOfClass:[NSArray class]]) { //multiKeys
                NSMutableArray *mappedToKeyArray = [NSMutableArray new];
                for (NSString *oneKey in (NSArray *)mappedToKey) {
                    if (![oneKey isKindOfClass:[NSString class]]) continue;
                    if (oneKey.length == 0) continue;
                    
                    NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                    if (keyPath.count > 1) {
                        [mappedToKeyArray addObject:keyPath];
                    } else {
                        [mappedToKeyArray addObject:oneKey];
                    }
                    
                    if (!propertyMeta->_mappedToKey) {
                        propertyMeta->_mappedToKey = oneKey;
                        propertyMeta->_mappedToKeyPath = keyPath.count > 1 ? keyPath : nil;
                    }
                }
                if (!propertyMeta->_mappedToKey) return;
                
                propertyMeta->_mappedToKeyArray = mappedToKeyArray;
                [multiKeysPropertyMetas addObject:propertyMeta];
                
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
                
            }
        }];
        
    }
    
    //将字典的Key 与 _SYModelPropertyMeta 映射起来
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString*  name, _SYModelPropertyMeta *propertyMeta, BOOL *  stop) {
        propertyMeta->_mappedToKey = name;
        propertyMeta->_next = mapper[name] ?: nil;
        mapper[name] = propertyMeta;
    }];
    
    if (mapper.count) _mapper = mapper;
    if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _classInfo = classInfo;
    _keyMappedCount = _allPropertyMetas.count;
    _nsType  = SYClassGet_NSType(cls);
    
    _hasCustomWillTransformFromDictionary = ([cls instancesRespondToSelector:@selector(sy_modelCustomWillTransformFromDictionary:)]);
    _hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(sy_modelCustomTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(sy_modelCustomTransformToDictionary:)]);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(sy_modelCustomClassForDictionary:)]);
    
    return self;
}
@end

#pragma mark -
static force_inline void SY_ModelSetNumberToProperty(__unsafe_unretained id model,
                                                     __unsafe_unretained NSNumber *num,
                                                     __unsafe_unretained _SYModelPropertyMeta *meta) {
    
    switch (meta->_type & SYEncodingType_Mask) {
        case SYEncodingType_Bool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case SYEncodingType_Int8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case SYEncodingType_UInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case SYEncodingType_Int16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case SYEncodingType_UInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case SYEncodingType_Int32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case SYEncodingType_UInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case SYEncodingType_Int64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case SYEncodingType_UInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case SYEncodingType_Float: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case SYEncodingType_Double: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case SYEncodingType_LongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } // break; commented for code coverage in next line
        default: break;
    }
    
}

static void SY_ModelSetValueForProperty(__unsafe_unretained id model,
                                        __unsafe_unretained id value,
                                        __unsafe_unretained _SYModelPropertyMeta *meta) {
    
    if (meta -> _isCNumber) {
        NSNumber *num = SYNSNumberCreateFromID(value);
        SY_ModelSetNumberToProperty(model, num, meta);
        if (num) [num class];
    } else if (meta -> _nsType) { //OC对象
        
        if (value == (id)kCFNull) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
        } else {
            switch (meta -> _nsType) {
                case SYEncodingType_NSString:
                case SYEncodingType_NSMutableString:{
                    if ([value isKindOfClass:[NSString class]]) {
                        if (meta->_nsType == SYEncodingType_NSString) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSString *)value).mutableCopy);
                        }
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == SYEncodingType_NSString) ?
                                                                       ((NSNumber *)value).stringValue :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                    } else if ([value isKindOfClass:[NSData class]]) {
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, string);
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == SYEncodingType_NSString) ?
                                                                       ((NSURL *)value).absoluteString :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                    } else if ([value isKindOfClass:[NSAttributedString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == SYEncodingType_NSString) ?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                }
                    break;
                case SYEncodingType_NSValue:
                case SYEncodingType_NSNumber:
                case SYEncodingType_NSDecimalNumber: {
                    if (meta -> _nsType == SYEncodingType_NSNumber) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, SYNSNumberCreateFromID(value));
                    } else if (meta -> _nsType == SYEncodingType_NSDecimalNumber) {
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            if (dec._length == 0 && dec._isNegative) {
                                decNum = nil; // NaN
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        }
                    } else {
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }
                    }
                }
                    break;
                case SYEncodingType_NSData:
                case SYEncodingType_NSMutableData:{
                    if ([value isKindOfClass:[NSData class]]) {
                        if (meta->_nsType == SYEncodingType_NSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            NSMutableData *data = ((NSData *)value).mutableCopy;
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                        }
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (meta->_nsType == SYEncodingType_NSMutableData) {
                            data = ((NSData *)data).mutableCopy;
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                    }
                }
                    break;
                case SYEncodingType_NSDate:{
                    if ([value isKindOfClass:[NSDate class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, SYNSDateFromString(value));
                    }
                }
                    break;
                case SYEncodingType_NSURL:{
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }
                }break;
                case SYEncodingType_NSDictionary:
                case SYEncodingType_NSMutableDictionary:{
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (meta->_genericCls) {
                            NSMutableDictionary *dic = [NSMutableDictionary new];
                            [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls sy_modelCustomClassForDictionary:oneValue];
                                        if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne sy_modelSetWithDictionary:(id)oneValue];
                                    if (newOne) dic[oneKey] = newOne;
                                }
                            }];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                        } else {
                            if (meta->_nsType == SYEncodingType_NSDictionary) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSDictionary *)value).mutableCopy);
                            }
                        }
                    }
                }break;
                    
                case SYEncodingType_NSMutableArray:
                case SYEncodingType_NSArray:{
                    if (meta->_genericCls) {
                        NSArray *valueArr = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
                        if (valueArr) {
                            NSMutableArray *objectArr = [NSMutableArray new];
                            for (id one in valueArr) {
                                if ([one isKindOfClass:meta->_genericCls]) {
                                    [objectArr addObject:one];
                                } else if ([one isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls sy_modelCustomClassForDictionary:one];
                                        if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne sy_modelSetWithDictionary:one];
                                    if (newOne) [objectArr addObject:newOne];
                                }
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                        }
                    } else {
                        if ([value isKindOfClass:[NSArray class]]) {
                            if (meta->_nsType == SYEncodingType_NSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSArray *)value).mutableCopy);
                            }
                        } else if ([value isKindOfClass:[NSSet class]]) {
                            if (meta->_nsType == SYEncodingType_NSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSSet *)value).allObjects);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               ((NSSet *)value).allObjects.mutableCopy);
                            }
                        }
                    }
                }break;
                    
                case SYEncodingType_NSSet:
                case SYEncodingType_NSMutableSet:{
                    NSSet *valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                    
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for (id one in valueSet) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls sy_modelCustomClassForDictionary:one];
                                    if (!cls) cls = meta->_genericCls; // for xcode code coverage
                                }
                                NSObject *newOne = [cls new];
                                [newOne sy_modelSetWithDictionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                    } else {
                        if (meta->_nsType == SYEncodingType_NSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           ((NSSet *)valueSet).mutableCopy);
                        }
                    }
                }break;
                default:
                    break;
            }
        }
        
    } else { // 非OC基本对象类型
        
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & SYEncodingType_Mask) {
            case SYEncodingType_Object:{
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                } else if ([value isKindOfClass:meta->_cls] || !meta->_cls) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one sy_modelSetWithDictionary:value];
                    } else {
                        Class cls = meta->_cls;
                        if (meta->_hasCustomClassFromDictionary) {
                            cls = [cls sy_modelCustomClassForDictionary:value];
                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                        }
                        one = [cls new];
                        [one sy_modelSetWithDictionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            }break;
                
            case SYEncodingType_Class:{
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                } else {
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                        }
                    } else {
                        cls = object_getClass(value);
                        if (cls) {
                            if (class_isMetaClass(cls)) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                            }
                        }
                    }
                }
            }break;
                
            case SYEncodingType_SEL:{
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                }
            }break;
                
            case SYEncodingType_Block:{
                if (isNull) {
                    ((void (*)(id, SEL, void (^)(void)))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)(void))NULL);
                } else if ([value isKindOfClass:SYNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)(void)))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)(void))value);
                }
            }break;
                
            case SYEncodingType_Struct:
            case SYEncodingType_Union:
            case SYEncodingType_CArray:{
                if ([value isKindOfClass:[NSValue class]]) {
                    const char *valueType = ((NSValue *)value).objCType;
                    const char *metaType = meta->_info.typeEncoding.UTF8String;
                    if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                        [model setValue:value forKey:meta->_name];
                    }
                }
            }break;
                
            case SYEncodingType_Pointer:
            case SYEncodingType_CString:{
                if (isNull) {
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsValue = value;
                    if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                    }
                }
            }break;
            default:
                break;
        }
        
    }
    
}


static void SY_ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    SY_ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _SYModelPropertyMeta *propertyMeta = (__bridge _SYModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    
    if (propertyMeta->_mappedToKeyArray) {
        value = SYValueForMultiKeys(dictionary, propertyMeta->_mappedToKeyArray);
    } else if (propertyMeta->_mappedToKeyPath) {
        value = SYValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    } else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        SY_ModelSetValueForProperty(model, value, propertyMeta);
    }
}

static void SY_ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    
    SY_ModelSetContext *context = _context;
    __unsafe_unretained _SYModelMeta *meta = (__bridge _SYModelMeta *)(context->modelMeta);
    __unsafe_unretained _SYModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {//如果限定词为 readonly 不会赋值
            SY_ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

#pragma mark -
static force_inline NSNumber *SY_ModelCreateNumberFromProperty(__unsafe_unretained id model,
                                                               __unsafe_unretained _SYModelPropertyMeta *meta) {
    switch (meta->_type & SYEncodingType_Mask) {
        case SYEncodingType_Bool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_Int8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_UInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_Int16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_UInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_Int32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_UInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_Int64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_UInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        }
        case SYEncodingType_Float: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case SYEncodingType_Double: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case SYEncodingType_LongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default: return nil;
    }
}

static NSString *SY_ModelDescription(NSObject *model) {
    static const int kDescMaxLength = 100;
    if (!model) return @"<nil>";
    if (model == (id)kCFNull) return @"<null>";
    if (![model isKindOfClass:[NSObject class]]) return [NSString stringWithFormat:@"%@",model];
    
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:model.class];
    switch (modelMeta -> _nsType) {
        case SYEncodingType_NSString:
        case SYEncodingType_NSMutableString: {
            return [NSString stringWithFormat:@"\"%@\"",model];
        }
            
        case SYEncodingType_NSValue:
        case SYEncodingType_NSData:
        case SYEncodingType_NSMutableData: {
            NSString *tmp = model.description;
            if (tmp.length > kDescMaxLength) {
                tmp = [tmp substringToIndex:kDescMaxLength];
                tmp = [tmp stringByAppendingString:@"..."];
            }
            return tmp;
        }
            
        case SYEncodingType_NSNumber:
        case SYEncodingType_NSDecimalNumber:
        case SYEncodingType_NSDate:
        case SYEncodingType_NSURL: {
            return [NSString stringWithFormat:@"%@",model];
        }
            
        case SYEncodingType_NSSet: case SYEncodingType_NSMutableSet: {
            model = ((NSSet *)model).allObjects;
        } // no break
            
        case SYEncodingType_NSArray:
        case SYEncodingType_NSMutableArray: {
            NSArray *array = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (array.count == 0) {
                return [desc stringByAppendingString:@"[]"];
            } else {
                [desc appendFormat:@"[\n"];
                for (NSUInteger i = 0, max = array.count; i < max; i++) {
                    NSObject *obj = array[i];
                    [desc appendString:@"    "];
                    [desc appendString:SY_ModelDescriptionAddIndent(SY_ModelDescription(obj).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"]"];
                return desc;
            }
        }
        case SYEncodingType_NSDictionary:
        case SYEncodingType_NSMutableDictionary: {
            NSDictionary *dic = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (dic.count == 0) {
                return [desc stringByAppendingString:@"{}"];
            } else {
                NSArray *keys = dic.allKeys;
                
                [desc appendFormat:@"{\n"];
                for (NSUInteger i = 0, max = keys.count; i < max; i++) {
                    NSString *key = keys[i];
                    NSObject *value = dic[key];
                    [desc appendString:@"    "];
                    [desc appendFormat:@"%@ = %@",key, SY_ModelDescriptionAddIndent(SY_ModelDescription(value).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendString:@"}"];
            }
            return desc;
        }
            
        default: {
            NSMutableString *desc = [NSMutableString new];
            [desc appendFormat:@"<%@: %p>", model.class, model];
            if (modelMeta->_allPropertyMetas.count == 0) return desc;
            
            // sort property names
            NSArray *properties = [modelMeta->_allPropertyMetas
                                   sortedArrayUsingComparator:^NSComparisonResult(_SYModelPropertyMeta *p1, _SYModelPropertyMeta *p2) {
                                       return [p1->_name compare:p2->_name];
                                   }];
            
            [desc appendFormat:@" {\n"];
            for (NSUInteger i = 0, max = properties.count; i < max; i++) {
                _SYModelPropertyMeta *property = properties[i];
                NSString *propertyDesc;
                if (property->_isCNumber) {
                    NSNumber *num = SY_ModelCreateNumberFromProperty(model, property);
                    propertyDesc = num.stringValue;
                } else {
                    switch (property->_type & SYEncodingType_Mask) {
                        case SYEncodingType_Object: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = SY_ModelDescription(v);
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case SYEncodingType_Class: {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ((NSObject *)v).description;
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        } break;
                        case SYEncodingType_SEL: {
                            SEL sel = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            if (sel) propertyDesc = NSStringFromSelector(sel);
                            else propertyDesc = @"<NULL>";
                        } break;
                        case SYEncodingType_Block: {
                            id block = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = block ? ((NSObject *)block).description : @"<nil>";
                        } break;
                        case SYEncodingType_CArray: case SYEncodingType_CString: case SYEncodingType_Pointer: {
                            void *pointer = ((void* (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = [NSString stringWithFormat:@"%p",pointer];
                        } break;
                        case SYEncodingType_Struct: case SYEncodingType_Union: {
                            NSValue *value = [model valueForKey:property->_name];
                            propertyDesc = value ? value.description : @"{unknown}";
                        } break;
                        default: propertyDesc = @"<unknown>";
                    }
                }
                
                propertyDesc = SY_ModelDescriptionAddIndent(propertyDesc.mutableCopy, 1);
                [desc appendFormat:@"    %@ = %@",property->_name, propertyDesc];
                [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
            }
            [desc appendFormat:@"}"];
            return desc;
        }
    }
}

static id SY_ModelToJSONObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = SY_ModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = SY_ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = SY_ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [SY_ISODateFormatter() stringFromDate:(id)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _SYModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = SY_ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = SY_ModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & SYEncodingType_Mask) {
                case SYEncodingType_Object: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = SY_ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case SYEncodingType_Class: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case SYEncodingType_SEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) { // end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        subDic = subDic.mutableCopy;
                        superDic[key] = subDic;
                    } else {
                        break;
                    }
                } else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    if (modelMeta->_hasCustomTransformToDictionary) {
        BOOL suc = [((id<SYModelDelegate>)model) sy_modelCustomTransformToDictionary:dic];
        if (!suc) return nil;
    }
    return result;
}

#pragma mark - SYModel
@implementation NSObject (SYModel)

+ (instancetype)sy_modelWithJSON:(id)json {
    NSDictionary *dic = [self sy_dictionaryWithJson:json];
    return [self sy_modelWithDictionary:dic];
}

+ (instancetype)sy_modelWithDictionary:(NSDictionary *)dictionary {
    
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:cls];
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls sy_modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one sy_modelSetWithDictionary:dictionary]) return one;
    return nil;
    
}

- (BOOL)sy_modelSetWithJSON:(id)json {
    NSDictionary  *dic = [NSObject sy_dictionaryWithJson:json];
    return [self sy_modelSetWithDictionary:dic];
}

- (BOOL)sy_modelSetWithDictionary:(NSDictionary *)dic  {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    
    if (modelMeta->_hasCustomWillTransformFromDictionary) {
        dic = [((id<SYModelDelegate>)self) sy_modelCustomWillTransformFromDictionary:dic];
        if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    }
    
    SY_ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        //1.
        CFDictionaryApplyFunction((CFDictionaryRef)dic, SY_ModelSetWithDictionaryFunction, &context);
        //2. keyPath
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 SY_ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        //2. multiKeys
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 SY_ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             SY_ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    if (modelMeta->_hasCustomTransformFromDictionary) {
        return [((id<SYModelDelegate>)self) sy_modelCustomTransformFromDictionary:dic];
    }
    
    return YES;
}

- (NSString *)sy_modelDescription {
    return SY_ModelDescription(self);
}

+ (NSDictionary *)sy_dictionaryWithJson:(id)json {
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

- (id)sy_modelToJSONObject {
    id jsonObject = SY_ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}

- (NSData *)sy_modelToJSONData {
    id jsonObject = [self sy_modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}

- (NSString *)sy_modelToJSONString {
    NSData *jsonData = [self sy_modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)sy_modelCopy {
    if (self == (id)kCFNull) return self;
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_SYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & SYEncodingType_Mask) {
                case SYEncodingType_Bool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Int8:
                case SYEncodingType_UInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Int16:
                case SYEncodingType_UInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Int32:
                case SYEncodingType_UInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Int64:
                case SYEncodingType_UInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Float: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_Double: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case SYEncodingType_LongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } // break; commented for code coverage in next line
                default: break;
            }
        } else {
            switch (propertyMeta->_type & SYEncodingType_Mask) {
                case SYEncodingType_Object:
                case SYEncodingType_Class:
                case SYEncodingType_Block: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case SYEncodingType_SEL:
                case SYEncodingType_Pointer:
                case SYEncodingType_CString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case SYEncodingType_Struct:
                case SYEncodingType_Union: {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }
                    } @catch (NSException *exception) {}
                } // break; commented for code coverage in next line
                default: break;
            }
        }
    }
    return one;
}

- (BOOL)sy_modelIsEqual:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _SYModelMeta *modelMeta = [_SYModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_SYModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if (![this isEqual:that]) return NO;
    }
    return YES;
}

@end
#pragma mark - NSArray
@implementation NSArray (SYModel)

+ (NSArray *)sy_modelArrayWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return [self sy_modelArrayWithClass:cls array:arr];
}

+ (NSArray *)sy_modelArrayWithClass:(Class)cls array:(NSArray *)arr {
    if (!cls || !arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [cls sy_modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

@end
#pragma mark - NSDictionary
@implementation NSDictionary (SYModel)

+ (NSDictionary *)sy_modelDictionaryWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self sy_modelDictionaryWithClass:cls dictionary:dic];
}

+ (NSDictionary *)sy_modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic {
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject *obj = [cls sy_modelWithDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}

@end
