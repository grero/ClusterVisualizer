//
//  StimInfo.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 13/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "StimInfo.h"

@implementation StimInfo

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)readFromFile:(NSString*)fname
{
    //check that file exists
    if( [[NSFileManager defaultManager] fileExistsAtPath: fname] )
    {
        data = [[NSMutableDictionary dictionary] retain];
        //get lines
        NSArray *lines = [[NSString stringWithContentsOfFile: fname] componentsSeparatedByString: @"\n"];
        //lines = [lines filterArr
        
        NSEnumerator *linesEnumerator = [lines objectEnumerator];
        NSString *line = [linesEnumerator nextObject];
        NSDictionary *currentDict;
        
        while( line )
        {
            if( [line isEqualToString: @""] ==NO)
            {
                NSArray *keysAndObjects = [line componentsSeparatedByString: @"="];
                if([keysAndObjects count] > 1 )
                {
                    [currentDict addObject: [keysAndObjects objectAtIndex:1] forKey: [keysAndObjects objectAtIndex:0]]; 
                }
                else if ([keysAndObjects count] ==1 )
                {
                    NSString *keyName = [keysAndObjects objectAtIndex:0];
                    NSRange _r1 = [keyName rangeOfString: @"["];
                    NSRange _r2 = [keyName rangeOfString: @"]"];
                    keyName = [[keyName substringWithRange: NSMakeRange(_r1.location+1,_r2.location-_r1.location-1)] capitalizedString];
                    
                    [data addObject: [NSMutableDictionary dictionary] forKey: keyName];
                    currentDict = [data objectForKey: keyName];
                }
            }
            line = [linesEnumerator nextObject];
            
        }
    }
}

@end
