//
//  BTDigitalOceanLogin.m
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import "BTDigitalOceanLogin.h"
#import "kDigitalOceanClientKey.h"
#import "NSString+BTOauthLogin.h"

@implementation BTDigitalOceanLogin

- (NSString*) name {
    return @"DigitalOcean";
}

- (NSString *) clientID {
    return kDigitalOceanClientId;
}

- (NSString *) clientSecret {
    return kDigitalOceanClientSecret;
}

- (NSURL *) authorizationURL {
    return [NSURL URLWithString:@"https://cloud.digitalocean.com/v1/oauth/authorize"];
}

- (NSURL *) tokenURL {
    return [NSURL URLWithString:@"https://cloud.digitalocean.com/v1/oauth/token"];
}

- (NSURL *) redirectURL {
    return [NSURL URLWithString:@"oceanbar://success"];
}

- (void) addLoginParams:(NSMutableDictionary*)params {
    NSMutableString *randString = @"".mutableCopy;
    for (int i=0; i<=16; i++)[randString appendFormat:@"%c", 'a' + arc4random_uniform(20)];
    [params setObject:randString.copy forKey:@"state"];
}
- (NSSet*) desiredScope {
    return [NSSet setWithObjects:@"read", @"write", nil];
}

- (BTOAuthURLAction) actionForURL:(NSURL*)url orCustomURL:(NSURL**)customURL
                            error:(NSError**)error {
    /* Flow:
     1. https://cloud.digitalocean.com/v1/oauth/authorize?client_id=297 is called.
     If the user is not logged in yet, there'll be a redirect to
     2. https://cloud.digitalocean.com/login - the login form
     3. There, the user submits, and comes to https://cloud.digitalocean.com/sessions
     4. Finally, if the login is successful, forwarded back to
     5. https://cloud.digitalocean.com/v1/oauth/authorize?client_id=297 to ask the user whether he wants to authorize the app
     6. If the user replies with yes, it will first forward to
     6.1 https://cloud.digitalocean.com/v1/oauth/authorize
     6.2 and then forward to oceanbar://success?code=96731e38d0d857b2884c1970520b1af52fa99114c9724e913a0185a6de5ed7c4
     7. If the user denies, it will first forward to
     7.1 https://cloud.digitalocean.com/v1/oauth/authorize
     7.2 and then forward to oceanbar://success?error=access_denied&error_description=The+resource+owner+or+authorization+server+denied+the+request.
     8. Any other links the user clicks, are to be loaded verbatim in a different window, there is a link to the app url: http://terhechte.github.io/OceanBar/
     9. There's a button to log out, which will do the following
     9.1 https://cloud.digitalocean.com/logout
     9.2 then https://cloud.digitalocean.com/
     9.3 and finally https://cloud.digitalocean.com/login again
     */
    
    // Flow for Digital Ocean
    NSString *path = [url path];
    NSString *host = [url host];
    NSString *scheme = [url scheme];
    
    if ([scheme isEqualToString:@"https"]) {
        if ([host isEqualToString:@"cloud.digitalocean.com"]) {
            if ([path isEqualToString:@"/v1/oauth/authorize"] && !_wasInLogin && !_wasInSession) {
                return BTOAuthFancyLoadURL;
            } else if ([path isEqualToString:@"/v1/oauth/authorize"] && _wasInLogin && _wasInSession && !_didShowSheet) {
                _didShowSheet = true;
                return BTOAuthFancyShowSheet;
            } else if ([path isEqualToString:@"/v1/oauth/authorize"] && _wasInLogin && _wasInSession && _didShowSheet) {
                // This is the the user denies or the user allows case, we just load it, and hide the sheet
                return BTOAuthFancyHideSheet;
            } else if ([path isEqualToString:@"/login"]) {
                if (_wasInSession && _wasInLogin) {
                    // the user entered a wrong password, we already were here:
                    _wasInLogin = false;
                    _wasInSession = false;
                    return BTOAuthFancyWrongCredentials;
                }
                _wasInLogin = true;
                return BTOAuthFancyInsertCredentials;
            } else if ([path isEqualToString:@"/sessions"]) {
                _wasInSession = true;
                return BTOAuthFancyLoadURL;
            } else if ([path isEqualToString:@"/logout"]) {
                _wasInSession = false;
                _wasInLogin = false;
                _didShowSheet = false;
                return BTOAuthFancyHideSheet;
            }
        }
    } else if ([scheme isEqualToString:@"oceanbar"]) {
        NSDictionary *components = [url.query dictionaryFromQueryComponents];
        if (components[@"code"]) {
            // success
            
            // reset state
            _didShowSheet = false;
            _wasInLogin = false;
            _wasInSession = false;
            
            return BTOAuthFancyFinished;
        } else if (components[@"error"]) {
            // failure
            
            // reset state
            _didShowSheet = false;
            _wasInLogin = false;
            _wasInSession = false;
            
            return BTOAuthFancyError;
        }
    }
    
    return BTOAuthFancyLoadExternal;
}

- (BTOAuthURLType) pageTypeForDataSource:(WebDataSource*)dataSource {
    
    /*!
     @abstract Verify that string contains all strings in strings.
     @discussion The strings need to be in sequential order in the document
     */
    BOOL (^stringContainsStrings)(NSArray *strings, NSString* string) = ^BOOL (NSArray *strings, NSString* string) {
        NSScanner *haystack = [NSScanner scannerWithString:string];
        
        for (NSString *needle in strings) {
            NSString *readString = nil;
            if (![haystack scanUpToString:needle intoString:&readString]) {
                return false;
            }
            if (readString.length == string.length) {
                return false;
            }
        }
        
        return true;
    };
    
    id<WebDocumentRepresentation> representation = dataSource.representation;
    if (!representation) {
        return BTOAuthURLTypeDefault;
    }
    
    if (![representation canProvideDocumentSource]) {
        return BTOAuthURLTypeDefault;
    }
    
    NSString *htmlContent = [representation documentSource];
    
    if (!htmlContent) {
        return BTOAuthURLTypeDefault;
    }
    
    // FIXME: Load these needles from a server, to quickly adopt to HTML changes.
    
    // Check if it is a login page
    if (stringContainsStrings(@[@"Log in to use your DigitalOcean<br> account with"], htmlContent))
        return BTOAuthURLTypeLoginPage;
    
    // Check if it is an authorization page
    if (stringContainsStrings(@[@"Authorize Application", @"would like permission to access your account"], htmlContent))
        return BTOAuthURLTypeApprovalPage;
    
    return BTOAuthURLTypeDefault;
}

- (void) fillCredentials:(NSString*)username password:(NSString*)password intoPage:(WebView*)webView {
    // FIXME: Load this javascript from a server, to quickly adopt to HTML changes
    // Insert Username and Password
    NSString *abc = [NSString stringWithFormat:@"document.getElementById(\"user_email\").value = \"%@\";\
                     document.getElementById(\"user_password\").value = \"%@\";\
                     document.getElementById(\"new_user\").submit();", username, password];
    
    WebScriptObject *script = [webView windowScriptObject];
    [script evaluateWebScript:abc];
}

@end
