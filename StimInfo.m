//
//  StimInfo.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 13/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "StimInfo.h"

@implementation StimInfo

@synthesize descriptor;
@synthesize framepts,repBoundaries;
@synthesize nframes,framesPerRep,nreps;

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
        sessionPath = [[fname stringByDeletingLastPathComponent] retain];
        sessionName = [[[fname lastPathComponent] stringByDeletingPathExtension] retain];
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

-(void)readMonitorSyncs
{
    NSString *fname = [sessionPath stringByAppendingPathComponent: [sessionName stringByAppendingPathExtension: @"snc"]];
    if( [[NSFileManager defaultManager] fileExistsAtPath: fname] )
    {
        //read data
        NSData *_data = [NSData dataWithContentsOfFile: fname];
        unsigned int offset = 0;
        //read the header
        unsigned int headersize, records;
        double meanF,stdF;
        char dname[260];
        [_data getBytes: &headersize range: NSMakeRange(offset,4)];
        offset+=4;
        [_data getBytes: dname range: NSMakeRange(offset,260)];
        offset+=260;
        [_data getBytes: &records range: NSMakeRange(offset,4)];
        offset+=4;
        [_data getBytes: &meanF range: NSMakeRange(offset,8)];
        offset+=8;
        [_data getBytes: &stdF   range: NSMakeRange(offset,8)];
        offset+=8;
        syncs = [[_data subdataWithRange: NSMakeRange(headersize,[_data length]-headersize)] retain];
        
        
    }
}

-(void)readDescriptor
{
    NSString *contents = [NSString stringWithContentsOfFile: [sessionPath stringByAppendingPathComponent: [sessionName stringByAppendingString: @"_descriptor.txt"]]];
    NSArray *lines = [contents componentsSeparatedByString: @"\n"];
    NSEnumerator *linesEnumerator = [lines objectEnumerator];
    //Skip the first line

    NSString *line = [linesEnumerator nextObject];
    line = [linesEnumerator nextObject];
    NSUInteger channels = [[[line componentsSeparatedByString:@" "] lastObject] intValue];
    line = [linesEnumerator nextObject];
    double sampling_rate = [[[line componentsSeparatedByString:@" "] lastObject] doubleValue];
    //skip one line
    line = [linesEnumerator nextObject];
    line = [linesEnumerator nextObject];
    double gain = [[[line componentsSeparatedByString:@" "] lastObject] doubleValue];
    //skip one line
    line = [linesEnumerator nextObject];
    line = [linesEnumerator nextObject];
    //iterate throgh lines
    NSMutableArray *chNr = [NSMutableArray arrayWithCapacity: 100];
    NSMutableArray *grNr = [NSMutableArray arrayWithCapacity: 100];
    NSMutableArray *status = [NSMutableArray arrayWithCapacity:100];
    NSMutableArray *type = [NSMutableArray arrayWithCapacity:100];
    while( line )
    {
        NSArray *parts = [line componentsSeparatedByString:@ " "];
        int nparts = [parts count];
        [chNr addObject: [NSNumber numberWithInt:[[parts objectAtIndex:0] intValue]]];
        [grNr addObject: [NSNumber numberWithInt: [[parts objectAtIndex: nparts-2] intValue]]];
        [type addObject: [parts objectAtIndex:1]];
        [status addObject: [NSNumber numberWithBool: [[[parts lastObject] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]] isEqualToString: @"Active"]]];
        line = [linesEnumerator nextObject];

         
    }
    [self setDescriptor: [NSDictionary dictionaryWithObjectsAndKeys: chNr, @"channelNumber", grNr, @"groupNumber",status,@"status",type,@"type",[NSNumber numberWithInt:channels],@"numChannels", [NSNumber numberWithFloat:sampling_rate], @"samplingRate",[NSNumber numberWithFloat: gain],@"gain",nil]];
    
    
}

-(void)getFramePoints
{
    if([self descriptor] == NULL)
    {
        [self readDescriptor];
    }
    if( syncs == NULL )
    {
        [self readMonitorSyncs];
    }
    //compute the frame points by finding the number of syncs per frame
    int syncs_per_frame = [[[data objectForKey:@"Treversecorrguiform"] objectForKey:@"Refreshes Per Frame"] intValue];
    double sr = [[[self descriptor] objectForKey:@"samplingRate"] doubleValue];
    uint32_t *_syncs = (uint32_t*)[syncs bytes];
    unsigned int _nsyncs = [syncs length]/sizeof(uint32_t);
    unsigned int _nframes = floor(_nsyncs/syncs_per_frame);
    double *_framepts = malloc(floor(_nsyncs/syncs_per_frame)*sizeof(double));
    unsigned int i,j;
    j = 0;
    for(i=0;i<_nsyncs;i+=syncs_per_frame)
    {
        //we want framepts in ms
        _framepts[j] = (double)_syncs[i]/sr*1000.0;
        j+=1;
    }
    [self setNreps: [[[data objectForKey: @"Treversecorrguiform"] objectForKey:@"Number Of Repeats"] intValue]] ;
    int _nreps = [self nreps];
    int _framesPerRep = _nframes/_nreps;
    double *_repBoundaries = malloc(_nreps*sizeof(double));
    for(i=0;i<_nreps;i++)
    {
        _repBoundaries[i] = _framepts[i*_framesPerRep];
    }
    [self setFramesPerRep:_framesPerRep];
    [self setFramepts:[NSData dataWithBytes:_framepts length:_nframes*sizeof(double)]];
    [self setNframes:_nframes];
    [self setRepBoundaries:[NSData dataWithBytes:_repBoundaries length:_nreps*sizeof(double)]];
    //since the bytes have been copied, we can free the original location
    free(_framepts);
    free(_repBoundaries);
    
}

-(void)getTriggerSignalWithThreshold:(float)threshold
{
    //make sure we have the descriptor first
    if( descriptor == NULL )
    {
        [self readDescriptor];
    }
    //memory map the file
    NSData *_data = [NSData dataWithContentsOfMappedFile: [sessionPath stringByAppendingPathComponent: [sessionName stringByAppendingPathExtension: @"bin"]]];
    int triggerChannel = [[[self descriptor] objectForKey: @"type"] indexOfObject: @"presenter"];
    int numChannels = [[[self descriptor] objectForKey:@"numChannels"] intValue];
    //to get the data for the trigger channel
    int headersize;
    //get the header size
    [_data getBytes: &headersize range: NSMakeRange(0,4)];
    //get the number of bytes per channel
    unsigned int pointsPerCh = ((unsigned int)[_data length]-headersize)/2/numChannels;
    unsigned int *triggerPoints = malloc(pointsPerCh*sizeof(unsigned int));
    unsigned int ntriggers = 0;
    int i,j,previ;
    j = 0;
    previ =0;
    int16_t buf;
    //since we are doing this in a loop anyway, we can just detected the crossings directly
    for(i=0;i<pointsPerCh;i++)
    {
        //for each datapoint we want to read, we have to 
        [_data getBytes: &buf range:NSMakeRange(headersize+2*(i*numChannels + triggerChannel),2)];
        //only detect if it is the first crossing
        if( (float)buf >= threshold )
        {
            if(i-previ  > 1 )
            {
                //we have a crossing
                triggerPoints[j] = i;
                j+=1;
            }
            previ = i;
            
        }
    }
    ntriggers = j;
    
    
    
    
}

@end
