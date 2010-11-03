//
//  OpenPanelDelegate.h
//  FeatureViewer
//
//  Created by Grogee on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@interface OpenPanelDelegate : NSObject
#else
@interface OpenPanelDelegate : NSObject <NSOpenSavePanelDelegate>
#endif

{

    NSString *basePath;
    NSString *extension;
    NSArray *extensions;
}
@property(retain,readwrite) NSString *basePath;
@property(retain,readwrite) NSString *extension;
@property(retain,readwrite) NSArray *extensions;

@end
