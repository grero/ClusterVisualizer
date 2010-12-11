//
//  FeatureViewerAppDelegate.h
//  FeatureViewer
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FeatureView.h"
#import "FeatureViewerController.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface FeatureViewerAppDelegate: NSObject
#else
@interface FeatureViewerAppDelegate : NSObject <NSApplicationDelegate> 
#endif
{
    NSWindow *window;
    IBOutlet FeatureViewerController *controller;
}


@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet FeatureViewerController *controller;

@end
