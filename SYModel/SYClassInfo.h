//
//  SYClassInfo.h
//  SYModel
//
//  Created by 沈云翔 on 2018/5/15.
//  Copyright © 2018年 syx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN
//https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
typedef NS_OPTIONS(NSUInteger, SYEncodingType) {
    SYEncodingType_Mask       = 0xFF, ///< mask of type value
    SYEncodingType_Unknown    = 0,
    SYEncodingType_Void       = 1,
    SYEncodingType_Bool       = 2,
    SYEncodingType_Int8       = 3,
    SYEncodingType_UInt8      = 4,
    SYEncodingType_Int16      = 5,
    SYEncodingType_UInt16     = 6,
    SYEncodingType_Int32      = 7,
    SYEncodingType_UInt32     = 8,
    SYEncodingType_Int64      = 9,
    SYEncodingType_UInt64     = 10,
    SYEncodingType_Float      = 11,
    SYEncodingType_Double     = 12,
    SYEncodingType_LongDouble = 13,
    SYEncodingType_Object     = 14,
    SYEncodingType_Class      = 15,
    SYEncodingType_SEL        = 16,
    SYEncodingType_Block      = 17,
    SYEncodingType_Pointer    = 18,//void*
    SYEncodingType_Struct     = 19,
    SYEncodingType_Union      = 20,
    SYEncodingType_CString    = 21,//char*
    SYEncodingType_CArray     = 22,//char[10]
    
    SYEncodingType_Qualifier_Mask   = 0xFF00,   ///< mask of qualifier
    SYEncodingType_Qualifier_Const  = 1 << 8,  ///< const
    SYEncodingType_Qualifier_In     = 1 << 9,  ///< in
    SYEncodingType_Qualifier_Inout  = 1 << 10, ///< inout
    SYEncodingType_Qualifier_Out    = 1 << 11, ///< out
    SYEncodingType_Qualifier_Bycopy = 1 << 12, ///< bycopy
    SYEncodingType_Qualifier_Byref  = 1 << 13, ///< byref
    SYEncodingType_Qualifier_Oneway = 1 << 14, ///< oneway
    
    SYEncodingType_Property_Mask         = 0xFF0000, ///< mask of property
    SYEncodingType_Property_Readonly     = 1 << 16, ///< readonly
    SYEncodingType_Property_Copy         = 1 << 17, ///< copy
    SYEncodingType_Property_Retain       = 1 << 18, ///< retain
    SYEncodingType_Property_Nonatomic    = 1 << 19, ///< nonatomic
    SYEncodingType_Property_Weak         = 1 << 20, ///< weak
    SYEncodingType_Property_CustomGetter = 1 << 21, ///< getter=
    SYEncodingType_Property_CustomSetter = 1 << 22, ///< setter=
    SYEncodingType_Property_Dynamic      = 1 << 23, ///< @dynamic
};

SYEncodingType SYEncodingGetType(const char *typeEncoding);

#pragma mark - SYClassIvarInfo
@interface SYClassIvarInfo : NSObject

@property (nonatomic, assign, readonly) Ivar ivar;              
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) ptrdiff_t offset;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, assign, readonly) SYEncodingType type;


- (instancetype)initWithIvar:(Ivar)ivar;

@end
#pragma mark - SYClassMethodInfo
@interface SYClassMethodInfo : NSObject

@property (nonatomic, assign, readonly) Method method;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) SEL sel;
@property (nonatomic, assign, readonly) IMP imp;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, strong, readonly) NSString *returnTypeEncoding;
@property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *argumentTypeEncodings;

- (instancetype)initWithMethod:(Method)method;

@end
#pragma mark - SYClassPropertyInfo
@interface SYClassPropertyInfo : NSObject

@property (nonatomic, assign, readonly) objc_property_t property;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) SYEncodingType type;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, strong, readonly) NSString *ivarName;
@property (nullable, nonatomic, assign, readonly) Class cls;
@property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *protocols;
@property (nonatomic, assign, readonly) SEL getter;
@property (nonatomic, assign, readonly) SEL setter;

- (instancetype)initWithProperty:(objc_property_t)property;

@end

#pragma mark - SYClassInfo
/**
 类对象的信息
 */
@interface SYClassInfo : NSObject

/**
 类对象
 */
@property(nonatomic, assign, readonly) Class    cls;

/**
 该类对象的父类
 */
@property(nonatomic, assign, readonly) Class    superCls;

/**
 该类对象的 元类
 */
@property(nonatomic, assign, readonly) Class    metaCls;

/**
 是否为 元类
 */
@property (nonatomic, readonly) BOOL isMeta;

@property (nullable, nonatomic, strong, readonly) SYClassInfo *superClassInfo;

@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SYClassIvarInfo *> *ivarInfos;

@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SYClassMethodInfo *> *methodInfos;

@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SYClassPropertyInfo *> *propertyInfos;
/**
 该类对象的名字
 */
@property (nonatomic, strong, readonly) NSString *name;

+ (nullable instancetype)classInfoWithClass:(Class)cls;

+ (nullable instancetype)classInfoWithClassName:(NSString *)className;

- (BOOL)needUpdate;

@end

NS_ASSUME_NONNULL_END
