//
//  OpenPanelDelegate.m
//  FeatureViewer
//
//  Created by Grogee on 10/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "OpenPanelDelegate.h"


@implementation OpenPanelDelegate

@synthesize basePath;
@synthesize extension;
@synthesize extensions;

-(BOOL)panel:(id)sender shouldEnableURL: (NSURL*)url
{
    NSString *path = [url path];
    NSArray *fileComps = [[path lastPathComponent] componentsSeparatedByString:@"."]; 
	if( basePath != NULL )
	{
		NSRange range = [path rangeOfString:basePath];
		if( range.location == NSNotFound)
		{
			return NO;
		}
	}
    if( [fileComps count] > 1)
    {
        //next compare the second last path component to see if its a cluster
        //if ([[fileComps objectAtIndex:1 /*[fileComps count]-2]*/] isEqualToString:extension]) 
		if( ([extensions containsObject: [fileComps objectAtIndex:1]] ) || ([extensions containsObject: [fileComps lastObject]]))
        {
            return YES;
        }
        else
        {
            return NO;
        }
    }
    else
        return NO;

}

@end
