//
//  FeatureViewerAppDelegate.h
//  FeatureViewer
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FeatureView.h"

@interface FeatureViewerAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}


@property (assign) IBOutlet NSWindow *window;

@end
