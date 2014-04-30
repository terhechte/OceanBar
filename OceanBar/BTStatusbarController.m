//
//  BTStatusbarController.m
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import "BTStatusbarController.h"
#import "BTOceanData.h"
#import "BTSocialTextView.h"

typedef void (^ConfirmationAction)();

const void* kApiCredentialContext = &kApiCredentialContext;

///-----------------------------------------------------------------------------
#pragma mark Icon Setup
//-----------------------------------------------------------------------------

NSString * const kIconDefault = @"default";
NSString * const kIconNewContent = @"newContent";
NSString * const kIconLoading = @"loading";
NSString * const kIconError = @"notConnected";

NSString * const kIconActive = @"stateActive";
NSString * const kIconInactive = @"stateInactive";

NSString * const kIconLocked = @"closedLock";
NSString * const kIconUnlocked = @"openLock";

@interface BTStatusbarController() {
    bool _loading;
    NSString *_loadError;
}
@property (retain) NSStatusItem* mainStatusbarItem;
@property (retain) NSTimer* reloadTimer;
@property (retain) BTOceanData *oceanData;
@end

@implementation BTStatusbarController

//-----------------------------------------------------------------------------
#pragma mark Setup & Creation
//-----------------------------------------------------------------------------

- (id) init {
    self = [super init];
    if (self) {
        self.oceanData = [[BTOceanData alloc] init];
        
        [self setupStatusbarItemWithDroplets:@[]];
        
        [self reloadContents];
        
        // any changes to the id / key have to trigger a reload
        NSUserDefaultsController *userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
        [userDefaultsController addObserver:self
                                 forKeyPath:@"values.doAPIKey"
                                    options:0
                                    context:&kApiCredentialContext];
        [userDefaultsController addObserver:self
                                 forKeyPath:@"values.doAPISecret"
                                    options:0
                                    context:&kApiCredentialContext];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &kApiCredentialContext) {
        [self forceReload];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void) forceReload {
        [self.reloadTimer invalidate];
        self.reloadTimer = nil;
        [self reloadContents];
}

- (void) setIconState {
    NSString *state = kIconDefault;
    
    if (_loading)
        state = kIconLoading;
    else if (_loadError)
        state = kIconError;
    
    [self.mainStatusbarItem setImage:[NSImage imageNamed:state]];
}

- (void) setupStatusbarItemWithDroplets:(NSArray*)droplets {
    self.mainStatusbarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    //[self.menuBarStatusItem setMenu:self.menuBarMenu];
    [self.mainStatusbarItem setEnabled: YES];
    
    //let it highlight when the user activates it
    [self.mainStatusbarItem setHighlightMode:YES];
    
    [self.mainStatusbarItem setMenu: [self mainMenuForDroplets:droplets]];
    
    [self setIconState];
}

- (void) reloadContents {
    // ignore if the credentials aren't set yet
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults objectForKey:@"doAPIKey"] length] == 0 ||
        [[defaults objectForKey:@"doAPISecret"] length] == 0) {
        _loadError = NSLocalizedString(@"Missing Credentials", @"Menu entry if we can't load");
        [self setupStatusbarItemWithDroplets:@[]];
        return;
    }
    
    // sometimes, loading takes time, simple indicator
    _loading = YES;
    
    [self.oceanData loadDropletsWithSuccess:^(NSArray *results) {
        _loading = NO;
        _loadError = nil;
        [self setupStatusbarItemWithDroplets:results];
    } failure:^(NSError *error) {
        _loading = NO;
        
        _loadError = error.localizedDescription;
        
        [self setupStatusbarItemWithDroplets:@[]];
    }];
    
    // and trigger the next reload
    NSNumber *reloadInterval = [defaults objectForKey:@"reloadInterval"];
    if (reloadInterval.intValue < 1)reloadInterval = @1;
    self.reloadTimer = [NSTimer scheduledTimerWithTimeInterval:reloadInterval.intValue * 60.0
                                                        target:self
                                                      selector:@selector(reloadContents)
                                                      userInfo:nil
                                                       repeats:NO];
}

