//
//  BTOAuthLoginBase.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

/**
 @abstract Each time an URL is loaded, one of those actions can be performed
 */
typedef enum : NSUInteger {
    BTOAuthFancyLoadURL,
    BTOAuthFancyShowSheet,
    BTOAuthFancyHideSheet,
    BTOAuthFancyInsertCredentials,
    BTOAuthFancyWrongCredentials,
    BTOAuthFancyError,
    BTOAuthFancyCustomURL,
    BTOAuthFancyLoadExternal,
    BTOAuthFancyFinished,
} BTOAuthURLAction;

typedef enum : NSUInteger {
    BTOAuthURLTypeDefault,
    BTOAuthURLTypeLoginPage,
    BTOAuthURLTypeApprovalPage
} BTOAuthURLType;


@protocol BTOAuthUserCredentialsProtocol <NSObject>
@required
- (void) loginManagerCredentialsWrong:(id)loginManager;
- (void) loginManagerLoginSuccess:(id)loginManager;
- (void) loginManagerLoginFailure:(id)loginManager;
@end

@interface BTOAuthLoginBase : NSObject

@property (readonly) NSString *name;

// The URL to be used for authorization
@property (readonly) NSURL *authorizationURL;

// The Client ID
@property (readonly) NSString *clientID;

// The Client Secret
@property (readonly) NSString *clientSecret;

// The Token retrieval URL
@property (readonly) NSURL *tokenURL;

// The Redirect URL
@property (readonly) NSURL *redirectURL;

- (void) addLoginParams:(NSMutableDictionary*)params;

- (BTOAuthURLAction) actionForURL:(NSURL*)url orCustomURL:(NSURL**)customURL
                       error:(NSError**)error;

- (BTOAuthURLType) pageTypeForDataSource:(WebDataSource*)dataSource;

@end

