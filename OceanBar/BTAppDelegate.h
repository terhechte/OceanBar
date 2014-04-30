//
//  BTAppDelegate.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BTAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (retain) NSString* testCredentialError;

- (IBAction)goDigitalOceanKeys:(id)sender;
- (IBAction)testDigitalOceanKeys:(id)sender;

@end