- (NSMenu*) mainMenuForDroplets:(NSArray*)droplets {
    NSMenu *statusMenu = [[NSMenu alloc] init];
    
    if (droplets.count > 0) {
        for (BTOceanDataDroplet* droplet in droplets) {
            NSMenuItem *mainItem = [[NSMenuItem alloc] init];
            [mainItem setTitle:droplet.name];
            [mainItem setEnabled: [droplet isActive]];
            
            if (droplet.isActive)
                mainItem.image = [NSImage imageNamed:kIconActive];
            else
                mainItem.image = [NSImage imageNamed:kIconInactive];
            
            NSMenu *subMenu = [self menuForDroplet:droplet];
            [mainItem setSubmenu:subMenu];
            
            [statusMenu addItem: mainItem];
        }
    } else {
        if (_loading) {
            NSMenuItem *mainItem = [[NSMenuItem alloc] init];
            [mainItem setTitle:NSLocalizedString(@"Loading...", @"If we're loading data. displayed as a menu entry")];
            [statusMenu addItem:mainItem];
        }
        if (_loadError) {
            NSMenuItem *mainItem = [[NSMenuItem alloc] init];
            [mainItem setTitle:$p(@"Error: %@", _loadError)];
            [statusMenu addItem:mainItem];
        }
        // otherwise, the user probably didn't set it up, or we don't have any droplets...
    }
    
    [statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *prefItem = [[NSMenuItem alloc]
                            initWithTitle:NSLocalizedString(@"Preferences", @"main menu")
                            action:@selector(openPreferences:)
                            keyEquivalent:@","];
    prefItem.target = self;
    
    [statusMenu addItem:prefItem];
    
    NSMenuItem *exitItem = [[NSMenuItem alloc]
                            initWithTitle:NSLocalizedString(@"Quit", @"main menu")
                            action:@selector(exit:)
                            keyEquivalent:@"q"];
    exitItem.target = self;
    
    [statusMenu addItem:exitItem];
    
    return statusMenu;
}

- (NSMenu*) menuForDroplet:(BTOceanDataDroplet*) droplet {
    const NSUInteger kMenuWidth = 220;
    
    NSMenu *dropletMenu = [[NSMenu alloc] initWithTitle:droplet.name];
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    
    // The first line is a simple custom view, too
    NSView *headlineView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kMenuWidth, 35)];
    NSImageView *im = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 9, 16, 16)];
    if (droplet.isActive)
        im.image = [NSImage imageNamed:kIconActive];
    else
        im.image = [NSImage imageNamed:kIconInactive];
    [headlineView addSubview:im];
    
    NSTextField *labelField = [[NSTextField alloc] initWithFrame:
                               NSMakeRect(40, 5, 80, 20)];
    [labelField setBordered:NO];
    [labelField setEditable:NO];
    [labelField setStringValue:droplet.status];
    
    NSButton *openButton = [[NSButton alloc]
                            initWithFrame:NSMakeRect(kMenuWidth - 70, 4, 60, 25)];
    openButton.title = NSLocalizedString(@"Open...", @"info box");
    [openButton setButtonType:NSMomentaryLightButton];
    [openButton setBezelStyle:NSTexturedRoundedBezelStyle];
    [openButton setTarget:self];
    [openButton setAction:@selector(openDropletAction:)];
    [openButton setTag: droplet.identifier.integerValue];
    
    [headlineView addSubview:openButton];
    [headlineView addSubview:labelField];
    
    NSMenuItem *activeitem = [[NSMenuItem alloc] init];
    activeitem.view = headlineView;
    
    [dropletMenu addItem:activeitem];
    
    BTSocialTextView *dropletTextView = [[BTSocialTextView alloc]
                                         initWithFrame:NSMakeRect(0, 0, kMenuWidth, 300)];
    
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dropletTextView addItem:NSLocalizedString(@"Created", @"info box")
                   withValue:[dateFormatter stringFromDate:droplet.createdAt]];
    
    [dropletTextView addItem:NSLocalizedString(@"IP Address", @"info box") withValue:droplet.ipAddress];
    if (droplet.privateIpAddress && droplet.privateIpAddress.length > 0)
        [dropletTextView addItem:NSLocalizedString(@"Private IP", @"info box") withValue:droplet.privateIpAddress];
    
    // Create the Image String:
    if (droplet.image) {
        NSMutableString *imageString = [droplet.image.name mutableCopy];
        if (droplet.image.distribution && droplet.image.distribution.length > 0)
            [imageString appendFormat:@"\n%@", droplet.image.distribution];
        
        [dropletTextView addItem:NSLocalizedString(@"Image", @"info box") withValue:imageString.copy];
        
    } else {
        [dropletTextView addItem:NSLocalizedString(@"Image", @"info box") withValue:NSLocalizedString(@"Image not found", @"info box if unknown image")];
    }
    
    [dropletTextView addItem:NSLocalizedString(@"Region", @"info box") withValue:droplet.region.name];
    
    // Create the Size String
    if (droplet.size) {
        NSMutableString *sizeString = [droplet.size.name mutableCopy];
        NSArray *sizeName = @[NSLocalizedString(@"Memory", @"Info box size"),
                              NSLocalizedString(@"Disk", @"Info box size"),
                              NSLocalizedString(@"CPU", @"Info box size"),
                              NSLocalizedString(@"Cost/Hour", @"Info box size"),
                              NSLocalizedString(@"Cost/Month", @"Info Box size")];
        
        NSArray *sizeKeys = @[droplet.size.memory,
                              droplet.size.disk,
                              droplet.size.cpu,
                              droplet.size.costPerHour,
                              droplet.size.costPerMonth];
        for (int i=0; i<sizeName.count; i++) {
            [sizeString appendFormat:@"\n%@: %@", sizeName[i], sizeKeys[i]];
        }
        
        [dropletTextView addItem:NSLocalizedString(@"Size", @"info box size") withValue:sizeString.copy];
    } else {
        [dropletTextView addItem:NSLocalizedString(@"Size", @"info box size") withValue:NSLocalizedString(@"Size not found", @"info box no size found")];
    }
    
    [dropletTextView render];
    
    [viewItem setView:dropletTextView];
    
    [dropletMenu addItem:viewItem];
    
    [dropletMenu addItem:[NSMenuItem separatorItem]];
    
    // Several Actions to perform on the droplet
    NSMenuItem *rebootItem =
    [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reboot", @"info box")
                               action:@selector(rebootDroplet:)
                        keyEquivalent:@"r"];
    rebootItem.target = self;
    rebootItem.representedObject = droplet;
    rebootItem.image = [NSImage imageNamed:NSImageNameRefreshFreestandingTemplate];
    [dropletMenu addItem:rebootItem];
    
    NSMenuItem *shutdownItem =
    [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Shutdown", @"info box")
                               action:@selector(shutdownDroplet:)
                        keyEquivalent:@"s"];
    shutdownItem.target = self;
    shutdownItem.representedObject = droplet;
    shutdownItem.image = [NSImage imageNamed:NSImageNameStopProgressTemplate];
    [dropletMenu addItem:shutdownItem];
    
    NSMenuItem *openItem = [[NSMenuItem alloc] init];
    openItem.title = NSLocalizedString(@"Open on Port...", @"info box");
    openItem.submenu = [self listOfPortsForDroplet:droplet];
    openItem.image = [NSImage imageNamed:NSImageNameRightFacingTriangleTemplate];
    [dropletMenu addItem:openItem];
    
    
    return dropletMenu;
}

