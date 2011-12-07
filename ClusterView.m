//
//  ClusterView.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 3/12/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "ClusterView.h"

@implementation ClusterView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(BOOL)acceptsFirstResponder
{
    return YES;
}

-(void)rightMouseDown:(NSEvent *)theEvent
{
    NSMenu *theMenu = [[[NSMenu alloc] initWithTitle:@"Contextual Menu"] autorelease];
    [theMenu insertItemWithTitle:@"Beep" action:@selector(beep:) keyEquivalent:@"" atIndex:0];
    [theMenu insertItemWithTitle:@"Honk" action:@selector(honk:) keyEquivalent:@"" atIndex:1];
    
    [NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:self];}

@end
