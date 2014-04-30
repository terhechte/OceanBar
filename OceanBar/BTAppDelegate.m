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
                               @"hideFromDock": @YES,
                               @"doAPIKey": @"",
                               @"doAPISecret": @""};
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
	
    // Register the defaults, and set the start values
	if (![d boolForKey:@"hasPreferencesDefaults"]) {
		[d setBool:YES forKey:@"hasPreferencesDefaults"];
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaults];
	}
    
    // if this is the first start, animate the user to fill in his values
    if ([[d objectForKey:@"doAPIKey"] length] == 0 ||
        [[d objectForKey:@"doAPISecret"] length] == 0) {
        // display the preferences window
        [self.window makeKeyAndOrderFront:self];
        
        NSAlert *alert =
        [NSAlert alertWithMessageText:NSLocalizedString(@"Please Enter your API Keys", @"First Start Popup")
                        defaultButton:NSLocalizedString(@"Take me there", @"First Start Popup")
                      alternateButton:NSLocalizedString(@"Ok", @"First Start Popup")
                          otherButton:nil
            informativeTextWithFormat:NSLocalizedString(@"For this app to work, you have to get the Client ID and generate the Digital Ocean API Key in the Digital Ocean Console. Then, you can enter the keys in here.", @"First Start Popup")];
        
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:nil];
    }
    
    self.statusBarController = [[BTStatusbarController alloc] init];
    self.statusBarController.delegate = self;
    
    if (![d boolForKey:@"hideFromDock"]) {
        [self showDockIcon];
    }
}

- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(int *) contextInfo {
    if (returnCode == 1) {
        [self goDigitalOceanKeys:self];
    }
}

//-----------------------------------------------------------------------------
#pragma mark Preferences Actions
//-----------------------------------------------------------------------------

- (IBAction)goDigitalOceanKeys:(id)sender {
    [[NSWorkspace sharedWorkspace]
     openURL:[NSURL URLWithString:kDigitalOceanAPILink]];
}

- (IBAction)testDigitalOceanKeys:(id)sender {
    BTOceanData *oceanData = [[BTOceanData alloc] init];
    [oceanData testCredentialsWithSuccess:^(id results) {
        self.testCredentialError = nil;
    } error:^(NSError *error) {
        self.testCredentialError = error.localizedDescription;
    }];
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
