//
//  ProgressPanel.m
//  FeatureViewer
//
//  Created by Grogee on 10/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ProgressPanel.h"


@implementation ProgressPanel

-(void)startProgressIndicator
{
    [progressIndicator startAnimation:self];
}

-(void)stopProgressIndicator
{
    [progressIndicator stopAnimation:self];
    [self orderOut:self];
}
@end
