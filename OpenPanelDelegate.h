//
//  OpenPanelDelegate.h
//  FeatureViewer
//
//  Created by Grogee on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OpenPanelDelegate : NSObject <NSOpenSavePanelDelegate>{

    NSString *basePath;
    NSString *extension;
}
@property(retain,readwrite) NSString *basePath;
@property(retain,readwrite) NSString *extension;

@end
