//
//  NSString+MEJSON.m
//  whhm_ios
//
//  Created by Murphy Zheng on 16/4/15.
//  Copyright © 2016年 Mieasy. All rights reserved.
//

#import "NSString+MEJSON.h"

@implementation NSString (MEJSON)
+(NSDictionary *)parseJSONStringToNSDictionary:(NSString *)JSONString {
    
    NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingMutableLeaves error:nil];
    return responseJSON;
    
}
+(NSArray *)parseJSONStringToArray:(NSString *)JSONString {
    
    NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *responseJSON = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingMutableLeaves error:nil];
    return responseJSON;
    
}
@end
