//
//  BTOAuthLoginBase.m
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import "BTOAuthLoginBase.h"
#import "NSString+BTOauthLogin.h"
#import <NXOAuth2Client/NXOAuth2.h>

@interface BTOAuthLoginBase() {
    // if the webkit should, after finishing the next load, try to insert
    // credentials into the form
    BOOL _nextStepInsertCredentials;
    BOOL _nextStepShowApproval;
    
    // Tracking resource loading
    NSInteger _resourceCount;
    NSInteger _resourceFailedCount;
    NSInteger _resourceCompletedCount;
}
// This allows us to force a redirect to a specific URL by whitelisting it for the next request
@property (retain) NSURL *nextRequestWhiteListURL;

@property (retain) IBOutlet NSWindow *sheetParentWindow;

@property (retain) NSString *credentialUsername;
@property (retain) NSString *credentialPassword;

@property (retain) IBOutlet NSWindow *approvalSheet;

@property (retain) IBOutlet WebView *approvalWebView;

@property (retain) IBOutlet NSProgressIndicator *approvalProgressIndicator;

@property (weak) IBOutlet id<BTOAuthUserCredentialsProtocol> delegate;

@end

@implementation BTOAuthLoginBase

- (id) init {
    self = [super init];
    if (self) {
        [[NXOAuth2AccountStore sharedStore] setClientID:[self clientID]
                                                 secret:[self clientSecret]
                                       authorizationURL:[self authorizationURL]
                                               tokenURL:[self tokenURL]
                                            redirectURL:[self redirectURL]
                                         forAccountType:[self name]];
        
        // allow the login to modify the configuration
        NSMutableDictionary *params = @{}.mutableCopy;
        [self addLoginParams:params];
        
        if (params.count > 0) {
            NSMutableDictionary *config = [[NXOAuth2AccountStore sharedStore]
                                           configurationForAccountType:[self name]].mutableCopy;
            [[NXOAuth2AccountStore sharedStore] setConfiguration:config.copy forAccountType:@"DigitalOcean"];
        }
        
        // Make sure we identify succesful loading
        [[NSNotificationCenter defaultCenter] addObserverForName:NXOAuth2AccountStoreAccountsDidChangeNotification
                                                          object:[NXOAuth2AccountStore sharedStore]
                                                           queue:nil
                                                      usingBlock:^(NSNotification *aNotification){
                                                          if (self.delegate && [self.delegate conformsToProtocol:@protocol(BTOAuthUserCredentialsProtocol)]) {
                                                              [self.delegate loginManagerLoginSuccess:self];
                                                          }
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:NXOAuth2AccountStoreDidFailToRequestAccessNotification
                                                          object:[NXOAuth2AccountStore sharedStore]
                                                           queue:nil
                                                      usingBlock:^(NSNotification *aNotification){
                                                          if (self.delegate && [self.delegate conformsToProtocol:@protocol(BTOAuthUserCredentialsProtocol)]) {
                                                              [self.delegate loginManagerLoginFailure:self];
                                                          }
                                                      }];
        
    }
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) startLoginProcessWithUsername:(NSString*)username password:(NSString*)password {
    [self.approvalWebView setFrameLoadDelegate:self];
    [self.approvalWebView setPolicyDelegate:self];
    [self.approvalWebView setResourceLoadDelegate:self];
    
    self.credentialUsername = username;
    self.credentialPassword = password;
    
#ifdef DEBUG
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    
    [[NXOAuth2AccountStore sharedStore] requestAccessToAccountWithType:[self name]
                                   withPreparedAuthorizationURLHandler:^(NSURL *preparedURL){
                                       // Open a web view or similar
                                       [self.approvalWebView.mainFrame loadRequest:[NSURLRequest requestWithURL:preparedURL]];
                                   }];
}

- (void) displayApprovalSheet {
    [NSApp beginSheet:self.approvalSheet modalForWindow:self.sheetParentWindow modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (void) updateResourceStatus {
    [self.approvalProgressIndicator setDoubleValue:(double)((float)(_resourceCompletedCount + _resourceFailedCount) / (float)_resourceCount) * 100.0];
}

- (void) showApprovalProgressIndicator {
    [self.approvalProgressIndicator setHidden:false];
    [self.approvalProgressIndicator setDoubleValue:0];
}

- (void) hideApprovalProgressIndicator {
    [self.approvalProgressIndicator setHidden:true];
}

#pragma mark -
#pragma mark Implemented By Subclass

- (void) addLoginParams:(NSMutableDictionary*)params {
    [NSException raise:NSGenericException format:@"%@: Not Implemented yet", NSStringFromSelector(_cmd)];
}

- (BTOAuthURLAction) actionForURL:(NSURL*)url orCustomURL:(NSURL**)customURL
                            error:(NSError**)error {
    [NSException raise:NSGenericException format:@"%@: Not Implemented yet", NSStringFromSelector(_cmd)];
    return BTOAuthFancyLoadExternal;
}

- (BTOAuthURLType) pageTypeForDataSource:(WebDataSource*)dataSource {
    [NSException raise:NSGenericException format:@"%@: Not Implemented yet", NSStringFromSelector(_cmd)];
    return BTOAuthURLTypeDefault;
}

- (void) fillCredentials:(NSString*)username password:(NSString*)password intoPage:(WebView*)webView {
    [NSException raise:NSGenericException format:@"%@: Not Implemented yet", NSStringFromSelector(_cmd)];
}

#pragma mark -
#pragma mark ResourceLoadDelegate

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource {
    // Return some object that can be used to identify this resource
    return [NSNumber numberWithInteger:_resourceCount++];
}

-(NSURLRequest *)webView:(WebView *)sender
                resource:(id)identifier
         willSendRequest:(NSURLRequest *)request
        redirectResponse:(NSURLResponse *)redirectResponse
          fromDataSource:(WebDataSource *)dataSource {
    // Update the status message
    [self updateResourceStatus];
    return request;
}

-(void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource {
    _resourceFailedCount++;
    // Update the status message
    [self updateResourceStatus];
}

-(void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource {
    _resourceCompletedCount++;
    // Update the status message
    [self updateResourceStatus];
}

#pragma mark -
#pragma mark FrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    // always hide the progress indicator again
    [self hideApprovalProgressIndicator];
    
    BTOAuthURLType urlType = [self pageTypeForDataSource:frame.dataSource];
    
    // If this is the login page, insert the credentials
    if (_nextStepInsertCredentials && urlType == BTOAuthURLTypeLoginPage) {
        [self fillCredentials:self.credentialUsername password:self.credentialPassword intoPage:self.approvalWebView];
        
        _nextStepInsertCredentials = false;
    }
    
    // If this is the approval page, show the approval screen
    if (_nextStepShowApproval && urlType == BTOAuthURLTypeApprovalPage) {
        [self displayApprovalSheet];
        _nextStepShowApproval = false;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
    
    NSURL *url = [request URL];
    
    if ([url isEqualTo:self.nextRequestWhiteListURL]) {
        [listener use];
        return;
    }
    
    NSError *error = nil;
    NSURL *customURL = nil;
    BTOAuthURLAction anAction = [self actionForURL:url orCustomURL:&customURL error:&error];
    
    switch (anAction) {
        case BTOAuthFancyCustomURL:
            if (customURL) {
                self.nextRequestWhiteListURL = customURL;
                [listener ignore];
                [frame loadRequest:[NSURLRequest requestWithURL:customURL]];
            } else {
                [listener use];
            }
            break;
        case BTOAuthFancyError:
            if (error) {
                [listener ignore];
                [[NSAlert alertWithError:error] runModal];
            } else {
                [listener use];
            }
            break;
        case BTOAuthFancyHideSheet:
            [self.approvalSheet close];
            [self.sheetParentWindow endSheet:self.approvalSheet];
            [listener use];
            break;
        case BTOAuthFancyLoadURL:
            [listener use];
            break;
        case BTOAuthFancyShowSheet: {
            // we begin the sheet with a delay, so the listener instruction has time to load the new page
            [self showApprovalProgressIndicator];
            _nextStepShowApproval = true;
            [listener use];
            break;
        }
        case BTOAuthFancyWrongCredentials:
            if (self.delegate) {
                [self.delegate loginManagerCredentialsWrong:self];
            }
            [listener ignore];
            break;
        case BTOAuthFancyInsertCredentials:
            [self showApprovalProgressIndicator];
            _nextStepInsertCredentials = true;
            [listener use];
            break;
        case BTOAuthFancyLoadExternal:
            [[NSWorkspace sharedWorkspace] openURL:url];
            [listener ignore];
            break;
        case BTOAuthFancyFinished:
            [self hideApprovalProgressIndicator];
            [[NXOAuth2AccountStore sharedStore] handleRedirectURL:url];
            break;
    }
    
}

@end
