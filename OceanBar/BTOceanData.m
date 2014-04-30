//
//  BTOceanData.m
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import "BTOceanData.h"
#import <AFNetworking/AFNetworking.h>

@interface BTOceanDataItem() {
    NSDictionary *_storage;
}

@end

// small macro to convert NSNull or Nil to a default value
#define defau(c, d) (c == [NSNull null] || c == nil ? d : c)
// convert NSNull to nil
#define nu2ni(c) (c == [NSNull null] ? nil : c)

@implementation BTOceanDataItem

- (id) initWithDictionary:(NSDictionary *)otherDictionary {
    self = [super init];
    if (self) {
        _storage = otherDictionary;
    }
    return self;
}

- (NSDictionary*) data {
    return _storage;
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key {
    return nu2ni([_storage objectForKey:key]);
}

- (NSNumber*) identifier {
    return self[@"id"];
}

- (NSString*) name {
    return defau(self[@"name"], @"");
}

- (NSString*) slug {
    return defau(self[@"slug"], @"");
}

@end

@implementation BTOceanDataImage

- (NSString*) distribution {
    return self[@"distribution"];
}

@end

@implementation BTOceanDataRegion
@end

@implementation BTOceanDataSize

- (NSNumber*) memory {
    return self[@"memory"];
}
- (NSNumber*) disk {
    return self[@"disk"];
}

- (NSNumber*) cpu {
    return self[@"cpu"];
}

- (NSNumber*) costPerHour {
    return self[@"cost_per_hour"];
}

- (NSNumber*) costPerMonth {
    return self[@"cost_per_month"];
}

@end

@implementation BTOceanDataDroplet

- (bool) isActive {
    return [self[@"status"] isEqualToString:@"active"];
}

- (bool) backupsActive {
    return [self[@"backups_active"] boolValue];
}

- (NSString*) ipAddress {
    return self[@"ip_address"];
}

- (NSString*) privateIpAddress {
    return self[@"private_ip_address"];
}

- (bool) locked {
    return [self[@"locked"] boolValue];
}

- (NSString*) status {
    return self[@"status"];
}

- (NSDate*) createdAt {
    // 2013-01-01T09:30:00Z
    NSString *dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSDateFormatter *dateFormatter =
    [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormat];
    return [dateFormatter dateFromString:self[@"created_at"]];
}

@end

@interface BTOceanData()
{
    NSDictionary *_images;
    NSDictionary *_regions;
    NSDictionary *_sizes;
    NSDictionary *_droplets;
}
@end

@implementation BTOceanData

- (NSString*) authURLString {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return $p(@"?client_id=%@&api_key=%@", [defaults objectForKey:@"doAPIKey"],
              [defaults objectForKey:@"doAPISecret"]);
}

- (NSString*) dropletURLString {
    return $p(@"%@/droplets/%@", DIGITALOCEAN_BASE_URL, [self authURLString]);
}

- (NSString*) regionURLString {
    return $p(@"%@/regions/%@", DIGITALOCEAN_BASE_URL, [self authURLString]);
}

- (NSString*) imageURLString {
    return $p(@"%@/images/%@", DIGITALOCEAN_BASE_URL, [self authURLString]);
}

- (NSString*) sizeURLString {
    return $p(@"%@/sizes/%@", DIGITALOCEAN_BASE_URL, [self authURLString]);
}

- (BTOceanDataDroplet*) dropletForID:(NSNumber*)dropletId {
    return _droplets[dropletId];
}

- (void) loadDropletsWithSuccess:(BTOceanDataAction)actionBlock failure:(BTOceanDataError)errorBlock {
    // Each time we reload, we also reload the available
    // Regions, Images, and Sizes
    
    AFHTTPRequestOperation *op1 =
    [self requestOperationFor:[self sizeURLString]
                     createClass:@"BTOceanDataSize"
                     propertyKey:@"sizes"
                    successBlock:^(NSDictionary* results) {
                        _sizes = results;
                    } failBlock:^(NSError *error) {
                        NSLog(@"Error: %@", error);
                        errorBlock(error);
                    }];
    
    AFHTTPRequestOperation *op2 =
    [self requestOperationFor:[self regionURLString]
                     createClass:@"BTOceanDataRegion"
                     propertyKey:@"regions"
                    successBlock:^(NSDictionary* results) {
                        _regions = results;
                    } failBlock:^(NSError *error) {
                        NSLog(@"Error: %@", error);
                        errorBlock(error);
                    }];
    
    AFHTTPRequestOperation *op3 =
    [self requestOperationFor:[self imageURLString]
                     createClass:@"BTOceanDataImage"
                     propertyKey:@"images"
                    successBlock:^(NSDictionary* resultDict) {
                        _images = resultDict;
                    } failBlock:^(NSError *error) {
                        NSLog(@"Error: %@", error);
                        errorBlock(error);
                    }];
    
    AFHTTPRequestOperation *finalOp =
    [self requestOperationFor:[self dropletURLString]
                     createClass:@"BTOceanDataDroplet"
                     propertyKey:@"droplets"
                    successBlock:^(NSDictionary* results) {
                        
                        // calculate if we have a changed state to previously
                        // but only after the inital import.
                        if (_droplets &&
                            ![[self comparisonDictionary:results]
                            isEqualToDictionary:[self comparisonDictionary:_droplets]]) {
                            // find the changes
                            // TODO: Test for more changes than just activity?
                            NSMutableArray *changedDroplets = @[].mutableCopy;
                            for (BTOceanDataDroplet *droplet in results.allValues) {
                                if (!_droplets[droplet.identifier]) {
                                    [changedDroplets addObject:@{@"change": @"new", @"droplet": droplet}];
                                    [self postNotification:NSLocalizedString(@"New Droplet", @"If a new droplet appeared")
                                                  subtitle:$p(NSLocalizedString(@"Found new droplet: %@", @"if a new droplet appeared, subtitle"), droplet.name)];
                                } else if (![_droplets[droplet.identifier] isActive] == droplet.isActive) {
                                    [changedDroplets addObject:@{@"change": @"active", @"droplet": droplet}];
                                    if (droplet.isActive) {
                                        [self postNotification:NSLocalizedString(@"Droplet Activated", @"If a droplet activated")
                                                      subtitle:$p(NSLocalizedString(@"Droplet %@ was actived", @"if a droplet acitvated, subtitle"), droplet.name)];
                                    } else {
                                        [self postNotification:NSLocalizedString(@"Droplet Deactivated", @"If a droplet deactivated")
                                                      subtitle:$p(NSLocalizedString(@"Droplet %@ was deactived", @"if a droplet deacitvated, subtitle"), droplet.name)];
                                    }
                                }
                            }
                            if (self.delegate && [self.delegate conformsToProtocol:@protocol(BTOceanDataDelegate)]) {
                                [self.delegate oceanData:self didFindChangedStateForDroplets:changedDroplets.copy];
                            }
                        }
                        
                        _droplets = results;
                        
                        // add regions and images
                        for (BTOceanDataDroplet *droplet in [results allValues]) {
                            droplet.region = _regions[droplet[@"region_id"]];
                            droplet.size = _sizes[droplet[@"size_id"]];
                            droplet.image = _images[droplet[@"image_id"]];
                        }
                        actionBlock([results allValues]);
                    } failBlock:^(NSError *error) {
                        errorBlock(error);
                    }];
    
    [finalOp addDependency:op1];
    [finalOp addDependency:op2];
    [finalOp addDependency:op3];
    
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    operationQueue.maxConcurrentOperationCount = 1;
    [operationQueue addOperations:@[op1, op2, op3, finalOp]
                                 waitUntilFinished:NO];
}

- (void) testCredentialsWithSuccess:(BTOceanDataAction)actionBlock error:(BTOceanDataError)errorBlock {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:[self regionURLString] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        actionBlock(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        errorBlock(error);
    }];
}

