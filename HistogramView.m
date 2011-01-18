//
//  HistogramView.m
//  FeatureViewer
//
//  Created by Grogee on 1/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HistogramView.h"


@implementation HistogramView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        axisFrame = NULL;
        bars = NULL;
        
    }
    return self;
}

- (void) drawHistogram:(NSData*)counts andBins: (NSData*)bins
{
    //draw a histogram based on the counts and bins; basically, draw rectangles of width equal to the bin widths
    //and height equal to the count
    //NSGraphicsContext* theContext = [NSGraphicsContext currentContext];
    unsigned int _ncounts = [counts length]/sizeof(unsigned int);
    unsigned int *_counts = (unsigned int*)[counts bytes];
    double *_bins = (double*)[bins bytes];
    unsigned int i;
    //first draw the axis
    CGFloat maxCount = 0.0;
    
    //[frame stroke];
    bars = [[NSBezierPath bezierPath] retain];
    for(i=0;i<_ncounts-1;i++)
    {
        if( _counts[i]<maxCount )
        {
            maxCount = _counts[i];
        }
        [bars appendBezierPathWithRect:NSMakeRect(_bins[i]/_bins[_ncounts-1], 0.0, (_bins[i+1]-_bins[i])/_bins[_ncounts-1], _counts[i])];
        
    }
    NSAffineTransform *transform = [NSAffineTransform transform];
    //scale such that maximum y is one
    [transform scaleXBy:1.0 yBy:0.9/maxCount];
    
    [bars transformUsingAffineTransform: transform];
    axisFrame = [[NSBezierPath bezierPath] retain];
    [axisFrame moveToPoint:NSMakePoint(0.0, 0.0)];
    [axisFrame lineToPoint:NSMakePoint(0.0, 1.0)];
    [axisFrame moveToPoint:NSMakePoint(0.0, 0.0)];
    [axisFrame lineToPoint:NSMakePoint(1.0, 0.0)];
    
    //[bars fill];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
    NSAffineTransform *transform = [NSAffineTransform transform];
    //scale to window size
    [transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
    
    if( axisFrame != NULL )
    {
        [axisFrame transformUsingAffineTransform:transform];
        [axisFrame stroke];
        [axisFrame transformUsingAffineTransform:transform];

    }
    if( bars != NULL )
    {
        [bars transformUsingAffineTransform:transform];
        [bars fill];
        [bars transformUsingAffineTransform: transform];
    }
    [transform invert];
    if( axisFrame != NULL)
        [axisFrame transformUsingAffineTransform:transform];
    if( bars != NULL)
        [bars transformUsingAffineTransform:transform];
    //reset for next drawing; could be slow
    
}

@end
