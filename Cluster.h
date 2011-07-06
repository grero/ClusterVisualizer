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
    NSMutableData *points;
    NSNumber *npoints;
    NSInteger active;
    NSInteger isTemplate;
    NSData *color;
    NSMutableIndexSet *indices;
    NSInteger valid;
    NSMutableArray *parents;
    NSColor *textColor;
    NSNumber *shortISIs;
    NSData *mean,*cov,*covi;
    NSNumber *lRatio,*isolationDistance;
    NSData *ISIs;
    NSData *isiIdx;
	NSData *featureRanges;
    NSMutableData *mask;
    NSImage *waveformsImage;
	NSInteger featureDims;
    

}

@property(retain,readwrite) NSString *name;
@property(retain,readwrite) NSMutableData *points;
@property(assign, readwrite) NSInteger active;
@property(assign,readwrite) NSInteger isTemplate;
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
@property(retain,readwrite) NSData *isiIdx;
@property(retain,readwrite) NSMutableData *mask;
@property(retain,readwrite) NSImage *waveformsImage;
@property(retain,readwrite) NSData *featureRanges;
@property(assign,readwrite) NSInteger featureDims;

-(void)createName;
-(void)makeInactive;
-(void)makeActive;
-(void) makeTemplate;
-(void) undoTemplate;

-(void)makeInvalid;
-(void)makeValid;
-(void)computeFeatureMean:(NSData*)data;
-(void)computeISIs:(NSData*)timestamps;
-(void)computeLRatio:(NSData*)data;
-(void)computeIsolationDistance:(NSData*)data;
-(NSDictionary*)computeXCorr:(Cluster*)cluster timepoints:(NSData*)timepts;
-(void)computeFeatureRanges:(NSData*)data;
-(void)removePoints:(NSData*)rpoints;
-(void)addPoints:(NSData*)rpoints;

//encoding
-(void)encodeWithCoder:(NSCoder*)coder;
-(id)initWithCoder:(NSCoder*)coder;
@end
