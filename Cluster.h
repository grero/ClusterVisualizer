//
//  Cluster.h
//  FeatureViewer
//
//  Created by Grogee on 9/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>
#import "utils.h"

@interface Cluster : NSObject {
    
    NSString *name;
    NSNumber *clusterId;
    NSData *points;
    NSNumber *npoints;
    NSInteger active;
    NSData *color;
    NSMutableIndexSet *indices;
    NSInteger valid;
    NSMutableArray *parents;
    NSColor *textColor;
    NSNumber *shortISIs;
    NSData *mean,*cov,*covi;
    NSNumber *lRatio,*isolationDistance;
    

}

@property(retain,readwrite) NSString *name;
@property(retain,readwrite) NSData *points;
@property(assign, readwrite) NSInteger active;
@property(retain,readwrite) NSNumber *npoints;
@property(retain,readwrite) NSMutableIndexSet *indices;
@property(retain,readwrite) NSData *color;
@property(assign,readwrite) NSInteger valid;
@property(retain,readwrite) NSMutableArray *parents;
@property(retain,readwrite) NSNumber *clusterId;
@property(retain,readwrite) NSColor *textColor;
@property(retain,readwrite) NSNumber *shortISIs;
@property(retain,readwrite) NSData *mean;
@property(retain,readwrite) NSData *cov;
@property(retain,readwrite) NSData *covi;
@property(retain,readwrite) NSNumber *lRatio;
@property(retain,readwrite) NSNumber *isolationDistance;

-(void)makeInactive;
-(void)makeActive;

-(void)makeInvalid;
-(void)makeValid;
-(void)computeISIs:(NSData*)timestamps;
-(void)computeLRatio:(NSData*)data;
-(void)computeIsolationDistance:(NSData*)data;
@end
