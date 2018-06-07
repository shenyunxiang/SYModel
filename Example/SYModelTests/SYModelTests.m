//
//  SYModelTests.m
//  SYModelTests
//
//  Created by 沈云翔 on 2018/5/15.
//  Copyright © 2018年 syx. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SYModelExample.h"
@interface SYModelTests : XCTestCase

@end

@implementation SYModelTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    
    
    [SYModelExample example_DicToModel];
    
    [SYModelExample example_DicToModel_PropertyMapper];
    
    [SYModelExample example_DicToModel_PropertyGenericClass];
    
}

- (void)testOBLC2 {
#if !__OBJC2__
    NSLog(@"\n******%d\n******", __OBJC2__);
#endif
    
    NSLog(@"\n&&&&&&&\n %d \n&&&&&&", __OBJC2__);
    
}



- (void)testTypeEncode {
    
    NSDictionary *typeEncode = @{@"int":[self toNStringWithCstring:@encode(int)],
                                 @"short":[self toNStringWithCstring:@encode(short)],
                                 @"long":[self toNStringWithCstring:@encode(long)],
                                 @"long long":[self toNStringWithCstring:@encode(long long)],
                                 @"char":[self toNStringWithCstring:@encode(char)],
                                 @"unsigned char":[self toNStringWithCstring:@encode(unsigned char)],
                                 @"unsigned int":[self toNStringWithCstring:@encode(unsigned int)],
                                 @"unsigned short":[self toNStringWithCstring:@encode(unsigned short)],
                                 @"unsigned long":[self toNStringWithCstring:@encode(unsigned long)],
                                 @"unsigned long long":[self toNStringWithCstring:@encode(unsigned long long)],
                                 @"float":[self toNStringWithCstring:@encode(float)],
                                 @"double":[self toNStringWithCstring:@encode(double)],
                                 @"BOOL":[self toNStringWithCstring:@encode(BOOL)],
                                 @"void":[self toNStringWithCstring:@encode(void)],
                                 @"NSArray":[self toNStringWithCstring:@encode(NSArray)]
                                 };
    
    
    
    NSLog(@"****** \n %@ \n ********",typeEncode);
    
}

- (NSString *)toNStringWithCstring:(char *)c {
    return [[NSString alloc]initWithUTF8String:c];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
