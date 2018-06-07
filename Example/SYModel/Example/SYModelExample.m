//
//  SYModelExample.m
//  SYModel
//
//  Created by 沈云翔 on 2018/5/16.
//  Copyright © 2018年 syx. All rights reserved.
//

#import "SYModelExample.h"
#import "NSObject+SYModel.h"

#pragma mark - Model Object
@interface SYBook : NSObject

@property (nonatomic, copy) NSString *name;
//NString -> uint64_t   @"520"
@property (nonatomic, assign) uint64_t pages;
//Number -> NString     @(518)
@property(nonatomic, copy) NSString     *index;
//NString -> NSDate     @"2010-01-01"
@property (nonatomic, strong) NSDate *publishDate;
@end
@implementation SYBook
@end

@interface SYPerson:NSObject
@property(nonatomic, copy) NSString     *name;
@property(nonatomic, assign) NSUInteger    clientID;
@property(nonatomic, strong) SYBook        *book;
@property(nonatomic, strong) NSArray        *bookList;
@property(nonatomic, strong) NSDictionary   *likedBooks;

@end
@implementation SYPerson

+ (nullable NSDictionary<NSString *, id> *)sy_modelCustomPropertyMapper {
    return @{
             @"name":@[@"n",@"na",@"name"],
             @"clientID":@"id"
             };
}

+ (nullable NSDictionary<NSString *, id> *)sy_modelContainerPropertyGenericClass {
    return @{
             @"book":@"SYBook",
             @"bookList":@"SYBook",
             @"likedBooks":@"SYBook"
             };
}

@end

#pragma mark -
@implementation SYModelExample


+ (void)example_DicToModel {
    NSDictionary *dic = @{@"name":@"Tom",
                          @"pages":@"520",
                          @"index":@(518),
                          @"publishDate":@"2010-01-01"};
    
    SYBook *book = [SYBook sy_modelWithDictionary:dic];
    NSString *desc = [book sy_modelDescription];
  
    NSLog(@"%@", desc);
    
}


+ (void)example_DicToModel_PropertyMapper {
    NSDictionary *dic = @{
                          @"na":@"Tom",
                          @"id":@"520"
                          };
    
    SYPerson *person = [SYPerson sy_modelWithDictionary:dic];
    NSString *desc = [person sy_modelDescription];
    
    NSLog(@"%@ %@", desc, [person sy_modelToJSONString]);
    
}

+ (void)example_DicToModel_PropertyGenericClass {
    
    NSDictionary *bookDic = @{@"name":@"Tom",
                              @"pages":@"520",
                              @"index":@(518),
                              @"publishDate":@"2010-01-01"};
    
    NSDictionary *dic = @{
                          @"name":@"Tom",
                          @"id":@"520",
                          @"book":bookDic,
                          @"bookList":@[bookDic],
                          @"likedBooks":@{@"First":bookDic,@"Second":bookDic}
                          };
    
    
    
    SYPerson *person = [SYPerson sy_modelWithDictionary:dic];
    NSString *desc = [person sy_modelDescription];
    
    NSLog(@"%@", desc);
    
    SYPerson *p2 = [SYPerson sy_modelWithDictionary:dic];
    BOOL equal = [p2 sy_modelIsEqual:person];
    
    NSLog(@"%@", equal?@"yes":@"no");
}

@end
