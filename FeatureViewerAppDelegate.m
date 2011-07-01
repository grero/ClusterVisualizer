//
//  FeatureViewerAppDelegate.m
//  FeatureViewer
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FeatureViewerAppDelegate.h"

@implementation FeatureViewerAppDelegate

@synthesize window;
@synthesize controller;



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	[NSBundle loadNibNamed: @"RasterWindow" owner: controller];
}

- (void)application:(NSApplication*)theApplication openFiles:(NSArray*)filenames
{

	[self application: theApplication openFile:[filenames objectAtIndex:0]];
	
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    //check the extension of the file to determine how to open it
    if( [[filename pathExtension] isEqualToString:@"bin"] )
    {
        //open waveforms.bin file
        [controller openWaveformsFile:filename];
        return YES;
    }
    else if( [[filename pathExtension] isEqualToString:@"fd"] )
    {
        //open feature file
        [controller openFeatureFile:filename];
        return YES;
    }
    else if( [[filename pathExtension] isEqualToString:@"fv"] )
    {
        [controller openClusterFile:filename];
        return YES;
    }
	else if( [[filename pathExtension] isEqualToString:@"cut"] )
    {
        [controller openClusterFile:filename];
        return YES;
    }
    else if( [[filename componentsSeparatedByString:@"."] containsObject:@"clu"] )
    {
        [controller openClusterFile:filename];
        return YES;
    }
	else if( [[filename componentsSeparatedByString:@"."] containsObject:@"overlap"] )
    {
        [controller openClusterFile:filename];
        return YES;
    }
	else if( [[filename componentsSeparatedByString:@"."] containsObject:@"fet"] )
	{
		//NSLog(@"filename: %@",filename);
		[controller openFeatureFile:filename];
		return YES;
	}
    else{
        //File not recognized, so return FALSE to indicate we could not open the file
        return NO;
    }
}
@end
