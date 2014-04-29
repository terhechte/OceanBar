//
//  BTStatusbarController.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BTStatusbarController : NSObject
@property (weak) id delegate;
@end

@protocol BTStatusbarControllerDelegate <NSObject>
- (void) openPreferences;
- (void) exit;
@end