- (NSMenu*) listOfPortsForDroplet:(BTOceanDataDroplet*)droplet {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Ports", @"The ports dropdown")];
    NSArray *ports = @[@80, @4000, @4040, @8000, @8080, @9000];
    for (NSNumber *port in ports) {
        NSMenuItem *portMenuItem = [[NSMenuItem alloc] init];
        portMenuItem.representedObject = @{@"droplet": droplet,
                                           @"port": port};
        portMenuItem.keyEquivalent = $p(@"%li", [ports indexOfObject:port] + 1);
        portMenuItem.target = self;
        portMenuItem.action = @selector(openDropletOnPortAction:);
        portMenuItem.title = $p(@"%@", port);
        [menu addItem:portMenuItem];
    }
    
    return menu;
}

//-----------------------------------------------------------------------------
#pragma mark Menu Actions
//-----------------------------------------------------------------------------

- (void) openDropletAction:(NSButton*)button {
    BTOceanDataDroplet *droplet = [self.oceanData dropletForID:@(button.tag)];
    if (droplet) {
        [self openDroplet:droplet onPort:@80];
    }
}

- (void) openDropletOnPortAction:(NSMenuItem*)menuItem {
    NSDictionary *info = menuItem.representedObject;
    BTOceanDataDroplet *droplet = info[@"droplet"];
    NSNumber *port = info[@"port"];
    
    [self openDroplet:droplet onPort:port];
}

- (void) openDroplet:(BTOceanDataDroplet*)droplet onPort:(NSNumber*)port {
    NSString* portString = (port.integerValue == 80 ? @"" : $p(@":%@", port));
    NSString *urlString = $p(@"http://%@%@", droplet.ipAddress, portString);
    [[NSWorkspace sharedWorkspace]
     openURL:[NSURL URLWithString:urlString]];
}

- (void) rebootDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to reboot '%@'", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, reboot it", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData rebootDroplet:droplet finishAction:^(id results) {
               [self forceReload];
           }];
       }];
}

- (void) shutdownDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to shutdown '%@'", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, shut it down", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData shutdownDroplet:droplet finishAction:^(id results) {
               [self forceReload];
           }];
       }];
}

- (void) openPreferences:(NSMenuItem*) item {
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(BTStatusbarControllerDelegate)]) {
        [self.delegate openPreferences];
    }
}

- (void) exit:(NSMenuItem*) item {
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(BTStatusbarControllerDelegate)]) {
        [self.delegate exit];
    }
}

- (void) confirm:(NSString*)text
        okButton:(NSString*)okButton
    cancelButton:(NSString*)cancelButton
      withAction:(ConfirmationAction)action {
    NSAlert *alert =
    [NSAlert alertWithMessageText:NSLocalizedString(@"Confirm", @"action confirmation title")
                    defaultButton:cancelButton
                  alternateButton:okButton
                      otherButton:nil
        informativeTextWithFormat:text];
    NSUInteger result = [alert runModal];
    if (result == 0) {
        action();
    }
}

@end
