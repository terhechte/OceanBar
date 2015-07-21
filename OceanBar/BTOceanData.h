//
//  BTOceanData.h
//  OceanBar
//
//  Created by Benedikt Terhechte on 28/04/14.
//  Copyright (c) 2014 Benedikt Terhechte. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^BTOceanDataAction)(id results);
typedef void (^BTOceanDataError)(NSError *error);

//-----------------------------------------------------------------------------
#pragma mark Types
//-----------------------------------------------------------------------------
// Lightweight interfaces-types around the few properties
// that the items contain

@interface BTOceanDataItem : NSObject
- (id) initWithDictionary:(NSDictionary *)otherDictionary;
- (id) objectForKeyedSubscript:(id <NSCopying>)key;
- (NSNumber*) identifier;
- (NSString*) name;
- (NSString*) slug;
@end

@interface BTOceanDataImage : BTOceanDataItem
- (NSString*) distribution;
@end

@interface BTOceanDataSize : BTOceanDataItem
- (NSNumber*) memory;
- (NSNumber*) disk;
- (NSNumber*) cpu;
- (NSNumber*) costPerHour;
- (NSNumber*) costPerMonth;
@end

@interface BTOceanDataRegion : BTOceanDataItem
@end

@interface BTOceanDataDroplet : BTOceanDataItem
@property (retain) BTOceanDataSize *size;
@property (retain) BTOceanDataRegion *region;
@property (retain) BTOceanDataImage *image;
- (bool) isActive;
- (bool) backupsActive;
- (NSString*) publicIpAddresses;
- (NSString*) privateIpAddresses;
- (NSString*) ipAddress;
- (NSString*) privateIpAddress;
- (NSString*) kernelName;
- (NSString*) features;
- (bool) locked;
- (NSString*) status;
- (NSDate*) createdAt;
@end

@interface BTOceanData : NSObject
@property (weak) id delegate;
- (BTOceanDataDroplet*) dropletForID:(NSNumber*)dropletId;
- (void) loadDropletsWithSuccess:(BTOceanDataAction)actionBlock failure:(BTOceanDataError)errorBlock;
- (void) shutdownDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
- (void) rebootDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
- (void) powercycleDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
- (void) powerOffDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
- (void) powerOnDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
- (void) destroyDroplet:(BTOceanDataDroplet*)droplet finishAction:(BTOceanDataAction)finishBlock;
@end

@protocol BTOceanDataDelegate <NSObject>
- (void) oceanData:(BTOceanData*)data didFindChangedStateForDroplets:(NSArray*)droplets;
@end

