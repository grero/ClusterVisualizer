//
//  TimeSliderController.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 20/7/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface TimeSliderController : NSController
{
    IBOutlet NSSlider *timeSlider;
    IBOutlet NSTextField *timeWindow;
    NSNumber *currentSliderValue,*timeWindowSize;
    NSString *stringWindowSize;
}

@property (assign) IBOutlet NSSlider *timeSlider;
@property (assign) IBOutlet NSTextField *timeWindow;
@property (retain,readwrite) NSNumber *currentSliderValue;
@property (retain,readwrite) NSNumber *timeWindowSize;
@property (retain,readwrite) NSString *stringWindowSize;

-(IBAction)moveSlider:(id)sender;
-(IBAction)showSliderPanel:(id)sender;
-(IBAction)closePanel:(id)sender;
@end
