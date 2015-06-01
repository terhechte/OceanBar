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
NSString * const kIconUpdated = @"stateUpdated";

NSString * const kIconLocked = @"closedLock";
NSString * const kIconUnlocked = @"openLock";

// how many seconds do we wait before we reload after droplet actions like shutdown etc?
const NSUInteger kReloadDelay = 10;

@interface BTStatusbarController() <BTOceanDataDelegate, NSMenuDelegate> {
    bool _loading;
    NSString *_loadError;
    NSArray *_updated;
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
        self.oceanData.delegate = self;
        
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
    else if (_updated)
        state = kIconNewContent;
    
    [self.mainStatusbarItem setImage:[NSImage imageNamed:state]];
}

- (void) setupStatusbarItemWithDroplets:(NSArray*)droplets {
    if (!self.mainStatusbarItem) {
        self.mainStatusbarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        [self.mainStatusbarItem setEnabled: YES];
        
        //let it highlight when the user activates it
        [self.mainStatusbarItem setHighlightMode:YES];
    }
    
    [self.mainStatusbarItem setMenu: [self mainMenuForDroplets:droplets]];
    
    [self setIconState];
    
    [self.mainStatusbarItem.menu setDelegate:self];
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
            
            if (droplet.isActive)
                mainItem.image = [NSImage imageNamed:kIconActive];
            else
                mainItem.image = [NSImage imageNamed:kIconInactive];
            
            if ([_updated containsObject:droplet]) {
                mainItem.image = [NSImage imageNamed:kIconUpdated];
            }
            
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
    
    [statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *refreshItem = [[NSMenuItem alloc]
                            initWithTitle:NSLocalizedString(@"Refresh", @"main menu")
                            action:@selector(forceReload)
                            keyEquivalent:@"r"];
    refreshItem.target = self;
    [statusMenu addItem:refreshItem];
    
    [statusMenu addItem:[NSMenuItem separatorItem]];
    
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
    
    // containing the current state as a led
    NSImageView *im = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 9, 16, 16)];
    if (droplet.isActive)
        im.image = [NSImage imageNamed:kIconActive];
    else
        im.image = [NSImage imageNamed:kIconInactive];
    [headlineView addSubview:im];
    
    // and the current locked state
    NSImageView *imLocked = [[NSImageView alloc] initWithFrame:NSMakeRect(30, 9, 16, 16)];
    if (droplet.locked)
        imLocked.image = [NSImage imageNamed:kIconLocked];
    else
        imLocked.image = [NSImage imageNamed:kIconUnlocked];
    [headlineView addSubview:imLocked];
    
    // the label with the active status
    NSTextField *labelField = [[NSTextField alloc] initWithFrame:
                               NSMakeRect(60, 5, 80, 20)];
    [labelField setBordered:NO];
    [labelField setEditable:NO];
    [labelField setStringValue:droplet.status];
    [labelField setBackgroundColor:[NSColor clearColor]];
    
    // the open button
    if (droplet.isActive) {
        NSButton *openButton = [[NSButton alloc]
                                initWithFrame:NSMakeRect(kMenuWidth - 70, 4, 60, 25)];
        openButton.title = NSLocalizedString(@"Open...", @"info box");
        [openButton setButtonType:NSMomentaryLightButton];
        [openButton setBezelStyle:NSTexturedRoundedBezelStyle];
        [openButton setTarget:self];
        [openButton setAction:@selector(openDropletAction:)];
        [openButton setTag: droplet.identifier.integerValue];
        
        [headlineView addSubview:openButton];
    }
    
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
    
    [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Copy public IP", @"info box")
                                       action: @selector(copyDropletPublicIp:)
                                          key:@"" droplet: droplet]];

    [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Copy private IP", @"info box")
                                       action: @selector(copyDropletPrivateIp:)
                                          key:@"" droplet: droplet]];

    // Several Actions to perform on the droplet
    if (droplet.isActive) {
        
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Shutdown", @"info box")
                                           action:@selector(shutdownDroplet:)
                                              key:@"s" droplet:droplet]];
        
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Reboot", @"info box")
                                           action:@selector(rebootDroplet:)
                                              key:@"r" droplet:droplet]];
        
        
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Power Cycle", @"info box")
                                           action:@selector(powerCycleDroplet:)
                                              key:@"" droplet:droplet]];
        
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Power Off", @"info box")
                                           action:@selector(powerOffDroplet:)
                                              key:@"" droplet:droplet]];
    } else {
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Power On", @"info box")
                                           action:@selector(powerOnDroplet:)
                                              key:@"" droplet:droplet]];
        
        [dropletMenu addItem:[NSMenuItem separatorItem]];
        
        [dropletMenu addItem:[self actionMenuItem:NSLocalizedString(@"Destroy!", @"info box")
                                           action:@selector(destroyDroplet:)
                                              key:@"" droplet:droplet]];
    
    }

    if (droplet.isActive) {
        [dropletMenu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *openItem = [[NSMenuItem alloc] init];
        openItem.title = NSLocalizedString(@"Open on Port...", @"info box");
        openItem.submenu = [self listOfPortsForDroplet:droplet];
        [dropletMenu addItem:openItem];
    }
    
    return dropletMenu;
}

