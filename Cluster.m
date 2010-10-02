//
//  Cluster.m
//  FeatureViewer
//
//  Created by Grogee on 9/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Cluster.h"


@implementation Cluster

@synthesize name;
@synthesize points;
@synthesize active;
@synthesize npoints;
@synthesize color;
@synthesize indices;
@synthesize valid;
@synthesize parents;
@synthesize clusterId;
@synthesize textColor;

-(void)setActive:(NSInteger)value
{
    active = value;
    //when cluster is set to active, notify the FeatureView to update the colouring.
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"ClusterStateChanged" object:self];
}

-(NSInteger)active
{
    return active;
}

-(void)makeInactive
{
    [self setActive:0];
}

-(void)makeActive
{
    [self setActive:1];
}

-(void)makeInvalid
{
    [self setValid: 0];
}
-(void)makeValid
{
    [self setValid:1];
}

-(NSIndexSet*)indices
{
    return indices;
}

-(void)setColor:(NSData*)new_color
{
    color = [[NSData dataWithData:new_color] retain];
    float *buffer = (float*)[color bytes];
    textColor = [[NSColor colorWithCalibratedRed:buffer[0] green:buffer[1] blue:buffer[2] alpha:1.0] retain];
}

-(NSData*)color
{
    return color;
}

-(void) dealloc
{
    [name release];
    [points release];
    [npoints release];
   // [active release];
    [indices release];
    [clusterId release];
    [parents release];
    [color release];
    [textColor release];
    [super dealloc];
}
@end
