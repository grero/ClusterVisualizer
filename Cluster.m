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
//@synthesize active;
@synthesize npoints;
@synthesize color;
@synthesize indices;

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

-(NSIndexSet*)indices
{
    return indices;
}

-(void) dealloc
{
    [name release];
    [points release];
    [npoints release];
    [active release];
    [indices release];
    [super dealloc];
}
@end
