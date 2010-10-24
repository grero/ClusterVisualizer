//
//  FeatureViewerAppDelegate.h
//  FeatureViewer
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FeatureView.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface FeatureViewerAppDelegate: NSObject
#else
@interface FeatureViewerAppDelegate : NSObject <NSApplicationDelegate> 
#endif
{
    NSWindow *window;
}


@property (assign) IBOutlet NSWindow *window;

@end
