//
//  BTDigitalOceanLogin.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 13/06/15.
//  Copyright (c) 2015 Benedikt Terhechte. All rights reserved.
//

#import "BTOAuthLoginBase.h"

@interface BTDigitalOceanLogin : BTOAuthLoginBase {
    // Internal state we need to assess whether it works
    BOOL _wasInLogin;
    BOOL _wasInSession;
    BOOL _didShowSheet;
}
@end
