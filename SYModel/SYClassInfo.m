//
//  SYClassInfo.m
//  SYModel
//
//  Created by 沈云翔 on 2018/5/15.
//  Copyright © 2018年 syx. All rights reserved.
//

#import "SYClassInfo.h"

SYEncodingType SYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return SYEncodingType_Unknown;
    size_t len = strlen(type);
    if (len == 0) return SYEncodingType_Unknown;
    
    SYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= SYEncodingType_Qualifier_Const;
                type++;
            } break;
            case 'n': {
                qualifier |= SYEncodingType_Qualifier_In;
                type++;
            } break;
            case 'N': {
                qualifier |= SYEncodingType_Qualifier_Inout;
                type++;
            } break;
            case 'o': {
                qualifier |= SYEncodingType_Qualifier_Out;
                type++;
            } break;
            case 'O': {
                qualifier |= SYEncodingType_Qualifier_Bycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= SYEncodingType_Qualifier_Byref;
                type++;
            } break;
            case 'V': {
                qualifier |= SYEncodingType_Qualifier_Oneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return SYEncodingType_Unknown | qualifier;
    
    switch (*type) {
        case 'v': return SYEncodingType_Void | qualifier;
        case 'B': return SYEncodingType_Bool | qualifier;
        case 'c': return SYEncodingType_Int8 | qualifier;
        case 'C': return SYEncodingType_UInt8 | qualifier;
        case 's': return SYEncodingType_Int16 | qualifier;
        case 'S': return SYEncodingType_UInt16 | qualifier;
        case 'i': return SYEncodingType_Int32 | qualifier;
        case 'I': return SYEncodingType_UInt32 | qualifier;
        case 'l': return SYEncodingType_Int32 | qualifier;
        case 'L': return SYEncodingType_UInt32 | qualifier;
        case 'q': return SYEncodingType_Int64 | qualifier;
        case 'Q': return SYEncodingType_Int64 | qualifier;
        case 'f': return SYEncodingType_Float | qualifier;
        case 'd': return SYEncodingType_Double | qualifier;
        case 'D': return SYEncodingType_LongDouble | qualifier;
        case '#': return SYEncodingType_Class | qualifier;
        case ':': return SYEncodingType_SEL | qualifier;
        case '*': return SYEncodingType_CString | qualifier;
        case '^': return SYEncodingType_Pointer | qualifier;
        case '[': return SYEncodingType_CArray | qualifier;
        case '(': return SYEncodingType_Union | qualifier;
        case '{': return SYEncodingType_Struct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return SYEncodingType_Block | qualifier;
            else
                return SYEncodingType_Object | qualifier;
        }
        default: return SYEncodingType_Unknown | qualifier;
    }
    
}

#pragma mark - SYClassMethodInfo
@implementation SYClassMethodInfo

- (instancetype)initWithMethod:(Method)method {
    if (!method) return nil;
    self = [super init];
    
    //赋值
    _method = method;
    _sel = method_getName(method);
    _imp = method_getImplementation(method);
    
    const char *name = sel_getName(_sel);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    const char *typeEncoding = method_getTypeEncoding(method);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    
    char *returnType = method_copyReturnType(method);
    if (returnType) {
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    
    unsigned int argumentCount = method_getNumberOfArguments(method);
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            NSString *type = argumentType ? [NSString stringWithUTF8String:argumentType] : nil;
            [argumentTypes addObject:type ? type : @""];
            if (argumentType) free(argumentType);
        }
        _argumentTypeEncodings = argumentTypes;
    }
    
    return self;
}

@end