- (NSMenuItem*) actionMenuItem:(NSString*)title action:(SEL)action key:(NSString*)k droplet:(BTOceanDataDroplet*)d {
    NSMenuItem *anItem =
    [[NSMenuItem alloc] initWithTitle:title
                               action:action
                        keyEquivalent:k];
    anItem.target = self;
    anItem.representedObject = d;
    return anItem;
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

- (void) copyDropletPublicIp:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    NSString *ip = droplet.ipAddress;
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObjects:NSStringPboardType, nil];
    [pasteboard declareTypes:types owner:self];
    [pasteboard setString: ip forType:NSStringPboardType];
}

- (void) copyDropletPrivateIp:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    NSString *ip = droplet.privateIpAddress;
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *types = [NSArray arrayWithObjects:NSStringPboardType, nil];
    [pasteboard declareTypes:types owner:self];
    [pasteboard setString: ip forType:NSStringPboardType];
}

- (void) rebootDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to reboot '%@'?", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, reboot it", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData rebootDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
           }];
       }];
}

- (void) shutdownDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to shutdown '%@'?", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, shut it down", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData shutdownDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
           }];
       }];
}

- (void) powerCycleDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to power cycle '%@'?", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, power cycle it", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData powercycleDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
           }];
       }];
}


- (void) powerOffDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to power off '%@'?", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, turn it off", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData powerOffDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
           }];
       }];
}

- (void) powerOnDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to power on '%@'?", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, turn it on", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData powerOnDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
           }];
       }];
}

- (void) destroyDroplet:(NSMenuItem*) menuItem {
    BTOceanDataDroplet *droplet = menuItem.representedObject;
    [self confirm:$p(NSLocalizedString(@"Do you really want to destroy '%@'? This is not reversible! All backups for this droplet will be deleted, too. However Snapshots won't. So if you want to keep the contents of this machine create a Snapshot before destroying it.", @"Droplet Action"), droplet.name)
         okButton:NSLocalizedString(@"Yes, destroy it", @"droplet action")
     cancelButton:NSLocalizedString(@"No", @"droplet action")
       withAction:^{
           [self.oceanData destroyDroplet:droplet finishAction:^(id results) {
               [self performSelector:@selector(forceReload) withObject:nil afterDelay:kReloadDelay];
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
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Wformat-security\"")
    _Pragma("clang diagnostic ignored \"-Wformat-nonliteral\"")
    NSAlert *alert =
    [NSAlert alertWithMessageText:NSLocalizedString(@"Confirm", @"action confirmation title")
                    defaultButton:cancelButton
                  alternateButton:okButton
                      otherButton:nil
        informativeTextWithFormat:text];
    _Pragma("clang diagnostic pop")
    NSUInteger result = [alert runModal];
    if (result == 0) {
        action();
    }
}

//-----------------------------------------------------------------------------
#pragma mark OceanData Delegate
//-----------------------------------------------------------------------------

- (void) oceanData:(BTOceanData *)data didFindChangedStateForDroplets:(NSArray *)droplets {
    // since updated state is ephemeral due to next requests, we have to keep it here.
    if (droplets.count > 0) {
        _updated = @[];
        for (NSDictionary* d in droplets) {
            _updated = [_updated arrayByAddingObject:d[@"droplet"]];
        }
        [self setIconState];
    }
}

//-----------------------------------------------------------------------------
#pragma mark NSMenuDelegate
//-----------------------------------------------------------------------------

- (void)menuWillOpen:(NSMenu *)menu {
    // reset the updated flag
    _updated = nil;
    [self setIconState];
}

@end