- (void) rebootDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Reboot" request:@"reboot" finishAction:finishBlock];
}

- (void) shutdownDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Shutdown" request:@"shutdown" finishAction:finishBlock];
}

- (void) powercycleDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Power Cycle" request:@"power_cycle" finishAction:finishBlock];
}

- (void) powerOffDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Power Off" request:@"power_off" finishAction:finishBlock];
}

- (void) powerOnDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Power On" request:@"power_on" finishAction:finishBlock];
}

- (void) destroyDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock {
    [self dropletAction:droplet verb:@"Destroy" request:@"destroy" finishAction:finishBlock];
}

- (void) dropletAction:(BTOceanDataDroplet*)droplet verb:(NSString*)verb request:(NSString*)request finishAction:(BTOceanDataAction)finishBlock {
    NSString *shutdownPath = $p(@"%@/droplets/%@/%@/%@", DIGITALOCEAN_BASE_URL, droplet.identifier, request, [self authURLString]);
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:shutdownPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self postNotification:NSLocalizedString(@"Success", @"notification for droplet aciton")
                      subtitle:$p(NSLocalizedString(@"Droplet '%@' action successful: %@", @"Notification for droplet action"),
                                  droplet.name, verb)];
        finishBlock(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self postNotification:NSLocalizedString(@"Failure", @"notification title for failed droplet action")
                      subtitle:$p(NSLocalizedString(@"Droplet %@ failed at: %@", @"notification for failed droplet action"),
                                  droplet.name, verb)];
    }];
}

- (AFHTTPRequestOperation*) requestOperationFor:(NSString*)urlString
                    createClass:(NSString*)createClass
                    propertyKey:(NSString*)propertyKey
                   successBlock:(BTOceanDataAction)success
                      failBlock:(BTOceanDataError)failBlock {
    
    NSURL *URL = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    op.responseSerializer = [AFJSONResponseSerializer serializer];
    [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        // Never know what we get back in JSON
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            failBlock(errorFor(1, $p(@"Error: Data is '%@ class'", [responseObject className]), @"OceanData"));
            return;
        }
        
        if (![[(NSDictionary*)responseObject objectForKey:@"status"] isEqualToString:@"OK"]) {
            failBlock(errorFor(1, $p(@"Status not 'OK' for '%@'", propertyKey), @"OceanData"));
            return;
        }
        
        NSMutableDictionary *collector = [NSMutableDictionary dictionary];
        for (NSDictionary *aDictionary in responseObject[propertyKey]) {
            BTOceanDataItem *item = [[NSClassFromString(createClass) alloc] initWithDictionary:aDictionary];
            
            [collector setObject:item forKey:item.identifier];
        }
        
        success(collector.copy);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failBlock(error);
    }];
    
    return op;
}

- (void) postNotification:(NSString*)title subtitle:(NSString*)subtitle {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"postNotificationCenter"]) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = title;
        notification.subtitle = subtitle;
        [[NSUserNotificationCenter defaultUserNotificationCenter]
         scheduleNotification:notification];
    }
}

- (NSDictionary*) comparisonDictionary:(NSDictionary*)droplets {
    NSMutableDictionary *dx = @{}.mutableCopy;
    for (NSString* dropletID in [droplets allKeys]) {
        BTOceanDataDroplet *droplet = [droplets objectForKey:dropletID];
        dx[droplet.identifier] = @(droplet.isActive);
    }
    return dx.copy;
}

@end
