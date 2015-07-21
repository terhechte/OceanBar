//
//  BTAppDelegate.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BTDigitalOceanLogin.h"

@interface BTAppDelegate : NSObject <NSApplicationDelegate, BTOAuthUserCredentialsProtocol>

@property (weak) IBOutlet BTDigitalOceanLogin *digitalOceanLogin;
@property (weak) IBOutlet NSButton *loginLogoutButton;
@property (weak) IBOutlet NSTextField *credentialUsernameField;
@property (weak) IBOutlet NSTextField *credentialPasswordField;
@property (weak) IBOutlet NSWindow *credentialWindow;
@property (retain) NSString *credentialLoginErrorMessage;

@property (retain) NSString *currentUserName;

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTabView *preferencesTabView;

- (IBAction)doLoginToDigitalOcean:(id)sender;

- (IBAction)credentialOk:(id)sender;
- (IBAction)credentialCancel:(id)sender;
- (IBAction)credentialSignup:(id)sender;

@end
