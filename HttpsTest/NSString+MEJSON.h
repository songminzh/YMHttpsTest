//
//  NSString+MEJSON.h
//  whhm_ios
//
//  Created by Murphy Zheng on 16/4/15.
//  Copyright © 2016年 Mieasy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (MEJSON)
/**
 * string to dictionary
 */
+(NSDictionary *)parseJSONStringToNSDictionary:(NSString *)JSONString;
/**
 * string to array
 */
+(NSArray *)parseJSONStringToArray:(NSString *)JSONString;
@end
