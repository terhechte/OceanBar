//
//  NSString+BTOauthLogin.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (BTOauthLogin)
- (NSString *)stringByDecodingURLFormat;
- (NSMutableDictionary *)dictionaryFromQueryComponents;
@end

