//
//  StimInfo.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 13/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StimInfo : NSObject{
    
    NSMutableDictionary *data;
    NSDictionary *descriptor;
    NSData *syncs,*framepts,*repBoundaries;
    NSString *sessionName, *sessionPath;
    NSUInteger nframes, framesPerRep,nreps;
}

-(void)readFromFile:(NSString*)fname;
-(void)readMonitorSyncs;
-(void)readDescriptor;
-(void)getFramePoints;
-(void)getTriggerSignalWithThreshold:(float)threshold;

@property (retain,readwrite) NSDictionary *descriptor;
@property (retain,readwrite) NSData *framepts;
@property (retain,readwrite) NSData *repBoundaries;
@property (assign,readwrite) NSUInteger nframes;
@property (assign,readwrite) NSUInteger framesPerRep;
@property (assign,readwrite) NSUInteger nreps;
@end
