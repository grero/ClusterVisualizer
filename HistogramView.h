//
//  HistogramView.h
//  FeatureViewer
//
//  Created by Grogee on 1/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HistogramView : NSView {

    NSBezierPath *axisFrame,*bars;
    
}

- (void) drawHistogram:(NSData*)counts andBins: (NSData*)bins;
@end
