//
//  TimeSliderController.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 20/7/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "TimeSliderController.h"

@implementation TimeSliderController

@synthesize timeSlider,timeWindow,timeWindowSize;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)setCurrentSliderValue:(NSNumber *)_currentSliderValue
{
    float currentValue,windowSize,tickSize;
    currentValue = [_currentSliderValue floatValue];
	if(currentValue != [[self currentSliderValue] floatValue])
	{
		windowSize = [[self timeWindow] floatValue];
		//get the current position of the slider
		//create a UserInfo dictionary to send with the notification
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:currentValue], @"startTime", [NSNumber numberWithFloat:windowSize],@"windowSize" ,nil ];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AdvanceTime" object:self userInfo:userInfo];
		currentSliderValue=[[NSNumber numberWithFloat:currentValue] retain];
	}

}

-(NSNumber*)currentSliderValue
{
    return currentSliderValue;
}

-(void)setStringWindowSize:(NSString *)_timeWindowSize
{
    float windowSize,minVal,maxVal,npoints,d;
    windowSize = [_timeWindowSize floatValue];
    minVal = [[self timeSlider] minValue];
    maxVal = [[self timeSlider] maxValue];
    npoints = [[self timeSlider] numberOfTickMarks];
    
    d = (npoints*([[self timeWindowSize] floatValue]))/windowSize;
    [[self timeSlider] setNumberOfTickMarks:d];    
    [self setTimeWindowSize:[NSNumber numberWithFloat:windowSize]]; 
    stringWindowSize = [[NSString stringWithString:_timeWindowSize] retain];
}

-(NSString*)stringWindowSize
{
    return stringWindowSize;
}


-(IBAction)moveSlider:(id)sender
{
    float currentValue,windowSize,tickSize;
    windowSize = [[self timeWindow] floatValue];
    //get the current position of the slider
    currentValue = [sender floatValue];
    //create a UserInfo dictionary to send with the notification
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"starTime", [NSNumber numberWithFloat:currentValue], @"windowSize", [NSNumber numberWithFloat:windowSize],nil ];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AdvanceTime" object:self userInfo:userInfo];
}

-(IBAction)showSliderPanel:(id)sender
{
    float minVal,maxVal,numPoints,d,windowSize;
    minVal = [[NSUserDefaults standardUserDefaults] floatForKey:@"minTime"];
    maxVal = [[NSUserDefaults standardUserDefaults] floatForKey:@"maxTime"];
    numPoints = [[NSUserDefaults standardUserDefaults] floatForKey:@"numPoints"];
    if([sender state] == NSOffState)
    {
        //set up the slider using values from NSUserDefaults
        
        //window size of 1 s
        windowSize = [[self timeWindowSize] floatValue];
        if( windowSize <= 0 )
            windowSize = 1000;
        
        [self setTimeWindowSize: [NSNumber numberWithFloat:windowSize]];
        [self setStringWindowSize:[NSString stringWithFormat:@"%f", windowSize]];
        
        if(minVal == maxVal)
        {
            maxVal = minVal+1;
            numPoints = 1;
        }
        d = ((maxVal-minVal))/windowSize;
        [timeSlider setMinValue: minVal];
        [timeSlider setMaxValue: maxVal];
        [timeSlider setNumberOfTickMarks:d];

        [[[self timeWindow] window] makeKeyAndOrderFront:self];
        [sender setState:NSOnState];
    }
    else
    {
        [[[self timeWindow] window] orderOut:self];
        [sender setState:NSOffState];
        //send a notification to reset the view
         NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:minVal], @"startTime", [NSNumber numberWithFloat:maxVal-minVal],@"windowSize" ,nil ];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AdvanceTime" object:self userInfo:userInfo];
    }
}

-(IBAction)closePanel:(id)sender
{
    //toggle the state of the menu item
    [[[NSApp mainMenu] itemWithTitle:@"Time slider"] setState:NSOffState];
    [sender orderOut:self];
}


@end
