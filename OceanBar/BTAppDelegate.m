//
//  BTAppDelegate.m
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import "BTAppDelegate.h"
#import "BTStatusbarController.h"
#import "BTSocialTextView.h"
#import <NXOAuth2Client/NXOAuth2.h>

NSString * const kDigitalOceanAPILink = @"https://cloud.digitalocean.com/api_access";

@interface BTAppDelegate() <BTStatusbarControllerDelegate>
@property (retain) BTStatusbarController *statusBarController;
@end

@implementation BTAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *defaults = @{@"reloadInterval": @2,
                               @"postNotificationCenter": @YES,
                               @"hideFromDock": @YES};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
    // Register the defaults, and set the start values
	if (![d boolForKey:@"hasPreferencesDefaults"]) {
		[d setBool:YES forKey:@"hasPreferencesDefaults"];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaults];
	}
    
    // if this is the first start, animate the user to fill in his values
    NSArray *accounts = [[NXOAuth2AccountStore sharedStore] accounts];
    if (accounts.count == 0) {
        // display the preferences window
        [self.window makeKeyAndOrderFront:self];
        
        NSAlert *alert =
        [NSAlert alertWithMessageText:NSLocalizedString(@"Please sign in to Digital Ocean", @"First Start Popup")
                        defaultButton:NSLocalizedString(@"Ok", @"First Start Popup")
                      alternateButton:nil
                          otherButton:nil
            informativeTextWithFormat:NSLocalizedString(@"Please sign in to Digital Ocean with your Digital Ocean User account", @"First Start Popup")];
        
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:nil];
    } else {
        NSLog(@"accounts: %@", accounts);
    }
    
    self.statusBarController = [[BTStatusbarController alloc] init];
    self.statusBarController.delegate = self;
    
    if (![d boolForKey:@"hideFromDock"]) {
        [self showDockIcon];
    }
}

- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(int *) contextInfo {
    [self.preferencesTabView selectTabViewItemAtIndex:1];
    [self doLoginToDigitalOcean:nil];
}


- (IBAction)doLoginToDigitalOcean:(id)sender {
    [self.window beginSheet:self.credentialWindow
          completionHandler:nil];
}

- (IBAction)credentialOk:(id)sender {
    self.credentialLoginErrorMessage = @"";
    
    NSString *username = self.credentialUsernameField.stringValue;
    NSString *password = self.credentialPasswordField.stringValue;
    
    if (username == nil || username.length == 0) {
        self.credentialLoginErrorMessage = NSLocalizedString(@"Error: Please enter a valid username", nil);
        return;
    }
    
    if (password == nil || password.length == 0) {
        self.credentialLoginErrorMessage = NSLocalizedString(@"Error: Please enter a valid password", nil);
        return;
    }
    
    [self.window endSheet:self.credentialWindow];
    
    [self.digitalOceanLogin startLoginProcessWithUsername:username password:password];
}

- (IBAction)credentialCancel:(id)sender {
    [self.window endSheet:self.credentialWindow];
}

- (IBAction)credentialSignup:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://cloud.digitalocean.com/registrations/new"]];
}


//-----------------------------------------------------------------------------
#pragma mark BTStatusBarControllerDelegate
//-----------------------------------------------------------------------------

- (void) openPreferences {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:self];
}

- (void) exit {
    [NSApp terminate:self];
}

- (void) showDockIcon {
    // currently deactivated, there's nothing in the main menu that would
    // make this functionality any useful...
    return;
    //http://stackoverflow.com/questions/620841/how-to-hide-the-dock-icon
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
 
}

@end