#pragma mark - SYClassPropertyInfo
@implementation SYClassPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property {
    if (!property) return nil;
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    SYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = SYEncodingGetType(attrs[i].value);
                    
                    if ((type & SYEncodingType_Mask) == SYEncodingType_Object && _typeEncoding.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:_typeEncoding];
                        if (![scanner scanString:@"@\"" intoString:NULL]) continue;
                        
                        NSString *clsName = nil;
                        if ([scanner scanUpToCharactersFromSet: [NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&clsName]) {
                            if (clsName.length) _cls = objc_getClass(clsName.UTF8String);
                        }
                        
                        NSMutableArray *protocols = nil;
                        while ([scanner scanString:@"<" intoString:NULL]) {
                            NSString* protocol = nil;
                            if ([scanner scanUpToString:@">" intoString: &protocol]) {
                                if (protocol.length) {
                                    if (!protocols) protocols = [NSMutableArray new];
                                    [protocols addObject:protocol];
                                }
                            }
                            [scanner scanString:@">" intoString:NULL];
                        }
                        _protocols = protocols;
                    }
                }
            } break;
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': {
                type |= SYEncodingType_Property_Readonly;
            } break;
            case 'C': {
                type |= SYEncodingType_Property_Copy;
            } break;
            case '&': {
                type |= SYEncodingType_Property_Retain;
            } break;
            case 'N': {
                type |= SYEncodingType_Property_Nonatomic;
            } break;
            case 'D': {
                type |= SYEncodingType_Property_Dynamic;
            } break;
            case 'W': {
                type |= SYEncodingType_Property_Weak;
            } break;
            case 'G': {
                type |= SYEncodingType_Property_CustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
            case 'S': {
                type |= SYEncodingType_Property_CustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            }
            default:
                break;
        }
    }
    
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    _type = type;
    if (_name.length) {
        if (!_getter) {
            _getter = NSSelectorFromString(_name);
        }
        if (!_setter) {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    
    return self;
}

@end
#pragma mark - SYClassIvarInfo
@implementation SYClassIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar {
    if (!ivar) return nil;
    self = [super init];
    
    _ivar = ivar;
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    
    NSLog(@"\n******\n%@ %s\n******",_name,typeEncoding);
    
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        _type = SYEncodingGetType(typeEncoding);
    }
    
    return self;
}

@end

#pragma mark - SYClassInfo
@implementation SYClassInfo {
    BOOL _needUpdate;
}


+ (instancetype)classInfoWithClassName:(NSString *)className {
    Class cls = NSClassFromString(className);
    return [self classInfoWithClass:cls];
}

+ (instancetype)classInfoWithClass:(Class)cls {
    
    if (!cls) return nil;
    //类对象 缓存
    static CFMutableDictionaryRef classCache;
    //元类 缓存
    static CFMutableDictionaryRef metaCache;
    static dispatch_once_t onceToken;
    //信号量
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(),
                                               0,
                                               &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(),
                                              0,
                                              &kCFTypeDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    SYClassInfo *clsInfo = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache,
                                                (__bridge const void *)(cls));
    if (clsInfo && clsInfo -> _needUpdate) {
        [clsInfo _update];
    }
    dispatch_semaphore_signal(lock);
   
    if (!clsInfo) {
        clsInfo = [[SYClassInfo alloc] initWithClass:cls];
        if (clsInfo) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(clsInfo.isMeta ? metaCache : classCache,
                                 (__bridge const void *)(cls),
                                 (__bridge const void *)(clsInfo));
            
            dispatch_semaphore_signal(lock);
        }
    }
    
    return clsInfo;
}

- (instancetype)initWithClass:(Class)cls {
    if (!cls) return nil;
    self = [super init];
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));
    }
    _name = NSStringFromClass(cls);
    [self _update];
    //父类
    _superClassInfo = [self.class classInfoWithClass:_superCls];
    return self;
}

- (void)_update {
    //清空数据
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = self.cls;
    
    //Method
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            SYClassMethodInfo *info = [[SYClassMethodInfo alloc] initWithMethod:methods[i]];
            if (info.name) methodInfos[info.name] = info;
        }
        //释放
        free(methods);
    }
    //Property
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            SYClassPropertyInfo *info = [[SYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    //Ivar
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            SYClassIvarInfo *info = [[SYClassIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    if (!_ivarInfos) _ivarInfos = @{};
    if (!_methodInfos) _methodInfos = @{};
    if (!_propertyInfos) _propertyInfos = @{};
    
    _needUpdate = NO;
}

- (BOOL)needUpdate {
    return _needUpdate;
}

@end
