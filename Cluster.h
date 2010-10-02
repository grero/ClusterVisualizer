//
//  Cluster.h
//  FeatureViewer
//
//  Created by Grogee on 9/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


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
-(void)makeInactive;
-(void)makeActive;

-(void)makeInvalid;
-(void)makeValid;
@end
