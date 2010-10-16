//
//  ProgressPanel.h
//  FeatureViewer
//
//  Created by Grogee on 10/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ProgressPanel : NSPanel {

    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *title;
}

-(void)startProgressIndicator;
-(void)stopProgressIndicator;

@end
