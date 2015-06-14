//
//  BTOAuthLoginBase.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

/*!
 @abstract Each time an URL is loaded, one of those actions can be performed
 */
typedef enum : NSUInteger {
    // Just load the URL
    BTOAuthFancyLoadURL,
    // Load the URL and show the approval sheet
    BTOAuthFancyShowSheet,
    // Load the URL and hide the approval sheet
    BTOAuthFancyHideSheet,
    // Load the URL and afterwards insert credentials.
    // This implies that the URL to be loaded is of BTOAuthURLType BTOAuthURLTypeLoginPage
    BTOAuthFancyInsertCredentials,
    // Load the URL with the informationt hat the credentials were wrong
    BTOAuthFancyWrongCredentials,
    // Ignore the URL, there was an error
    BTOAuthFancyError,
    // Ignore this URL, and instead load the provided *customURL
    BTOAuthFancyCustomURL,
    // This is a custom URL to be loaded in Safari
    BTOAuthFancyLoadExternal,
    // This URL contains the token, authentication is finished, we're done
    BTOAuthFancyFinished,
} BTOAuthURLAction;

/*!
 @abstract These are the possible types an URL can be
 */
typedef enum : NSUInteger {
    // A normal URL
    BTOAuthURLTypeDefault,
    // The URL to the "Login into Service" page
    BTOAuthURLTypeLoginPage,
    // The URL to the "Approve App ? for Service" page
    BTOAuthURLTypeApprovalPage
} BTOAuthURLType;


@protocol BTOAuthUserCredentialsProtocol <NSObject>
@required
/*!
 @abstract Will be called when the user-provided credentials for login proved to be wrong
 */
- (void) loginManagerCredentialsWrong:(id)loginManager;
/*!
 @abstract Will be called when login & approval was successful
 */
- (void) loginManagerLoginSuccess:(id)loginManager;
/*!
 @abstract Will be called when login or approval failed
 */
- (void) loginManagerLoginFailure:(id)loginManager;
@end

/*!
 @abstract the OAuth Login Base Class
 @discussion This class itself does nothing. It has to be subclassed, and all appropriate methods have to be implemented.
   Then, the resulting class can be used for a fancy oauth flow where the username / password does happen in a constrained
   & well defined environment
 */
@interface BTOAuthLoginBase : NSObject

#pragma mark -
#pragma mark Public Interface

/*!
 @abstract Once username and password have been gathered, start the login process with them
 */
- (void) startLoginProcessWithUsername:(NSString*)username password:(NSString*)password;

#pragma mark -
#pragma mark To be implemented by Subclasses

/// The name of the service
@property (readonly) NSString *name;

/// The URL to be used for authorization
@property (readonly) NSURL *authorizationURL;

/// The Client ID
@property (readonly) NSString *clientID;

/// The Client Secret
@property (readonly) NSString *clientSecret;

/// The Token retrieval URL
@property (readonly) NSURL *tokenURL;

/// The Redirect URL
@property (readonly) NSURL *redirectURL;

- (void) addLoginParams:(NSMutableDictionary*)params;

/*!
 @abstract Return the appropriate action for the URL before it is being loaded
 @discussion The Base Class will ask for each URL that is being loaded in the OAuth process what kind of action should be performed. 
 This allows great flexibility in terms of how the flow should be implemented for a particular oauth provider
 @param url The URL that is about to be loaded
 @param customURL If the return type is BTOAuthFancyCustomURL then this is a NSURL that should be loaded instead of url
 @param error If there was an error, this will be filled
 @returns The type of action to be implemented
 */
- (BTOAuthURLAction) actionForURL:(NSURL*)url orCustomURL:(NSURL**)customURL
                       error:(NSError**)error;

/*!
 @abstract When a page is done loading, this will be called to figure out how to act on the loaded page
 @discussion A loaded page can either be the login page, the approval page, or anything else. For Login and Approval special actions are needed. This call allows the Subclass to figure out what kind of page it is
 @param dataSource The WebKit datasource that just finished loading
 @returns the URL type
 */
- (BTOAuthURLType) pageTypeForDataSource:(WebDataSource*)dataSource;

/*!
 @abstract When the page is a login page, the subclass has to modify the HTML via Javascript to fill the form with the correct credentials *and then submit it*
 @discussion This is only needed if credentials are being entered in a seperate Window. One can also ignore that and for the login page also open a sheet. In that case this method can just do nothing
 @param username Username
 @param password Password
 @param webView The webview where the login form has been loaded
 */
- (void) fillCredentials:(NSString*)username password:(NSString*)password intoPage:(WebView*)webView;

@end

