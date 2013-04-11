//
//  FeatureViewerController.m
//
//  Created by Grogee on 9/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FeatureViewerController.h"

@implementation FeatureViewerController

@synthesize fw;
@synthesize wfv;
@synthesize dim1;
@synthesize dim2;
@synthesize dim3;
@synthesize Clusters;
@synthesize ClusterOptions;
@synthesize isValidCluster;
//@synthesize filterClustersPredicate;
@synthesize clustersSortDescriptor;
@synthesize clustersSortDescriptors;
@synthesize waveformsFile,currentDir,logFilePath,lastOperation,currentBaseName;
@synthesize activeCluster,selectedCluster;
//@synthesize selectedClusters;
//@synthesize selectedWaveform;
@synthesize featureCycleInterval;
@synthesize releasenotes;
@synthesize rasterView;
@synthesize histView;
@synthesize stimInfo;
@synthesize clusterMenu,waveformsMenu,clusterNotesPanel;
@synthesize descriptor;

-(void)awakeFromNib
{
    //[self setClusters:[NSMutableArray array]];
    dataloaded = NO;
    queue = [[[NSOperationQueue alloc] init] retain];
	//currentBaseName = NULL;
	timestamps = NULL;
    //[self setFilterClustersPredicate:[NSPredicate predicateWithFormat: @"SELF.valid==YES"]];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"showInput" object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"hideAllClusters" object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"highlight" object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"loadLargeWaveforms" object: nil];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"performClusterOption" object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:NSUserDefaultsDidChangeNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"AdvanceTime" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"loadWaveforms" object:nil];
	//load the nibs
	//setup defaults
	/*NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSNumber *fci = [defaults objectForKey:@"featureCycleInterval"];
	if(fci == nil )
	{
		//no default value was found; use 0.5
		[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:0.5], @"featureCycleInterval",nil]];
		
	}*/
	//[self setFeatureCycleInterval:[defaults objectForKey:@"featureCycleInterval"]];
	[self setFeatureCycleInterval:[NSNumber numberWithFloat:0.5]];
	//load the releasenotes
	NSString *rn = [[NSBundle mainBundle] pathForResource:@"release_notes" ofType: @"rtf"];
	NSAttributedString *reln = [[[NSAttributedString alloc] initWithPath:rn documentAttributes:NULL] autorelease];
	[self setReleasenotes: reln];
	
	//set up predicates for filter
	NSPredicateEditorRowTemplate *row = [[[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions: [NSArray arrayWithObjects:[NSExpression expressionForKeyPath:@"valid"],[NSExpression expressionForKeyPath: @"active"],nil] rightExpressions:
										  [NSArray arrayWithObjects:[NSExpression expressionForConstantValue: [NSNumber numberWithInt:1]],[NSExpression expressionForConstantValue:[NSNumber numberWithInt:1]],nil] modifier: NSDirectPredicateModifier operators:
										  [NSArray arrayWithObjects:[NSNumber numberWithInt: NSEqualToPredicateOperatorType],[NSNumber numberWithInt: NSEqualToPredicateOperatorType],nil] options:
										 NSCaseInsensitivePredicateOption] autorelease];
										 
									
																					
	//[filterPredicates setRowTemplates: [NSArray arrayWithObjects:row,row,nil]];
    [self setFilterClustersPredicate:[NSPredicate predicateWithFormat: @"SELF.valid==YES AND SELF.active==YES"]];
	//filterClustersPredicate = [[NSPredicate predicateWithFormat: @"SELF.valid==YES AND SELF.active==YES"] retain];
	[clusterController setFilterPredicate: [self filterClustersPredicate]];
	[clusterController setClearsFilterPredicateOnInsertion: NO];
    
    //load the rasterview window
    
    
    //setup some usedefaults
    /*
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if( [defaults objectForKey:@"autoLoadWaveforms"] == nil )
    {
        [defaults setBool:YES forKey:@"autoLoadWaveforms"];
    }
    */
	clustersLoaded = NO;
    shouldShowRaster = NO;
    shouldShowWaveforms =YES;
    autoLoadWaveforms = YES;
    [selectClusterOption removeAllItems];
    //create the waveforms menu
    waveformsMenu = [[NSMenu alloc] init];
    [waveformsMenu addItemWithTitle:@"Find correlated waveforms" action:@selector(correlateWaveforms:) keyEquivalent:@""];
    [waveformsMenu addItemWithTitle:@"Find outlier waveforms" action:@selector(hideOutlierWaveforms:) keyEquivalent:@"a"];
    [waveformsMenu addItemWithTitle:@"Screen waveforms" action:@selector(screenWaveforms) keyEquivalent:@"c"];
	[waveformsMenu addItemWithTitle:@"Apply threshold" action:@selector(applyThreshold) keyEquivalent:@"t"];
    [[self wfv] setMenu:waveformsMenu];
    //disable autoenable
	//upate the cluster menu for the waveforsview
	//
    [[NSApp mainMenu] setAutoenablesItems:NO];
	NSLog(@"Finished laoding NIB");
    
}

-(BOOL) acceptsFirstResponder
{
    return YES;
}

-(IBAction) loadFeatureFile: (id)sender
{
    /*TODO: Make this a bit more generic; the only thing the user should have to select is the waveformsfile. Everything else
          can be derived from that. For this, we would need to get the contents of the directory, using NSFilemanager, then loop through
           each feature file to get both the data and the feature names
     */
     NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setDelegate:[[[OpenPanelDelegate alloc] init]autorelease]];
	[openPanel setTitle:@"Choose feature file to load"];
	[[openPanel delegate] setExtensions: [NSArray arrayWithObjects:@"fd",@"fet",nil]];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories: YES];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        //if we are loading a new dataset, remove everything about the old
        if(dataloaded == YES)
        {
            [dim1 removeAllItems];
            [dim2 removeAllItems];
            [dim3 removeAllItems];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];
            [[self fw] hideAllClusters];
            [self removeAllObjectsFromClusters];
            [[[self wfv]  window] orderOut:self];
            if(timestamps != NULL)
            {
                [timestamps release];
                timestamps = NULL;
            }
            
            [self setWaveformsFile:NULL];
            
            
        }
        NSString *path = [[openPanel URL] path];
        [self openFeatureFile: path];
		
        
    }
}
        
-(void) openFeatureFile:(NSString*)path
{
	NSAutoreleasePool *_pool;
	_pool = [[NSAutoreleasePool alloc] init];
	//if there is a timer running, we want to stop it, such that we don't overwrite the new clusters before they have had  chance to get loaded
	if ( archiveTimer != nil )
	{
		if( [archiveTimer isValid] )
		{
			[archiveTimer invalidate];
		}
	}

	//data object to hold the feature data
	NSString *directory = [path stringByDeletingLastPathComponent];
    [self setCurrentDir: directory];
	NSMutableData *data = [NSMutableData dataWithCapacity:100000*sizeof(float)];
	float *tmp_data,*tmp_data2;
	int cols=0;
	int rows = 0;
	int i,j,k;
	BOOL anyLoaded = NO;
	NSMutableArray *feature_names = [NSMutableArray arrayWithCapacity:16];
	NSString *filebase;
    tmp_data = NULL;
    tmp_data2 = NULL;
    //get the group; format: gXXXX
    //NSError *xerror = NULL;
    //NSString *group = [[NSRegularExpression regularExpressionWithPattern:@"(g[0-9]*)" options: NSRegularExpressionCaseInsensitive: error &xerror] firstMatchInString: path option: 0 range:NSMakeRange(0,[path length])];
	if( [[path pathExtension] isEqualToString:@"fd"])
	{
		NSArray *dir_contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: directory error: nil] pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",nil]];
		
		if( [dir_contents count] == 0)
		{
			return;
		}
		
		//geth the base path
		//TODO: This does not work if there are underscores in the file name
		//find the last occurrence of "_"
		NSRange range = [[path lastPathComponent] rangeOfString:@"_" options:NSBackwardsSearch];
		filebase = [[path lastPathComponent] substringToIndex:range.location]; 
		//currentBaseName = [[NSString stringWithString:filebase] retain];
		[self setCurrentBaseName: [NSString stringWithString:filebase]];
		NSLog(@"currentBaseName = %@", currentBaseName);
		//the the group
		range = [[path lastPathComponent] rangeOfString:@"waveforms"];
		currentGroup = [[[path lastPathComponent] substringWithRange: NSMakeRange(range.location-4,4)] retain];
		//attempt to locate the highpass file as well
		//set the current directory of the process to the the one pointed to by the load dialog
		[[NSFileManager defaultManager] changeCurrentDirectoryPath:directory];
		//get all feature files, i.e. files ending in .fd from the FD directory
		//NSArray *dir_contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"FD"] error: NULL] 
		 //                        pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",nil]];
		//get waveforms file
					
		NSEnumerator *enumerator = [dir_contents objectEnumerator];
		id file;
		header H;
        H.cols = 0;
		//float *tmp_data,*tmp_data2;
					
		//TODO: parallelize this
        [progressPanel setTitle: @"Loading features"];
        [progressPanel orderFront:self];
        
        [progressPanel startProgressIndicator];
		while(file = [enumerator nextObject] )
		{
			if(([file hasPrefix:filebase] )) //&& ([[file stringByDeletingPathExtension]))
			{
				//check if this file contains a valid feature
				if( [[file stringByDeletingPathExtension] isEqualToString:filebase] )
				{
					//skip
					continue;
				}
                NSString *fn = [[[[file lastPathComponent] componentsSeparatedByString:@"_"] lastObject] stringByDeletingPathExtension];
				//if feature name is valley and we are already using triggervalue, skip it
				if( [fn isEqualToString: @"valley"])
				{
					continue;
				}
                [progressPanel setTitle:[NSString stringWithFormat:@"Loading feature %@", fn]];
                
				const char *filename = [[NSString pathWithComponents: [NSArray arrayWithObjects: directory,file,nil]] cStringUsingEncoding:NSASCIIStringEncoding];
				H = *readFeatureHeader(filename, &H);
				tmp_data = malloc(H.rows*H.cols*sizeof(float));
				tmp_data2 = malloc(H.rows*H.cols*sizeof(float));
				//the feature file will in general have a channelValidity file; this tells me which channels were used
				float *_channelValidity = malloc(H.numChannels*sizeof(float));
				channelValidity = malloc(H.numChannels*sizeof(uint8_t));
				tmp_data = readFeatureData(filename, tmp_data,_channelValidity);
				//copy to the global channelValidity variable
				for(i=0;i<H.numChannels;i++)
				{
					channelValidity[i] = (uint8_t)_channelValidity[i];
				}
				nchannels = H.numChannels;
				nvalidChannels = H.rows;
				free(_channelValidity);
				if(tmp_data == NULL)
				{
					//create an alert
                    NSAlert *alert = [NSAlert alertWithMessageText:@"Feature file could not be loaded" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
					[alert runModal];
					free(tmp_data);
					free(tmp_data2);
					continue;
					
				}
				//transpose
				//this is kind of a hack; if we are loading spikewdiths, use absolute values
				if([fn compare: @"spikewidth" options: NSCaseInsensitiveSearch] == NSOrderedSame )
				{
					vDSP_vabs(tmp_data,1,tmp_data,1,H.rows*H.cols);
				}
				for(i=0;i<H.rows;i++)
				{ 
					for(j=0;j<H.cols;j++)
					{
						tmp_data2[j*H.rows+i] = tmp_data[i*H.cols+j];
					}
				}
					
				[data appendBytes:tmp_data2 length: H.rows*H.cols*sizeof(float)];
				free(tmp_data);
				free(tmp_data2);
				cols+=H.rows;
				//feature names
				//get basename
				 
				for(j=0;j<H.numChannels;j++)
				{
					if(channelValidity[j]==1)
					{
						[feature_names addObject: [fn stringByAppendingFormat:@"%d",j+1]];
					}

				}
				//notify that we have indeed loaded something
				anyLoaded = YES;
				
		}
		//scale individual features
			
			/*need to reshape the data
			tmp_data = malloc([data length]);
			float *tmp_data2 = [data bytes];
		   
			for(i=0;i<H.rows;i++)
			{ 
				for(j=0;j<tmp_cols;j++)
				{
					tmp_data[i*tmp_cols+j] = tmp_data_2[j%H.cols+]
				}
			}*/
			
			rows = H.cols;
		}
        [progressPanel stopProgressIndicator];
        [progressPanel orderOut:self];
		if( anyLoaded == NO)
		{
			return;
		}
		//need to reshape
		//tmp_data = NSZoneMalloc([self zone], rows*cols*sizeof(float));
		tmp_data = malloc((rows*(cols+1))*sizeof(float));
		tmp_data2 = (float*)[data bytes];
		for(i=0;i<rows;i++)
		{
			for(k=0;k<cols/H.rows;k++)
			{
				for(j=0;j<H.rows;j++)
				{
					tmp_data[i*(cols+1)+k*H.rows+j] = tmp_data2[k*rows*H.rows + i*H.rows+j];
				}
			}
			//scale time between -1 and 1
			tmp_data[i*(cols+1)+cols] = 2*((float)i)/rows-1;
		}
		//make space for time
		cols+=1;
		[feature_names addObject: [NSString stringWithFormat:@"Time"]];
		//free(temp_data);
	}
	
	else if([[[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:1] isEqualToString:@"fet"]) 
	{
		//the file is a .fet file; it will have all the features written in ascii format, one row per line
		//the first line contains the number of columns
		filebase = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
		//NSLog(@"LastComponent: %@",[path lastPathComponent]);
		currentBaseName = [[NSString stringWithString:filebase] retain];

		NSArray *lines = [[NSString stringWithContentsOfFile:path] componentsSeparatedByString:@"\n"];
		cols = [[lines objectAtIndex:0] intValue];
		//check if last line is empty
		if( [[lines lastObject] isEqualToString:@""] )
		{
			rows = [lines count]-2;
		}
		else
		{
			rows = [lines count]-1;
		}
        //make sure tmp_data is always located in the zone
		//tmp_data = NSZoneMalloc([self zone], rows*cols*sizeof(float));
		tmp_data = malloc(rows*cols*sizeof(float));
		int i,j;
		for(i=0;i<rows;i++)
		{
			NSScanner *tokens = [NSScanner scannerWithString: [lines objectAtIndex:i+1]];
			//skip all whitespace characters
			[tokens setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
			for(j=0;j<cols;j++)
			{
				[tokens scanFloat:tmp_data+i*cols+j];
			}
		}
        
        /*
		float max,min;
		float l;
		//find max
		vDSP_maxv(tmp_data,1,&max,rows*cols);
		//find min
		vDSP_minv(tmp_data,1,&min,rows*cols);
		l = max-min;
		for(j=0;j<rows*cols;j++)
		{
			tmp_data[j] = 2*(tmp_data[j]-min)/l-1;
		}*/
		[data appendBytes:tmp_data length:rows*cols*sizeof(float)];
		//tmp_data2 = (float*)[data bytes];
		//free(tmp_data);
		//we don't know what the features are, so just call them by the the column
		for(j=0;j<cols;j++)
		{
			[feature_names addObject: [NSString stringWithFormat:@"feature%d", j]];
		}
	}
	//float *tmp_data = malloc(rows*cols*sizeof(float));
	//tmp_data2 = [data bytes];    
	NSRange range;
	range.location = 0;
	range.length = rows*cols*sizeof(float);
	//add time as a dimension	
	//scale data
    float max,min,l;
    if( [[NSUserDefaults standardUserDefaults] integerForKey:@"autoScaleAxes"] == 0 )
    {
        if(tmp_data != NULL)
        {
            //find max
            vDSP_maxv(tmp_data,1,&max,rows*cols);
            //find min
            vDSP_minv(tmp_data,1,&min,rows*cols);
            l = max-min;

            for(j=0;j<rows*cols;j++)
            {
                tmp_data[j] = 2*(tmp_data[j]-min)/l-1;
            }
        }
    }
    else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"autoScaleAxes"]==1 )
    {
        //scale each feature individually
        if(tmp_data != NULL )
        {
           for(i=0;i<cols;i++)
            {
                //find max
                vDSP_maxv(tmp_data+i,cols,&max,rows);
                //find min
                vDSP_minv(tmp_data+i,cols,&min,rows);
                //scale the data
                l = (max-min);
                //vDSP_addv(tmp_data2+i,cols,&min,
                //vDSP_vsdiv(tmp_data2+i,cols,&l,tmp_data+i,cols,rows*cols);
                for(j=0;j<rows;j++)
                {
                    tmp_data[j*cols+i] = 2*(tmp_data[j*cols+i]-min)/l-1;
                }
            }
        }
    }
	/*
	//find max
	vDSP_maxv(tmp_data,1,&max,rows*cols);
	//find min
	vDSP_minv(tmp_data,1,&min,rows*cols);
	l = max-min;
	for(j=0;j<rows*cols;j++)
	{
		tmp_data[j] = 2*(tmp_data[j]-min)/l-1;
	}
	 */
    if(tmp_data != NULL)
    {
		//increase the length of data to account for the extra time axis
		[data setLength: rows*cols*sizeof(float)];
        [data replaceBytesInRange:range withBytes:tmp_data length: rows*cols*sizeof(float)];
         
        free(tmp_data);
    
        [fw createVertices:data withRows:rows andColumns:cols];
    }
	//[fw loadVertices: [openPanel URL]];
	//remove existing elements first
	[[self dim1] removeAllItems];
	[[self dim2] removeAllItems];
	[[self dim3] removeAllItems];
	[[self dim1] addItemsWithObjectValues:feature_names];
	[[self dim2] addItemsWithObjectValues:feature_names];
	[[self dim3] addItemsWithObjectValues:feature_names];
	
	
	//get time data
	//NSLog(@"XYZF: Is this going to work?");
	//NSLog(@"Filebase: %@",filebase);
    //check for the presence of xml file
	//set the window title
	[[[self fw] window] setTitle: [NSString stringWithFormat: @"FeatureViewer - %@",filebase]];
    
	if ( (autoLoadWaveforms == YES) && ([self waveformsFile] == NULL))
	{
        //check for the presence of spk files; first we need to load some info
        NSString *xmlFile = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:1];
        xmlFile = [directory stringByAppendingPathComponent: [xmlFile stringByAppendingPathExtension:@"xml"]];
        if( [[NSFileManager defaultManager] fileExistsAtPath:xmlFile] )
        {
            //NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:xmlFile];
            //now check for the presence of spk file
            NSString *spkFile = [path stringByReplacingOccurrencesOfString:@"fet" withString:@"spk"];
            //NSUInteger group = [[path pathExtension] intValue];
            if( [[NSFileManager defaultManager] fileExistsAtPath:spkFile] )
            {
                //we only need to know the number of bits and the number of channels
                //NSNumber *nbits = [[info objectForKey:@"acquisitionSystem"] objectForKey:@"nBits"];
                //NSNumber *nchannels = [[[[info objectForKey: @"anatomicalDescription"] objectForKey:@"channelGroups"] objectAtIndex:group] count];
                //now read the info from the file
                //NSData *spikeData = [NSData dataWithContentsOfFile:spkFile];
                
            }
        }
        //waveforms file usually resides in a directory above the feature file
		NSArray *waveformfiles = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [directory stringByDeletingLastPathComponent] error: nil] 
								   pathsMatchingExtensions:[NSArray arrayWithObjects:@"bin",nil]] filteredArrayUsingPredicate:
								  [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", filebase]];
		//NSString *waveformsPath = @"";
		if( [waveformfiles count] == 1 )
		{
            [self setWaveformsFile: [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent: [waveformfiles objectAtIndex:0]]];
			const char *waveformsPath = [waveformsFile cStringUsingEncoding: NSASCIIStringEncoding];
			nptHeader spikeHeader;
			spikeHeader = *getSpikeInfo(waveformsPath, &spikeHeader);
			unsigned long long int *times = malloc(rows*sizeof(unsigned long long int));
			unsigned int *times_indices = malloc(rows*sizeof(unsigned int));
			for(i=0;i<rows;i++)
			{
				times_indices[i] = i;
			}
			times = getTimes(waveformsPath, &spikeHeader, times_indices, rows, times);
			timestamps = [[NSData dataWithBytes:times length:rows*sizeof(unsigned long long int)] retain];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)(times[0])/1000.0 forKey:@"minTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)(times[rows-1])/1000.0 forKey:@"maxTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)rows forKey:@"numPoints"];

			free(times);
			free(times_indices);
		}
        else
        {
            [[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:@"minTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)rows-1 forKey:@"maxTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)rows forKey:@"numPoints"];

        }
	}
    else
    {
        [[NSUserDefaults standardUserDefaults] setFloat:0.0 forKey:@"minTime"];
        [[NSUserDefaults standardUserDefaults] setFloat:(float)rows-1 forKey:@"maxTime"];
        [[NSUserDefaults standardUserDefaults] setFloat:(float)rows forKey:@"numPoints"];

    }
        

    //load feature anems
    //NSArray *feature_names = [[NSString stringWithContentsOfFile:@"../../feature_names.txt"] componentsSeparatedByString:@"\n"];
   
    /*NSArray *feature_names;
    //open panel
    result = [openPanel runModal];
    if( result == NSOKButton )
    {
        feature_names = [[NSString stringWithContentsOfURL :[openPanel URL]] componentsSeparatedByString:@"\n"];
   
        
        [dim1 addItemsWithObjectValues:feature_names];
        [dim2 addItemsWithObjectValues:feature_names];
        [dim3 addItemsWithObjectValues:feature_names];
     }*/
    params.rows = rows;
    params.cols = cols;
	//make sure we receive setFeatures notification 
	featureNames = [[NSMutableArray arrayWithArray:feature_names] retain];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) 
												 name:@"setFeatures" object:nil];
    [[self dim1] setEditable:NO];
	if( [feature_names containsObject: @"triggerValue1"])
	{
		[[self dim1] selectItemWithObjectValue:@"triggerValue1"];
	}
	else
	{
		[[self dim1] selectItemAtIndex: 0];
	}
	[[self dim1] setObjectValue:[[self dim1] objectValueOfSelectedItem]];
	//notifiy of the change
	[self changeDim1:[self dim1]];
    [[self dim2] setEditable:NO];
	if( [feature_names containsObject: @"wavePC11"])
	{
		[[self dim2] selectItemWithObjectValue:@"wavePC11"];
	}
	else
	{
		[[self dim2] selectItemAtIndex: 0];
	}
	[[self dim2] setObjectValue:[[self dim2] objectValueOfSelectedItem]];
	[self changeDim2:[self dim2]];
    [[self dim3] setEditable:NO];
	if( [feature_names containsObject: @"wavePC21"])
	{
		[[self dim3] selectItemWithObjectValue:@"wavePC21"];
	}
	else
	{
		[[self dim3] selectItemAtIndex: 0];

	}
	[[self dim3] setObjectValue:[[self dim3] objectValueOfSelectedItem]];
	[self changeDim3:[self dim3]];
	//register featureview for notification about change in highlight
	//feature view only received notification from waveforms view
	//[[NSNotificationCenter defaultCenter] addObserver: fw selector:@selector(receiveNotification:) 
	//											 name:@"highlight" object: [self wfv]];
	
	
    
    if( [[NSUserDefaults standardUserDefaults] boolForKey:@"stimInfo"] ==YES)
    {
        NSString *stimInfoFile = NULL;
        NSString *stimInfoDir = directory;
        if( waveformsFile != NULL )
        {
            //attempt to locate a simtinfo object. This should be located two levels above the waveformfile
            NSString *stimInfoDir = [waveformsFile stringByDeletingLastPathComponent];
            stimInfoFile = [waveformsFile lastPathComponent];
            NSRange _r = [stimInfoFile rangeOfString:@"g00"];
            stimInfoFile = [stimInfoDir stringByAppendingPathComponent:[[stimInfoFile substringWithRange:NSMakeRange(0, _r.location)] stringByAppendingString:@".ini"]];
            if( [[NSFileManager defaultManager] fileExistsAtPath:stimInfoFile] == NO)
            {
                stimInfoDir = [[waveformsFile stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
                stimInfoFile = [waveformsFile lastPathComponent];
                _r = [stimInfoFile rangeOfString:@"g00"];
                stimInfoFile = [stimInfoDir stringByAppendingPathComponent:[[stimInfoFile substringWithRange:NSMakeRange(0, _r.location)] stringByAppendingString:@"_stimInfo.mat"]];
            }
        }
        if( [[NSFileManager defaultManager] fileExistsAtPath:stimInfoFile] == NO)
        {
            stimInfoFile=NULL;
            //ask for the file name
            NSOpenPanel *panel = [NSOpenPanel openPanel];
            [panel setDirectory:stimInfoDir];
            [panel setTitle:@"Open stimulus file"];
            [panel setAllowedFileTypes: [NSArray arrayWithObjects:@"ini", nil]];
            int result = [panel runModal];
            if (result == NSOKButton )
            {
                stimInfoFile = [panel filename];
            }
        }
        
        
        if(stimInfoFile != NULL)
        {
            //load stimInfo
            stimInfo = [[[StimInfo alloc] init] retain];
            [stimInfo readFromFile:stimInfoFile];
            [stimInfo readMonitorSyncs];
            [stimInfo readDescriptor];
            [stimInfo getFramePoints];
            //[stimInfo getTriggerSignalWithThreshold:1500.0];
        }
        else
        {
            //pop up a dialog box asking for the necessary values; we can get by creating an approximate raster by getting the duration of each stimulus repetition
        }
    }
	//only reset clusters if data has already been loaded
    if( ([self Clusters] != nil) && (dataloaded == YES ) )
    {
		//don't send notifcation about cluster state changed
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];
        [self removeAllObjectsFromClusters];
    }
    dataloaded = YES;
    //show window
    if( [[[self fw] window] isVisible] == NO )
    {
        [[[self fw] window] orderFront:self];
    }
	//check if we are also auto-loading cluster
    //create a noise cluster with all points
    Cluster *firstCluster = [[Cluster alloc] init];
    [firstCluster setClusterId:[NSNumber numberWithInt:0]];
    [firstCluster setIndices:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, rows)]];
    [firstCluster setNpoints:[NSNumber numberWithUnsignedInt: rows]];
    unsigned int *points = malloc(rows*sizeof(unsigned int));
    for(i=0;i<rows;i++)
    {
        points[i] = (unsigned int)i;
    }
    [firstCluster setPoints:[NSMutableData dataWithBytes:points length:rows*sizeof(unsigned int)]];
    free(points);
    [firstCluster createName];
    //compute mean and covariance
    [firstCluster setFeatureDims:cols];
    [firstCluster computeFeatureMean:[[self fw] getVertexData]];
	//[firstCluster computeFeatureCovariance:[[self fw] getVertexData]];
	//compute pca on the whole feature space
		
    //create cluster color
    float *_ccolor = malloc(3*sizeof(float));
    _ccolor[0] = 1.0f;//use_colors[3*cids[i+1]];
    _ccolor[1] = 0.85f;//use_colors[3*cids[i+1]+1];
    _ccolor[2] = 0.35f;//use_colors[3*cids[i+1]+2];
    [firstCluster setColor: [NSData dataWithBytes:_ccolor length:3*sizeof(float)]];
    [firstCluster makeActive];
    [firstCluster makeValid];
    free(_ccolor);
    [selectClusterOption addItemWithTitle:@"Create cluster"];
    [selectClusterOption addItemWithTitle:@"Add points to cluster"];
    [selectClusterOption addItemWithTitle:@"Delete"];
    [selectClusterOption addItemWithTitle:@"Compute ISOmap"];
	[selectClusterOption addItemWithTitle: @"Find correlated waverforms"];
	[selectClusterOption addItemWithTitle:@"Show cluster notes"];
	[selectClusterOption addItemWithTitle: @"Find best projection"];
	[selectClusterOption addItemWithTitle: @"Multi-unit"];
    [clusterMenu addItemWithTitle:@"Create cluster" action:@selector(performClusterOption:) keyEquivalent:@""];
    [clusterMenu addItemWithTitle:@"Add points to cluster" action:@selector(performClusterOption:) keyEquivalent:@""];
    [clusterMenu addItemWithTitle:@"Move points to cluster" action:@selector(performClusterOption:) keyEquivalent:@""];
    [clusterMenu addItemWithTitle:@"Remove points from cluster" action:@selector(performClusterOption:) keyEquivalent:@""];
	NSLog(@"Finished adding menu items");
    //before we create the cluster, hide all existing clusters
    [[self fw] hideAllClusters];
    if([ self Clusters] != nil )
    {
        [self insertObject:firstCluster inClustersAtIndex:0];
    }
    else
    {
        [self setClusters:[NSMutableArray arrayWithObject:firstCluster]];
    }
	[clusterController rearrangeObjects];
	//release first cluster since we are done with it; it now belongs to Clusters
	[firstCluster release];
    //enable the time slider on the main menu
    [[[NSApp mainMenu] itemWithTitle: @"Time slider"] setEnabled:YES];
    //register for slider notifications
    
    //set the log file
    [self setLogFilePath:[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.log", filebase]]];
	//check if are also laoding clusters
	NSLog(@"CurrentDir = %@", currentDir);
	NSLog(@"CurrentBaesName = %@", currentBaseName);
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"autoLoadClusters"])
	{
		NSArray *_fileNames = [[NSFileManager defaultManager] directoryContentsAtPath: [self currentDir] ];
		//try looking for .fv file first
		NSArray *_goodFiles = [_fileNames filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF MATCHES[cd] %@", 
							 [currentBaseName stringByAppendingString:@".fv"]]];
		if( [_goodFiles count] > 0)
		{
			[self openClusterFile: [[self currentDir] stringByAppendingPathComponent: [_goodFiles firstObject]]];
		}
		//try looking for a cut file first
		_goodFiles = [_fileNames filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF MATCHES[cd] %@", 
							 [currentBaseName stringByAppendingString:@".cut"]]];
	
		if( [_goodFiles count] == 0)
		{
			_goodFiles = [_fileNames filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF BEGINSWITH[cd] %@", 
								 [currentBaseName stringByAppendingString:@".clu"]]];
		}
		if( [_goodFiles count] > 0)
		{
			//we found something
			[self openClusterFile: [[self currentDir] stringByAppendingPathComponent: [_goodFiles firstObject]]];
		}
		else
		{
			//check one directory above
			_fileNames = [[NSFileManager defaultManager] directoryContentsAtPath: [[self currentDir] stringByAppendingPathComponent:@"../"]];
			_goodFiles = [_fileNames filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"SELF BEGINSWITH[cd] %@", 
							 [currentBaseName stringByAppendingString:@".clu"]]];
			if( [_goodFiles count] > 0)
			{
				[self openClusterFile: [[self currentDir] stringByAppendingString: [NSString stringWithFormat:@"/../%@",[_goodFiles firstObject]]]];
			}
			else
			{
				NSLog(@"Could not find cluster file");
			}
		}
	}
	//allow object to receive performClusterOptions
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"performClusterOption" object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
	dataloaded = YES;
	NSLog(@"Data loaded %d", dataloaded);
	[_pool drain];
}


-(void)loadStimInfo
{
    NSString *stimInfoFile = NULL;
    NSString *stimInfoDir = NULL;
    if( waveformsFile != NULL )
    {
        //attempt to locate a simtinfo object. This should be located two levels above the waveformfile
        NSString *stimInfoDir = [waveformsFile stringByDeletingLastPathComponent];
        stimInfoFile = [waveformsFile lastPathComponent];
        NSRange _r = [stimInfoFile rangeOfString:@"g00"];
        stimInfoFile = [stimInfoDir stringByAppendingPathComponent:[[stimInfoFile substringWithRange:NSMakeRange(0, _r.location)] stringByAppendingString:@".ini"]];
        if( [[NSFileManager defaultManager] fileExistsAtPath:stimInfoFile] == NO)
        {
            stimInfoDir = [[waveformsFile stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
            stimInfoFile = [waveformsFile lastPathComponent];
            _r = [stimInfoFile rangeOfString:@"g00"];
            stimInfoFile = [stimInfoDir stringByAppendingPathComponent:[[stimInfoFile substringWithRange:NSMakeRange(0, _r.location)] stringByAppendingString:@"stimInfo.mat"]];
        }
    }
    if( [[NSFileManager defaultManager] fileExistsAtPath:stimInfoFile] == NO)
    {
        stimInfoFile=NULL;
        //ask for the file name
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        if( stimInfoDir != NULL)
        {
            [panel setDirectory:stimInfoDir];
        }
        [panel setTitle:@"Open stimulus file"];
        [panel setAllowedFileTypes: [NSArray arrayWithObjects:@"ini", nil]];
        int result = [panel runModal];
        if (result == NSOKButton )
        {
            stimInfoFile = [panel nameFieldStringValue];
        }
    }
    
    
    if(stimInfoFile != NULL)
    {
        //load stimInfo
        stimInfo = [[[StimInfo alloc] init] retain];
        [stimInfo readFromFile:stimInfoFile];
        [stimInfo readMonitorSyncs];
        [stimInfo readDescriptor];
        [stimInfo getFramePoints];
        //[stimInfo getTriggerSignalWithThreshold:1500.0];
    }
    else
    {
        //pop up a dialog box asking for the necessary values; we can get by creating an approximate raster by getting the duration of each stimulus repetition
    }

}

- (IBAction) loadClusterIds: (id)sender
{
	//first check whether there is a single file to load
	//NSString *clusterFname = [currentDir stringByAppendingPathComponent: currentBaseName];
     
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    //set a delegate for openPanel so that we can control which files can be opened
    [openPanel setDelegate:[[[OpenPanelDelegate alloc] init] autorelease]];
    //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
    
	[[openPanel delegate] setBasePath: currentBaseName];
    [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"clu",@"fv",@"overlap",@"cut",@"clusters",nil]];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        [self openClusterFile:[[openPanel URL] path]];
    }
        
                                                       
}

- (void)openClusterFile:(NSString*)path;
{
	NSAutoreleasePool *_pool = [[NSAutoreleasePool alloc] init];
	unsigned int i,j;
    [[NSNotificationCenter defaultCenter] removeObserver: self name: @"ClusterStateChanged" object: nil];
    //remove all the all clusters
    //[self removeAllObjectsFromClusters];
    //NSString *filename = [[openPanel URL] path];
    //get the components of the filename; sometimes we are interested int he last extension, sometimes the second last
    NSArray *fileComps = [[path lastPathComponent] componentsSeparatedByString:@"."]; 
    NSUInteger nFileComps = [fileComps count];
    NSString *extension = [fileComps objectAtIndex:1];
    float *cluster_colors = NULL;
    NSMutableArray *tempArray = NULL;
    //check if data is loaded
    if(dataloaded==NO)
    {
        //need to load the data before loading the clusters
        
        //get the basename
        NSString *basename = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
        NSString *directory = [path stringByDeletingLastPathComponent];
        [self setCurrentDir:directory];
        NSString *featurePath = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_area.fd", basename]];
		//set the waveforms file as well
		NSString *wfFile = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", basename]];
		if( [[NSFileManager defaultManager] fileExistsAtPath:wfFile] == YES )
		{
			[self setWaveformsFile:wfFile];
		}
			
		//check if the path exists
		if( [[NSFileManager defaultManager] fileExistsAtPath:featurePath] == NO )
		{
			//try the FD directory
			featurePath = [[directory stringByAppendingPathComponent:@"FD"] stringByAppendingPathComponent:
						   [NSString stringWithFormat:@"%@_area.fd", basename]];
			
			if( [[NSFileManager defaultManager] fileExistsAtPath:featurePath] == NO )
			{
				//file could not be automatically located; popup a dialog to ask for it
				[self loadFeatureFile:self];
				
			}
			else {
				//we found the feature file, so open it
				[self openFeatureFile:featurePath];
			}

	
		}
		else
		{
			[self openFeatureFile:featurePath];
		}
    }
	//create a data object to hold the channels
	unsigned int *_chs = malloc(nvalidChannels*sizeof(unsigned int));
	j = 0;
	for(i=0;i<nchannels;i++)
	{
		if(channelValidity[i]==1)
		{
			_chs[j] = i;
			j+=1;
		}
	}
    if( [[fileComps lastObject] isEqualToString:@"fv"] )
    {
        tempArray = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        //get cluster colors
        //NSMutableData *_cluster_colors = [NSMutableData dataWithCapacity:params.rows*3*sizeof(float)];
        cluster_colors = malloc(params.rows*3*sizeof(float));
        id _cluster;
        NSEnumerator *_clustersEnumerator = [tempArray objectEnumerator];
        while( _cluster = [_clustersEnumerator nextObject] )
        {
			NSUInteger _idx;
			NSIndexSet *_indexSet;
            float *_color = (float*)[[_cluster color] bytes];
			_indexSet = [_cluster indices];
			_idx = [_indexSet firstIndex];
			while( _idx != NSNotFound )
			{
				cluster_colors[3*_idx] = _color[0];
				cluster_colors[3*_idx+1] = _color[1];
				cluster_colors[3*_idx+2] = _color[2];
				_idx = [_indexSet indexGreaterThanIndex: _idx];
			}
        }
        [tempArray makeObjectsPerformSelector:@selector(makeValid)];
        
    }
    else 
	{
        if( [[fileComps lastObject] isEqualToString:@"cut"] || [[fileComps objectAtIndex:nFileComps-2] isEqualToString:@"clu"] )
        {
			int offset = 1;
			if( [[fileComps lastObject] isEqualToString:@"cut"] )
			{
				offset = 0;
			}
        
			//char *fname = [path cStringUsingEncoding:NSASCIIStringEncoding];
			//TODO: Check if there is also an overlap present; if so, load it as well
			/*
			 header H;
			 H = *readFeatureHeader("../../test2.hdf5", &H);
			 int rows = H.rows;
			 */
			int *cids = calloc((rows+1),sizeof(int));
			//cids = readClusterIds(fname, cids);
			NSArray *lines = [[NSString stringWithContentsOfFile:path encoding: NSASCIIStringEncoding error: NULL] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			//iteratae through lines
			NSEnumerator *lines_enum = [lines objectEnumerator];
			id line;
			NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
			int cidx,v;
			cidx =  0;
			while ( (line = [lines_enum nextObject] ) )
			{
				NSNumber *q = [formatter numberFromString:line];
				//if line is not a string, q is nil
				if( q )
				{
					v = [q intValue];
					if( v >= 0)
					{
						cids[cidx] = v;
					}
					cidx+=1;
				}
				
			}
			//done with formatter, so release it
			[formatter release];
			//find the maximum cluster number
			//TODO: this is quick and dirty; should try and speed this up
			int maxCluster = 0;
			int i;

			for(i=0;i<rows;i++)
			{
				if( cids[i+offset] > maxCluster )
				{
					maxCluster = cids[i+offset];
				}
			}
			//since we are using 0-based indexing, the number of clusters is maxCluster+1
			maxCluster+=1;
		
			tempArray = [NSMutableArray arrayWithCapacity:maxCluster];
			//count the number of points in each cluster
			unsigned int *npoints;
			npoints = calloc(maxCluster,sizeof(unsigned int));
			cluster_colors = malloc(rows*3*sizeof(float));
			for(i=0;i<rows;i++)
			{
				if( cids[i+offset] >= 0 )
				{
					npoints[cids[i+offset]]+=1;
				}
			}
			
			NSUInteger *cpoints = malloc(rows*sizeof(NSUInteger));
			for(i=0;i<maxCluster;i++)
			{
				Cluster *cluster = [[Cluster alloc] init];
				cluster.clusterId = [NSNumber numberWithUnsignedInt:i];
				//cluster.name = [NSString stringWithFormat: @"%d",i];
				
				
				cluster.npoints = [NSNumber numberWithUnsignedInt: npoints[i]];
				[cluster setTotalNPoints: [NSNumber numberWithUnsignedInt:rows]];
				//cluster.name = [[[[cluster clusterId] stringValue] stringByAppendingString:@": "] stringByAppendingString:[[cluster npoints] stringValue]];
				[cluster createName];
				cluster.indices = [NSMutableIndexSet indexSet];
				cluster.valid = 1;
				[cluster setChannels: [NSData dataWithBytes: _chs length:nvalidChannels*sizeof(unsigned int)]];
				//set color
				float color[3];
				srandom(i);
				color[0] = ((float)rand())/RAND_MAX;
				color[1] = ((float)rand())/RAND_MAX;
				color[2] = ((float)rand())/RAND_MAX;
				cluster.color = [NSData dataWithBytes: color length:3*sizeof(float)];
				unsigned int *points = malloc(npoints[i]*sizeof(unsigned int));
				int j,k = 0;
				//use a binary mask to indicate cluster membership
				//uint8 *_mask = calloc(rows,sizeof(uint8));
				
				for(j=0;j<rows;j++)
				{
					if(cids[j+offset]==i)
					{
						points[k] = (unsigned int)j;
						//mask[j] = 1;
						cpoints[j]= k;
						k+=1;
						//set the colors at the same time
						cluster_colors[3*j] = color[0];
						cluster_colors[3*j+1] = color[1];
						cluster_colors[3*j+2] = color[2];
						[[cluster indices] addIndex: (NSUInteger)j];
						
					}
					
				}
				cluster.points = [NSMutableData dataWithBytes:points length:npoints[i]*sizeof(unsigned int)];
				//cluster.mask = [NSMutableData dataWithBytes: _mask length: rows*sizeof(uint8)];
				//free(_mask);
				free(points);
				//compute ISIs; this step can run on a separate thread
				[cluster computeISIs:timestamps];
				[cluster setIsTemplate:0];
				[cluster setActive: 1];
				[tempArray addObject:cluster];
				//we have handed over ownership of cluster to tempArray, so release it
				[cluster release];
			}
			[[self fw] setClusterIdx: cpoints count: rows];
			free(cpoints);
			free(cids);
			free(npoints);
			//free(cluster_colors);

			//tell the view to change the colors
		}
		else if ([[fileComps lastObject] isEqualToString:@"overlap"])
		{
			const char *fname = [path cStringUsingEncoding:NSASCIIStringEncoding];
			uint64_t nelm = getFileSize(fname)/sizeof(uint64_t);
			unsigned ncols = nelm/2;
			uint64_t *overlaps = malloc(nelm*sizeof(uint64_t));
			overlaps = readOverlapFile(fname, overlaps, nelm);
			//since the overlaps are assumed to ordered according to clusters, with cluster ids in the first column, we can easily get
			//the maximum numbers of clusters
			unsigned int maxCluster = overlaps[ncols-2]+1;
			unsigned i;
				
			cluster_colors = malloc(3*ncols*sizeof(float));
			tempArray = [NSMutableArray arrayWithCapacity:maxCluster];
            //NSLog(@"maxCluster: %d", maxCluster);
			for(i=0;i<maxCluster;i++)
			{
				Cluster *cluster = [[Cluster alloc] init];
				cluster.clusterId = [NSNumber numberWithUnsignedInt:i];
				//cluster.name = [NSString stringWithFormat: @"%d",i];
				
				
				cluster.npoints = [NSNumber numberWithUnsignedInt: 0];
				//cluster.name = [[[[cluster clusterId] stringValue] stringByAppendingString:@": "] stringByAppendingString:[[cluster npoints] stringValue]];
				[cluster createName];
				cluster.indices = [NSMutableIndexSet indexSet];
				cluster.valid = 1;
				//set color
				float color[3];
				color[0] = ((float)rand())/RAND_MAX;
				color[1] = ((float)rand())/RAND_MAX;
				color[2] = ((float)rand())/RAND_MAX;
				cluster.color = [NSData dataWithBytes: color length:3*sizeof(float)];
				cluster.points = [NSMutableData dataWithCapacity:1000*sizeof(unsigned long)];
				//cluster.mask = [NSMutableData dataWithBytes: _mask length: rows*sizeof(uint8)];
				//free(_mask);
				//compute ISIs; this step can run on a separate thread
				//[cluster computeISIs:timestamps];
				[cluster setIsTemplate:0];
				[cluster setActive: 1];
                //TODO: for some reason, the update doesn't work properly so I had to disable it
				//[cluster updateDescription];
				[tempArray addObject:cluster];
				[cluster release];
			}
			//now loop through the overlap matrix, adding points to the clusters as we go along
			unsigned int cid,wfidx,npoints;
			cid = maxCluster+1;
			Cluster *cluster = NULL;
			float  *color;
			for(i=0;i<ncols;i++)
			{
				wfidx = overlaps[ncols+i];
				if( overlaps[i] != cid )
				{
					cid = overlaps[i];
					cluster = [tempArray objectAtIndex:cid];
				}
				//set the colors
                if(cluster != NULL)
                {
                    color = (float*)[[cluster color] bytes];
                    cluster_colors[3*i] = color[0];
                    cluster_colors[3*i+1] = color[1];
                    cluster_colors[3*i+2] = color[2];
                    
                    [[cluster points] appendBytes:&wfidx length:sizeof(unsigned int)];
                    [[cluster indices] addIndex:wfidx];
                    npoints = [[cluster npoints] unsignedIntValue];
                    //increment the number of points
                    [cluster setNpoints:[NSNumber numberWithUnsignedInt:npoints+1]];
                }
			}
			//free overlaps since we don't need it
			free(overlaps);
			[tempArray makeObjectsPerformSelector:@selector(createName)];	
			
		}
        else if ([[fileComps lastObject] isEqualToString:@"clusters"])
        {
            unsigned int* cids = malloc(rows*sizeof(unsigned int));
            readMClustClusters([path cStringUsingEncoding:NSASCIIStringEncoding], cids);
        }
        else
        {
            //unknown extension
            NSAlert *alert = [NSAlert alertWithMessageText:@"Unknown extension" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:nil];
            [alert runModal];
            
        }
        
    }
	free(_chs);
	//turn off the first cluster, since it's usually the noise cluster
    if(tempArray != NULL )
    {
        [[tempArray objectAtIndex:0] makeInactive];
    }
	if( (dataloaded == YES ) && (cluster_colors != NULL))
	{
		//only do this if data has been loaded
		[fw setClusterColors: cluster_colors forIndices: NULL length: rows];
	}
    //since colors are now ccopied, we can free it
    if( cluster_colors != NULL )
    {
        free(cluster_colors);
    }
    if( ([self Clusters] != nil) && (dataloaded == YES ) )
    {
        [self removeAllObjectsFromClusters];
		[[self fw] hideAllClusters];
    }
	[self setClusters:tempArray];
	[[self fw] setSelectedClusters: [NSMutableArray arrayWithArray: tempArray]];
    [self setIsValidCluster:[NSPredicate predicateWithFormat:@"valid==1"]];
   
	//apply filter
	[clusterController setFilterPredicate: [self filterClustersPredicate]] ;
    //[selectClusterOption removeAllItems];
    NSMutableArray *options = [NSMutableArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Filter clusters",@"Remove waveforms",@"Make Template",@"Multi-unit",@"Undo Template",@"Compute XCorr",@"Compute Isolation Distance",@"Compute Isolation Info", @"Show raster",@"Save clusters",@"Assign to cluster",@"Split among clusters",@"Screen waveforms",@"Resolve overlaps",nil];
    
    //test
    //clusterOptionsMenu  = [[[NSMenu alloc] initWithTitle:@"Options"] autorelease];
    //add some items
    //[clusterOptionsMenu addItem: [[NSMenuItem alloc] initWithTitle:@"Make template" action:@selector(performClusterOption:) keyEquivalent:nil]];
    //
    if(timestamps!=NULL)
    {
        //only allow isi computation if timestamps are loaded
        [options addObject:@"Shortest ISI"];
    }
    
    //[selectClusterOption addItemsWithTitles: [NSArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Show waveforms",@"Filter clusters",
    //                                         @"Compute Isolation Distance",nil]];
    //[self setClusterOptions:[NSArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Show waveforms",@"Filter clusters",nil]];
    
    //draw image of all clusters
	
	NSEnumerator *clusterEn = [[self Clusters] objectEnumerator];
	Cluster *cluster;
    NSMenu *addToClustersMenu,*moveToClusterMenu;
    addToClustersMenu = [[[NSMenu alloc] init] autorelease];
    moveToClusterMenu = [[[NSMenu alloc] init] autorelease];
    uint8_t _allActive = 1;
	while( (cluster=[clusterEn nextObject] ) ) 
	{
        [cluster setFeatureDims:params.cols];
        //update the menu
        [addToClustersMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[cluster clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];
        [moveToClusterMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[cluster clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];
        //check that there no more than 5000 points
		if( ([[cluster clusterId] unsignedIntValue] > 0 ) && ([[cluster npoints] unsignedIntValue] >0))
		{
			[self loadWaveforms: cluster];
			//make sure we also update the waverormsImage
			if([cluster waveformsImage] == NULL)
			{
				NSImage *img = [[self wfv] image];
				[cluster setWaveformsImage:img];
			}
		}
        _allActive = _allActive*(uint8_t)([cluster active]);
		//add set the feature dimension
		[cluster setFeatureDims: params.cols];
		//compute mean and covariance
		[cluster computeFeatureMean: [[self fw] getVertexData]];
		[cluster computeFeatureCovariance: [[self fw] getVertexData]];
		
	}
    [[[self clusterMenu] itemWithTitle:@"Add points to cluster"] setSubmenu:addToClustersMenu];
    [[[self clusterMenu] itemWithTitle:@"Move points to cluster"] setSubmenu:moveToClusterMenu];

	[[wfv window] orderOut: self];
	//turn off overlay for the waveforms window such that we start from scratch next time we draw
	[wfv setOverlay: NO];
	//[self performComputation:@"Compute Feature Mean" usingSelector:@selector(computeFeatureMean:)];
    //[self performComputation:@"Compute Feature Covariance" usingSelector:@selector(computeFeatureCovariance:)];
	//[allActive setState:1];
    if(_allActive == 1)
        [allActive setState:1];
	[[self fw] showAllClusters];
	//make sure we pass the Featureview the list of clusters
	[[self fw ] setSelectedClusters: [NSMutableArray arrayWithArray:Clusters]];
	//check if we are doing isolation distance
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
	    //check for model file
	/*j
    NSString *modelFilePath = [path stringByReplacingOccurrencesOfString: extension withString: @"model"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: modelFilePath ] )
    {
        [self readClusterModel:modelFilePath];
        [options addObject: @"Compute L-ratio"];
    }
	*/
    //update the state of the allActive button
    
    [selectClusterOption addItemsWithTitles:options];
    //once we have loaded the clusters, start up a timer that will ensure that data gets arhived automatically every 5 minutes
    archiveTimer = [[NSTimer scheduledTimerWithTimeInterval:120 target:self selector:@selector(archiveClusters:) userInfo:nil repeats: YES] retain];
	//allow object to receive performClusterOptions
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"performClusterOption" object: nil];
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"doIsolationDistance"])
	{

        [self performComputation:@"Compute Isolation Distance" usingSelector:@selector(computeIsolationDistance:)];
		//sort the clusters
        NSMutableArray *descriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"isolationDistance" ascending:NO]];
        [self setClustersSortDescriptors: descriptors];

	}
	clustersLoaded = YES;
	//make sure no clusters are selected initially
	selectedCluster = nil;
	[_pool drain];
}

-(void) openWaveformsFile: (NSString*)path
{
    //since we do not, in general want to load the entire waveforms file, we load instead a random subset
    //hide the feature view since we dont need it
	//indicate that we want to show waveforms
	shouldShowWaveforms = YES;
    [[fw window ] orderOut: self];
    //we also dont' want the FeatureView to receive any notifications
    [[NSNotificationCenter defaultCenter] removeObserver: fw];
    [self setWaveformsFile:path];
    const char *fpath = [[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding];
    nptHeader spikeHeader;
    spikeHeader = *getSpikeInfo(fpath,&spikeHeader);
    int _npoints = 1000;
    //in case there aren't enough points
    if (_npoints > spikeHeader.num_spikes) 
    {
        _npoints = spikeHeader.num_spikes;
    }
    unsigned int *_points = malloc(_npoints*sizeof(unsigned int));
    int i;
    Cluster *cluster = [[Cluster alloc] init];
	[cluster setClusterId: [NSNumber numberWithInt:0]];
    //create an index
    NSMutableIndexSet *_index = [NSMutableIndexSet indexSet];
    //[cluster setIndices:[NSMutableIndexSet indexSet]];
    if( _npoints < spikeHeader.num_spikes)
    {
        for(i=0;i<_npoints;i++)
        {
            _points[i] = (unsigned int)((((float)rand())/RAND_MAX)*(spikeHeader.num_spikes));
            [_index addIndex:_points[i]];
        }
    }
    else
    {
        for(i=0;i<_npoints;i++)
        {
            _points[i] = i;
            [_index addIndex:_points[i]];
        }
    }
    [cluster addIndices:_index];
    /*
    [cluster createName];
    [cluster setPoints:[NSMutableData dataWithBytes:_points length:_npoints*sizeof(unsigned int)]];
    [cluster setNpoints:[NSNumber numberWithUnsignedInt: _npoints]];
    */
    float color[3];
    color[0] = ((float)rand())/RAND_MAX;
    color[1] = ((float)rand())/RAND_MAX;
    color[2] = ((float)rand())/RAND_MAX;
    cluster.color = [NSData dataWithBytes: color length:3*sizeof(float)];
    free(_points);
    [self loadWaveforms:cluster];
    //allow the waveforms view to receive notification about highlights
    [[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
    //make the cluster valid
    [cluster makeValid];
    //add the cluster
    if( [self Clusters] == nil )
    {
        [self setClusters:[NSMutableArray arrayWithObject:cluster]];
    }
    else
    {
        unsigned int nclusters = [[self Clusters] count];
        [self insertObject:cluster inClustersAtIndex:nclusters];
    }
    //check if we are to compute features as well

    if([[NSUserDefaults standardUserDefaults] objectForKey:@"autoLoadFeatures"])
    {
        //here we really want to load everything and compute features, but only if no features exist yet
        //attempt to load feature files first; in general look in the FD directory below the waveforms file directory
        BOOL found = NO;
        NSString *featurePath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"FD"];
        //get the files in the directory
        NSArray *files = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:featurePath error: nil] pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",@"fet", nil]];
        if( files == nil )
        {
            //no contents found, or an error occured
        }
        else
        {
            files = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"SELF BEGINSWITH[c] %@", [[path lastPathComponent] stringByDeletingPathExtension]]];
            if([files count] > 0 )
            {
                [self openFeatureFile:[featurePath stringByAppendingPathComponent:[files objectAtIndex:0]]];
                found = YES;
            }
            //hide all clusters
            [allActive setState:0];
            [[self fw] hideAllClusters];
            //only show the feature points corresponding to the waveforms we are showing.
            [[self fw] showCluster:cluster];
            //set the colors
            [[self fw] setClusterColors:(GLfloat*)[[cluster color] bytes] forIndices:(GLuint*)[[cluster points] bytes] length:[[cluster npoints] unsignedIntValue]];
            
            [[NSNotificationCenter defaultCenter] addObserver:[self fw] selector:@selector(receiveNotification:) name:NSUserDefaultsDidChangeNotification object:nil];
            [cluster makeActive];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(ClusterStateChanged:)
                                                         name:@"ClusterStateChanged" object:nil];
        }
        //if we still haven't found anything, give the user a choice between manually locating the features, or computing them
        if(found == NO )
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSInformationalAlertStyle];
            [alert setMessageText:@"Unable to located features, would you like to manually locate them, have the program compute the features, or go ahead without features?"];
            [alert addButtonWithTitle:@"Skip features"];
            [alert addButtonWithTitle:@"Compute features"];
            [alert addButtonWithTitle:@"Locate features"];
            int result = [alert runModal];
            if(result == NSAlertSecondButtonReturn )
            {
                //compute features
                //load all the data in the waveforms file and compute features
                NSLog(@"Computing features...");
                _points = malloc(spikeHeader.num_spikes*sizeof(unsigned int));
                //create an index to load everything
                const char *cpath = [path cStringUsingEncoding:NSASCIIStringEncoding]; 
                for(i=0;i<spikeHeader.num_spikes;i++)
                {
                    _points[i] = i;
                }
                unsigned int wfSize = spikeHeader.num_spikes*spikeHeader.channels*spikeHeader.timepts;
                short int *waveforms = malloc(wfSize*sizeof(short int));
                waveforms = getWaves(cpath, &spikeHeader, _points, spikeHeader.num_spikes, waveforms);
                    
                //convert to float
                float *fwaveforms = malloc(wfSize*sizeof(float));
                vDSP_vflt16(waveforms, 1, fwaveforms, 1, wfSize);
                free(waveforms);
                
                //computeFeatures
                [self computeFeature:[NSData dataWithBytes:fwaveforms length:wfSize*sizeof(float)] withNumberOfSpikes: spikeHeader.num_spikes andChannels:spikeHeader.channels andTimepoints:spikeHeader.timepts];
                //set the colors
                [[self fw] setClusterColors:(GLfloat*)[[cluster color] bytes] forIndices:(GLuint*)[[cluster points] bytes] length:[[cluster npoints] unsignedIntValue]];
                
                [[NSNotificationCenter defaultCenter] addObserver:[self fw] selector:@selector(receiveNotification:) name:NSUserDefaultsDidChangeNotification object:nil];
                //make sure we send notification about state changes
                 [cluster makeActive];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(ClusterStateChanged:)
                                                             name:@"ClusterStateChanged" object:nil];
               
                //[[NSNotificationCenter defaultCenter] addObserver:[self fw] selector:@selector(receiveNotification:) name:@"ClusterStateChanged" object:nil];
            }
            else if (result == NSAlertThirdButtonReturn)
            {
                [self loadFeatureFile:self];
                //if the feature window is hidden, make it visible
                if( [[[self fw] window] isVisible] == NO)
                {
                    [[[self fw] window] orderFront:self];
                }
                //hide all clusters
                [allActive setState:0];
                [[self fw] hideAllClusters];
                //only show the feature points corresponding to the waveforms we are showing.
                [[self fw] showCluster:cluster];
                //set the colors
                [[self fw] setClusterColors:(GLfloat*)[[cluster color] bytes] forIndices:(GLuint*)[[cluster points] bytes] length:[[cluster npoints] unsignedIntValue]];
                
                [[NSNotificationCenter defaultCenter] addObserver:[self fw] selector:@selector(receiveNotification:) name:NSUserDefaultsDidChangeNotification object:nil];
                [cluster makeActive];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(ClusterStateChanged:)
                                                             name:@"ClusterStateChanged" object:nil];
                

            }
            [alert release];
            
        }
        //[self computeFeature:<#(NSData *)#> withChannels:<#(NSUInteger)#> andTimepoints:<#(NSUInteger)#>
    }
    [cluster release];//release the cluster since we have added it to the clusters array

    
}
- (void)updateWaveformsFromCluster: (Cluster*)cluster fromIndex: (NSUInteger)startIndex toIndex: (NSUInteger)endIndex
{
    autoLoadWaveforms = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoLoadWaveforms"];
    if ( (waveformsFile == NULL) && ( autoLoadWaveforms))
    {
        int result;
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        //set a delegate for openPanel so that we can control which files can be opened
        [openPanel setDelegate:[[[OpenPanelDelegate alloc] init] autorelease]];
		[openPanel setTitle:@"Choose waveforms to load"];
        //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
        [[openPanel delegate] setBasePath: currentBaseName];
        [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"bin",nil]];
        result = [openPanel runModal];
        if( result == NSOKButton )
        {
            //test
            //Cluster *cluster = [Clusters objectAtIndex: 3];
            [self setWaveformsFile:[[openPanel URL] path]];
			[[wfv window] orderFront: self];
        }
        else if( result == NSCancelButton )
        {
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"autoLoadWaveforms"];
        }
    }
    if( waveformsFile != NULL)
    {
        NSUInteger lastIndex,maxWaveformsDrawn;
        const char *path;
        unsigned int npoints,wfSize,i;
        short int *waveforms;
        float *fwaveforms;
        
        path = [waveformsFile cStringUsingEncoding:NSASCIIStringEncoding];
        NSString *reorderPath = [[[self waveformsFile] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
		NSMutableData *reorder_index = NULL;
		if (([[NSFileManager defaultManager] fileExistsAtPath:reorderPath ] ) && (reorderIndex==NULL))
		{
            unsigned int count,T;
			NSArray *reorder = [[NSString stringWithContentsOfFile:reorderPath] componentsSeparatedByString:@" "];
			count = [reorder count];
			reorder_index = [NSMutableData dataWithCapacity:count*sizeof(unsigned int)];
			T = 0;
			for(i=0;i<count;i++)
			{
				T = [[reorder objectAtIndex:i] integerValue]-1;
				[reorder_index appendBytes:&T length:sizeof(T)]; 
			}
			//should check whether we are loading only a subset of the channels
			if(nchannels != count)
			{

			}
            reorderIndex = [[NSData dataWithData:reorder_index] retain];
		}
		if( reorderIndex != nil)
		{
			if( [reorderIndex length]/sizeof(unsigned int) > nchannels)
			{
				//don't use it
				[reorderIndex release];
				reorderIndex = nil;
			}
		}

        maxWaveformsDrawn = [[NSUserDefaults standardUserDefaults] integerForKey:@"maxWaveformsDrawn"]; 
        lastIndex = [[cluster indices] lastIndex];
        //if(index <  lastIndex)
        //{
        NSRange irange;
        NSUInteger *_index,nindexes;
        NSIndexSet *_indices;
        unsigned int *uindex;
        
        irange =  NSMakeRange(startIndex, endIndex-startIndex);
        //get the number of remaining indices
        nindexes = [[cluster indices] countOfIndexesInRange:irange];
        if(nindexes == 0)
        {
            return;
        }
        nindexes = MIN(nindexes,maxWaveformsDrawn);
        uindex = malloc(nindexes*sizeof(unsigned int));
        _index = malloc(nindexes*sizeof(NSUInteger));
        [[cluster indices] getIndexes:_index maxCount:nindexes inIndexRange:&irange];
        //convert to unsigned int
        for(i=0;i<nindexes;i++)
        {
            uindex[i] = (unsigned int)_index[i];
        }
        NSMutableIndexSet *tidx = [NSMutableIndexSet alloc];
		//tidx holds the indices that we want to draw
        [tidx initWithIndexSet:[[cluster indices] indexesInRange:NSMakeRange(_index[0], _index[nindexes-1]-_index[0]+1) options:NSEnumerationConcurrent passingTest:^BOOL(NSUInteger idx, BOOL *stop) {
            return YES;
        }]];
        //locate the first index
		//something fishy is going on here...
        NSUInteger fidx,sidx,qidx;
        fidx = 0;
        sidx = [[cluster indices] firstIndex];
		qidx = [tidx firstIndex];
		//the purpose of this is to establish the index of the first drawn wave in the global cluster index
		fidx = [[cluster indices] countOfIndexesInRange: NSMakeRange(sidx,qidx-sidx)];
		//now fidx is the number of indices in [cluster indices] prior to the first index in tidx, in other words, fidx is the index of the first index in tidx relative to all cluster indices
		/*
        while(sidx != NSNotFound )
        {
            sidx = [tidx indexGreaterThanIndex:sidx];
            fidx+=1;
        }
		*/
        [[self wfv] setGlobalIndices:tidx];
        [[self wfv] setFirstIndex:fidx];
        [tidx release];
        free(_index);
        _index = NULL;
        nptHeader spikeHeader;
        spikeHeader = *getSpikeInfo(path,&spikeHeader);
        if( nvalidChannels == 0)
        {
            nvalidChannels = spikeHeader.channels;
        }
        wfSize = nindexes*nvalidChannels*spikeHeader.timepts;
        waveforms = malloc(wfSize*sizeof(short int));
        if( (nchannels == nvalidChannels ) || (nchannels == 0))
        {
            waveforms = getWaves(path, &spikeHeader, uindex, nindexes, waveforms);
        }
        else if (channelValidity != NULL)
        {
            if(validChannels == NULL )
            {
                unsigned int k ;
                validChannels = malloc(nvalidChannels*sizeof(unsigned int));
                k = 0;
                for(i=0;i<nchannels;i++)
                {
                    if(channelValidity[i]==1)
                    {
                        validChannels[k] = i;
                        k+=1;
                    }
                }
            }
            waveforms = getWavesForChannels(path, &spikeHeader, uindex,nindexes,validChannels,nvalidChannels,waveforms);
        }
        fwaveforms = malloc(wfSize*sizeof(float));
        vDSP_vflt16(waveforms, 1, fwaveforms, 1, wfSize);
        free(waveforms);
        
        [[wfv window] orderFront: self];
        [wfv createVertices:[NSData dataWithBytes:fwaveforms length:wfSize*sizeof(float)] withNumberOfWaves: nindexes channels: (NSUInteger)nvalidChannels andTimePoints: (NSUInteger)spikeHeader.timepts 
                   andColor:[cluster color] andOrder:reorderIndex];
        free(fwaveforms);
        if(timestamps==NULL)
        {
            //load time stamps if not already loaded
            unsigned long long int *times = malloc(spikeHeader.num_spikes*sizeof(unsigned long long int));
            unsigned int *times_indices = malloc(spikeHeader.num_spikes*sizeof(unsigned int));
            
            for(i=0;i<spikeHeader.num_spikes;i++)
            {
                times_indices[i] = i;
            }
            times = getTimes(path, &spikeHeader, times_indices, spikeHeader.num_spikes, times);
            timestamps = [[NSData dataWithBytes:times length:spikeHeader.num_spikes*sizeof(unsigned long long int)] retain];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)times[0] forKey:@"minTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)times[rows-1] forKey:@"maxTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)rows forKey:@"numPoints"];
            free(times);
            free(times_indices);
            //add the ISI options to cluster options
            [selectClusterOption addItemWithTitle:@"Shortest ISI"];
            
        }

    //}
    }
}

- (void) loadWaveforms: (Cluster*)cluster
{
    autoLoadWaveforms = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoLoadWaveforms"];
    NSAutoreleasePool *_pool = [[NSAutoreleasePool alloc] init];
    if ( (waveformsFile == NULL) && ( autoLoadWaveforms))
    {
        int result;
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        //set a delegate for openPanel so that we can control which files can be opened
        [openPanel setDelegate:[[[OpenPanelDelegate alloc] init] autorelease]];
		[openPanel setTitle:@"Choose waveforms to load"];
        //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
        [[openPanel delegate] setBasePath: currentBaseName];
        [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"bin",nil]];
        result = [openPanel runModal];
        if( result == NSOKButton )
        {
            //test
            //Cluster *cluster = [Clusters objectAtIndex: 3];
            [self setWaveformsFile:[[openPanel URL] path]];
			[[wfv window] orderFront: self];
        }
        else if( result == NSCancelButton )
        {
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:@"autoLoadWaveforms"];
        }
    }
    if (waveformsFile != NULL)
    {
        const char *path;
        unsigned int npoints,wfSize,i;
        short int *waveforms;
        NSUInteger *idx;
        unsigned int *_idx;
        float *fwaveforms;
        
		NSString *reorderPath = [[[self waveformsFile] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
		NSMutableData *reorder_index = NULL;
		if (([[NSFileManager defaultManager] fileExistsAtPath:reorderPath ] ) && (reorderIndex==NULL))
		{
            
            unsigned int count,T;
			NSArray *reorder = [[NSString stringWithContentsOfFile:reorderPath] componentsSeparatedByString:@" "];
			count = [reorder count];
			reorder_index = [NSMutableData dataWithCapacity:count*sizeof(unsigned int)];
			T = 0;
			for(i=0;i<count;i++)
			{
				T = [[reorder objectAtIndex:i] integerValue]-1;
				[reorder_index appendBytes:&T length:sizeof(T)]; 
			}
            reorderIndex = [[NSData dataWithData:reorder_index] retain];
		}
		if( reorderIndex != nil)
		{
			if( [reorderIndex length]/sizeof(unsigned int) > nchannels)
			{
				//don't use it
				[reorderIndex release];
				reorderIndex = nil;
			}
		}
			
		
        path = [[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding];         
        npoints = [[cluster npoints] unsignedIntValue];
        //TODO: This should be made more general; for now it will just load waveforms up to the limit
        if(npoints > [[NSUserDefaults standardUserDefaults] integerForKey:@"maxWaveformsDrawn"] )
        {
            npoints = [[NSUserDefaults standardUserDefaults] integerForKey:@"maxWaveformsDrawn"];
        }
        
        nptHeader spikeHeader;
        spikeHeader = *getSpikeInfo(path,&spikeHeader);
		if( nvalidChannels == 0)
		{
			nvalidChannels = spikeHeader.channels;
		}
        wfSize = npoints*nvalidChannels*spikeHeader.timepts;
        waveforms = malloc(wfSize*sizeof(short int));
        
        idx = malloc(npoints*sizeof(NSUInteger));
        [[cluster indices] getIndexes:idx maxCount:npoints inIndexRange:nil];
        //convert to unsigned int
        _idx = malloc(npoints*sizeof(unsigned int));
        for(i=0;i<npoints;i++)
        {
            _idx[i] = (unsigned int)idx[i];
        }
        free(idx);
		
		if( (nchannels == nvalidChannels ) || (nchannels == 0))
		{
			waveforms = getWaves(path, &spikeHeader, _idx, npoints, waveforms);
		}
		else if (channelValidity != NULL)
        {
            if (validChannels == NULL)
            {
                unsigned int k ;
                validChannels = malloc(nvalidChannels*sizeof(unsigned int));
                k = 0;
                for(i=0;i<nchannels;i++)
                {
                    if(channelValidity[i]==1)
                    {
                        validChannels[k] = i;
                        k+=1;
                    }
                }
            }
			waveforms = getWavesForChannels(path, &spikeHeader, _idx,npoints,validChannels,nvalidChannels,waveforms);
		}
        //update the global index as well; this keeps track of which points within the cluster we are actually drawing. Initially, we are drawing everything up to maxWaveformsDrawn
        if(npoints > 0 )
        {
            NSMutableIndexSet *tidx = [NSMutableIndexSet alloc];
            [tidx initWithIndexSet:[[cluster indices] indexesInRange:NSMakeRange(_idx[0], _idx[npoints-1]-_idx[0]) options:NSEnumerationConcurrent passingTest:^BOOL(NSUInteger idx, BOOL *stop) {
                return YES;
            }]];
            [[self wfv] setGlobalIndices:tidx];
            [[self wfv] setFirstIndex:0];
            [tidx release];
        }

        free(_idx);
        
        //convert to float
        fwaveforms = malloc(wfSize*sizeof(float));
        vDSP_vflt16(waveforms, 1, fwaveforms, 1, wfSize);
		free(waveforms);
		
        [[wfv window] orderFront: self];
        [wfv createVertices:[NSData dataWithBytes:fwaveforms length:wfSize*sizeof(float)] withNumberOfWaves: npoints channels: (NSUInteger)nvalidChannels andTimePoints: (NSUInteger)spikeHeader.timepts 
                   andColor:[cluster color] andOrder:reorderIndex];
        //update the global indices
                [cluster setWfMean:[[self wfv] wfMean]];
        [cluster setWfCov: [[self wfv] wfStd]];
        free(fwaveforms);
        //remove this
        //we only want to update the image if we are not using overlay
        /*if([[self wfv] overlay] == NO )
        {
            aglSwapBuffers(aglGetCurrentContext());
            //[[self wfv] display];
            [cluster setWaveformsImage:[[self wfv] image]];
        }*/
        //
		nchannels = spikeHeader.channels;
		//setup self to recieve notification on feature computation
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"computeSpikeWidth" object:nil];
		if(timestamps==NULL)
        {
            //load time stamps if not already loaded
            unsigned long long int *times = malloc(spikeHeader.num_spikes*sizeof(unsigned long long int));
            unsigned int *times_indices = malloc(spikeHeader.num_spikes*sizeof(unsigned int));
        
            for(i=0;i<spikeHeader.num_spikes;i++)
            {
                times_indices[i] = i;
            }
            times = getTimes(path, &spikeHeader, times_indices, spikeHeader.num_spikes, times);
            timestamps = [[NSData dataWithBytes:times length:spikeHeader.num_spikes*sizeof(unsigned long long int)] retain];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)times[0] forKey:@"minTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)times[rows-1] forKey:@"maxTime"];
            [[NSUserDefaults standardUserDefaults] setFloat:(float)rows forKey:@"numPoints"];
			free(times);
            free(times_indices);
            //add the ISI options to cluster options
            [selectClusterOption addItemWithTitle:@"Shortest ISI"];
			
        }
		//[rasterView createVertices:timestamps];
		//[[rasterView window] orderFront:self];
	}
	[_pool drain];
		
    
}

-(id)objectInClustersAtIndex: (NSUInteger)index
{
    return [Clusters objectAtIndex:index];
}

-(void)insertObject:(Cluster *)p inClustersAtIndex:(NSUInteger)index {
    [Clusters insertObject:p atIndex:index];
}

-(void)removeObjectFromClustersAtIndex:(NSUInteger)index {
    
    [Clusters removeObjectAtIndex:index];
}
-(void)removeAllObjectsFromClusters
{
    //NSInteger state = 0;
    //state = 0;
    [Clusters makeObjectsPerformSelector:@selector(makeInactive)];
    [Clusters makeObjectsPerformSelector:@selector(makeInvalid)];
    [Clusters removeAllObjects];
}

-(void)setClusters:(NSMutableArray *)a {
    Clusters= a;
}

-(NSArray*)Clusters {
    return Clusters;
}

-(void)setClusterOptions:(NSMutableArray *)a
{
    ClusterOptions = a;
}

-(NSArray*)ClusterOptions
{
    return ClusterOptions;
}


-(void)insertObject:(NSString*)p inClusterOptionsAtIndex:(NSUInteger)index
{
 [ClusterOptions insertObject:p atIndex:index];   
}

-(void)removeObjectFromClusterOptionsAtIndex:(NSUInteger)index
{
    [ClusterOptions removeObjectAtIndex:index];
}

-(void)addClusterOption:(NSString*)option
{
    //[ClusterOptions addObject:option];
    [selectClusterOption addItemWithTitle:option];
}

-(void)ClusterStateChanged:(NSNotification*)notification
{
    if( [[notification object] isKindOfClass:[Cluster class]] == NO )
    {
        return;
    }
	//get all active clusters
	NSArray *candidates = [Clusters filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"active == 1"]];
    if( [[notification object] active] )
    {
		//reset the last operation
		[self setLastOperation: @"None"];
        [fw showCluster:[notification object]];
        [self setActiveCluster:[notification object]];
		
        //update the raster
        if( shouldShowRaster )
        {
            [[[self rasterView] window] orderFront: self];
        }
        if( [[[self rasterView] window] isVisible] )
        {
            if( [self stimInfo] == NULL )
            {
                [rasterView createVertices:[[notification object] getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[[self activeCluster] color]];
            }
            else
            {
                [rasterView createVertices:[[notification object] getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[[self activeCluster] color] andRepBoundaries:[[self stimInfo] repBoundaries]];
            }
        }
        if( shouldShowWaveforms )
        {
            [[[self wfv] window] orderFront:self];
        }
             
        if( [[[self wfv] window] isVisible] )
        {
            //check if we are adding another set of waveforms from another cluster
			if([candidates count]> 1)
            //if(( [[notification object] isEqual:selectedCluster]==NO) && (selectedCluster != nil) )
            {
                [[self wfv] setOverlay:YES];
            }
            else
            {
                [[self wfv] setOverlay:NO];
            }
            [self loadWaveforms: [notification object]];
        }
        

    }
    else 
    {
        [fw hideCluster: [notification object]];
        //also need to update raster and waveformsview; 
        //get the active clusters
        NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
        if( [candidates count] > 0 )
        {
            Cluster *candidate = [candidates objectAtIndex:0];
            if( [[[self rasterView] window] isVisible] )
            {
                if( [self stimInfo] == NULL )
                {
                    [rasterView createVertices:[candidate getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[[self activeCluster] color]];
                }
                else
                {
                    [rasterView createVertices:[candidate getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[candidate color] andRepBoundaries:[[self stimInfo] repBoundaries]];
                }
            }

            if( [[[self wfv] window] isVisible] )
            {
                //TODO: this could be modified to show the waveforms of all selected clusters
                [[self wfv] setOverlay:NO];
				[[self wfv] setNeedsDisplay: YES];
                //[self loadWaveforms: candidate];
            }
        }
        else
        {
            //No active clusters; hide both raster and waveforms view
            [[[self wfv] window] orderOut:self];
            [[[self rasterView] window] orderOut:self];
        }
        
        if([[self activeCluster] isEqualTo:[notification object]] )
        {
            //if the cluster we de-selected was the active one (i.e. last selected)
            [self setActiveCluster:nil];
        }
    }
	[clusterController setFilterPredicate: [self filterClustersPredicate]] ;
	[clusterController rearrangeObjects];
    
}

-(void)setFilterClustersPredicate:(NSPredicate *)predicate
{
    //[fw hideAllClusters];
    NSPredicate *isActive = [NSPredicate predicateWithFormat:@"active==YES and valid==YES"];
	//we want to compound the new predicate with the basic active and valid predicate
	filterClustersPredicate = [[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: isActive, predicate,nil]] retain];
    //[[Clusters filteredArrayUsingPredicate:[NSCompoundPredicate notPredicateWithSubpredicate: predicate]] makeObjectsPerformSelector:@selector(makeInactive)];
    //[allActive setState: 0];
    //Inactive those clusters for which the predicate is not true and which are already active
    [[Clusters filteredArrayUsingPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: 
	[NSCompoundPredicate notPredicateWithSubpredicate:predicate], isActive,nil]]] makeObjectsPerformSelector:@selector(makeInactive)];
    //Activate those clusters for which the predicate is true and which are inactive
    [[Clusters filteredArrayUsingPredicate: [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: 
	[NSCompoundPredicate notPredicateWithSubpredicate:isActive],predicate,nil]]] makeObjectsPerformSelector:@selector(makeActive)];
}

-(NSPredicate*)filterClustersPredicate
{
    return filterClustersPredicate;
}

-(IBAction)closeFilterClusterWindow:(id)sender
{
	//reset the predicate
	NSPredicate *predicate = [NSPredicate predicateWithFormat: @"active == YES AND valid==YES"];
	[self setFilterClustersPredicate: predicate];
	[sender orderOut: self];
}

- (IBAction) changeDim1: (id)sender
{
    //[fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
	[fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"dim", 
						  [NSNumber numberWithInt: [featureNames indexOfObject:[sender objectValueOfSelectedItem]]],@"dim_data",nil]];

}

- (IBAction) changeDim2: (id)sender
{
    //[fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
    [fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"dim", 
						  [NSNumber numberWithInt: [featureNames indexOfObject:[sender objectValueOfSelectedItem]]],@"dim_data",nil]];
	
	
}

- (IBAction) changeDim3: (id)sender
{
    //[fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:2],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
    [fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:2],@"dim", 
						  [NSNumber numberWithInt: [featureNames indexOfObject:[sender objectValueOfSelectedItem]]],@"dim_data",nil]];
	
	
}

- (IBAction) cycleDims: (id)sender
{
	if( cycleTimer == nil )
	{
		//show the cyclePanel
		if( [cyclePanel isVisible] == NO )
		{
			[cyclePanel orderFront:self];
		}
		int currentDim1 = [featureNames indexOfObject:[[ self dim1] objectValueOfSelectedItem]];
		int currentDim2 = [featureNames indexOfObject:[[self dim2] objectValueOfSelectedItem]];
		int currentDim3 = [featureNames indexOfObject:[[self dim3] objectValueOfSelectedItem]];

		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithInt:currentDim1],@"currentDim1", [NSNumber numberWithInt:currentDim2], @"currentDim2",
									 [NSNumber numberWithInt:currentDim3], @"currentDim3",nil];
		cycleTimer = [NSTimer scheduledTimerWithTimeInterval:[[self featureCycleInterval] floatValue] target:self selector:@selector(cycleDimensionsUsingTimer:) userInfo: info repeats: YES];
	}
	else 
	{
		if( [cyclePanel isVisible] == YES )
		{
			[cyclePanel orderOut:self];
		}
		//the time is already running, and we wish to stop it; do this by first invalidating the timer, then setting it to NULL
		[cycleTimer invalidate];
		cycleTimer = nil;
	}
	
}

- (IBAction) changeCycleInterval: (id)sender
{
	[self setFeatureCycleInterval:[NSNumber numberWithFloat: 1.0/([sender floatValue])]];
	//reset the timer
	[cycleTimer invalidate];
	cycleTimer = NULL;
	[self cycleDims:self];
}

-(void)cycleDimensionsUsingTimer:(NSTimer*)timer
{
	//cycles through dimensions
	//get the currently shown dimensions from the timer's userInfo object
	//the integer currentDim is a linear index indicating which features are currently being drawn
	int nrows = [featureNames count];
	int currentDim1= [[[timer userInfo] objectForKey: @"currentDim1"] intValue];
	int currentDim2= [[[timer userInfo] objectForKey: @"currentDim2"] intValue];
	int currentDim3= [[[timer userInfo] objectForKey: @"currentDim3"] intValue];
	//3 columns of features
	//int row = currentDim/3;
	//int col = currentDim % 3;
	//int row = currentDim%nrows;
	//int col = currentDim/nrows;
	//stop the time if we are at the end
	//if( (row== nrows-1) && (col ==2) )
	if( currentDim1 >= nrows-1 )
	{
		//if we have stepped through everything
		[timer invalidate];
	}
	else 
	{
		//TODO: a bit inefficient; change this
		[[self dim1] selectItemAtIndex:currentDim1];
		[[self dim1] setObjectValue:[[self dim1] objectValueOfSelectedItem]];
		[self changeDim1:[self dim1]];
		
		
		[dim2 selectItemAtIndex:currentDim2];
		[dim2 setObjectValue:[dim2 objectValueOfSelectedItem]];
		[self changeDim2:dim2];

		
		[dim3 selectItemAtIndex:currentDim3];
		[dim3 setObjectValue:[dim3 objectValueOfSelectedItem]];
		[self changeDim3:dim3];


		currentDim3+=1;
		if ( currentDim3 >= nrows )
		{
			currentDim2 +=1;
			currentDim3 = currentDim2+1;

		}
		if (currentDim2 >= nrows )
		{
			currentDim1+=1;
			currentDim2 = currentDim1+1;
			
		}
		[[timer userInfo] setObject: [NSNumber numberWithInt:currentDim1] forKey: @"currentDim1"];
		[[timer userInfo] setObject: [NSNumber numberWithInt:currentDim2] forKey: @"currentDim2"];
		[[timer userInfo] setObject: [NSNumber numberWithInt:currentDim3] forKey: @"currentDim3"];
	}
}

-(void) receiveNotification:(NSNotification*)notification
{
	if( [[notification name] isEqualToString:@"setFeatures"] )
	{
		[self setAvailableFeatures:[[notification userInfo] objectForKey:@"channels"]];
	}
	else if ( [[notification name] isEqualToString:@"computeSpikeWidth"] )
	{
		[self computeFeature:[[notification userInfo] objectForKey: @"data"] withNumberOfSpikes:[[[notification userInfo] objectForKey:@"numspikes"] unsignedIntValue] andChannels:[[[notification userInfo] objectForKey:@"channels"] unsignedIntValue]
			   andTimepoints:[[[notification userInfo] objectForKey:@"timepoints"] unsignedIntValue]];
	}
	else if ( [[notification name] isEqualToString:@"showInput" ] )
	{
		//show the input panel
		NSNumber *number = [[notification userInfo] objectForKey:@"selected"];
		//TODO: this causes a double-trigger of highlight waveforms	
		[self setSelectedWaveform: [number stringValue]];
		//
		//[inputPanel makeKeyAndOrderFront:self];
		[inputPanel orderFront:self];
	}
	else if ([[notification name] isEqualToString:@"highlight" ] )
	{
		/*
		//grab the points and convert to string
		unsigned int *points = (unsigned int*)[[[notification object] objectForKey:@"points"] bytes];
		[self setSelectedWaveform: [NSString stringWithFormat:@"%u",points[0]]];
		//check if visible
		if( [inputPanel isVisible] == NO )
		{
			[inputPanel makeKeyAndOrderFront:self];
		}*/
		//A highlight was received from waveformsview; this needs to be passed onto featureView
		/*
        if( [[notification object] isKindOfClass:[Cluster class]] )
        {
            [[self fw] highlightPoints:[notification userInfo] inCluster: [notification object]];
        }*/
        /*
		else if (([self selectedClusters] != nil) && ([[self selectedClusters] count] >= 1 ) ) 
		{
        
            [[self fw] highlightPoints:[notification userInfo] inCluster:[[self Clusters] objectAtIndex:[selectedClusters firstIndex]]];
        
		}*/
        
		//else
        //{
			//no cluster selected
            if([[[self fw] window] isVisible] )
            {
				//check if we have a cluster object in the userInfo
				Cluster *_cluster = [[notification userInfo] objectForKey: @"cluster"];
				//if we get a cluster, this is the currently selected cluster
				if( _cluster != nil )
				{
					[self setSelectedCluster: _cluster];
				}
			   [[self fw] highlightPoints:[notification userInfo] inCluster:[self selectedCluster]];
			   /*
                //check if more than one cluster is selected
                NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active==YES"]];
                if([candidates count]>0)
                {
                    BOOL found = [candidates containsObject:[self selectedCluster]];
                    if( ([candidates count] >1) || (([candidates count]==1) && (found==NO)))
                    {
                        //if we have atleast one candidate in addition to the selected cluster
                        [[self fw] highlightPoints:[notification userInfo] inCluster:nil];
                    }
                   else
                   {
                       [[self fw] highlightPoints:[notification userInfo] inCluster:[self selectedCluster]];
                   }
                }
                else
                {
                    [[self fw] highlightPoints:[notification userInfo] inCluster:[self selectedCluster]];
                }
				*/
            }
	//	}	
    }
	else if ([[notification name] isEqualToString:@"Remove points from cluster"])	
	{
		[self movePointsFromCluster: [self selectedCluster] toCluster:[Clusters objectAtIndex:0]];
	}
	else if ([[ notification name] isEqualToString: @"AdvanceTime"])
	{
		NSUInteger startTime, endTime, startIdx, endIdx,windowSize;
		//get start end end times
		startTime = [[[notification userInfo] objectForKey: @"startTime"] floatValue];
        windowSize = [[[notification userInfo] objectForKey:@"windowSize"] floatValue];
        endTime = startTime + windowSize;
		//endTime = [[[notification userInfo] objectForKey: @"endTime"] intValue];
		//check if we have loaded timestamps
		if( timestamps != NULL )
		{
			unsigned long long *_timestamps = (unsigned long long *) [timestamps bytes];
			//start and end are given in as actual time; find the correpsonding index
			unsigned int i;
			i = 0;
			while( (_timestamps[i]/1000.0 < startTime ) && (i < rows) )
			{
				i++;
			}
			startIdx = i;
			while ( (_timestamps[i]/1000.0 < endTime ) && (i < rows ) )
			{
				i++;
			}
			endIdx = i;
		}
		else
		{
			startIdx = startTime;
			endIdx = endTime;
		}
        //get the relevant indices
        /*NSIndexSet *showIndices = [[fw indexset] indexesInRange: NSMakeRange(startIdx,endIdx-startIdx) options:NSEnumerationConcurrent passingTest:^(NSUInteger idx, BOOL *stop)
        {
            return YES;
        }];
        */
		[fw showIndices: [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(startIdx,endIdx-startIdx)]];
        if([[[ self wfv] window] isVisible] )
        {
            //also update the waveforms
            //we cheat for now, i.e.
            [self updateWaveformsFromCluster:selectedCluster fromIndex:startIdx toIndex:endIdx];
            //a bit of a hack; we don't want to use firstinde here
            [wfv setFirstIndex: 0];
        }

	}
	else if ([[notification name] isEqualToString:@"loadWaveforms"])
	{
		NSUInteger startIdx,endIdx,i,k;
		NSIndexSet *_indexes;
		startIdx = [[[notification userInfo] objectForKey:@"startIdx"] unsignedIntValue];
		endIdx = [[[notification userInfo] objectForKey:@"endIdx"] unsignedIntValue];
		//these refer to the local cluster coordinates; convert to global coordinates
	    _indexes = [selectedCluster indices]; 	
		k = [_indexes firstIndex];
		i = 0;
		while( (k != NSNotFound ) && (i < startIdx))
		{
			k = [_indexes indexGreaterThanIndex: k];
			i+=1;
		}
		startIdx = k;
		while( (k != NSNotFound ) && (i < endIdx))
		{
			k = [_indexes indexGreaterThanIndex: k];
			i+=1;
		}
		if(k== NSNotFound)
		{
			k = [_indexes lastIndex];
		}
	    endIdx = k;	
		//now update the waveforms
		[self updateWaveformsFromCluster: [self selectedCluster] fromIndex: startIdx toIndex: endIdx];

	}
    else if ([[notification name] isEqualToString:@"performClusterOption"] )
	{
        if (([[[notification userInfo] objectForKey: @"option"] isEqualToString:@"Add points to cluster"]) || ( [[[notification userInfo] objectForKey:@"option"] isEqualToString:@"Move points to cluster"] ))
        {
            NSScanner *scanner = [NSScanner scannerWithString:[[notification userInfo] objectForKey:@"clusters"]];
            //skip all letters
            [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"Cluster "]];
            int clusterID;
            [scanner scanInt:&clusterID];
            
            NSArray *candidates = [[self Clusters] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"clusterId == %d",clusterID]];
            
            if( [[[notification userInfo] objectForKey:@"option"] isEqualToString:@"Move points to cluster"] )
            {
                [self movePointsFromCluster:[self selectedCluster] toCluster:[candidates objectAtIndex:0]];
            }
            else
            {
                [self addPointsToCluster: [candidates objectAtIndex:0]];
            }
			[self setLastOperation: @"Add points to cluster"];
        }
		else if ([[[notification userInfo] objectForKey:@"option"] isEqualToString:@"Remove points from cluster"])
		{
			[self movePointsFromCluster: [self selectedCluster] toCluster:[Clusters objectAtIndex:0]];		
        }
		
        
        else
        {
            //set the selected object
            //check that the option is valid
			//we don't necessarily want to do this any more
            NSUInteger idx = [[selectClusterOption itemTitles] indexOfObject:[[notification userInfo] objectForKey:@"option"]];
            if (idx != NSNotFound )
            {
                [selectClusterOption selectItemAtIndex: idx];
                [self performClusterOption:selectClusterOption];
            }
            //[[self ClusterOptions]] 
        }
	
    }
    else if ([[notification name] isEqualToString:NSUserDefaultsDidChangeNotification])
    {
        autoLoadWaveforms = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoLoadWaveforms"];
    }
	else if ([[notification name] isEqualToString:@"loadLargeWaveforms"])
	{
		unsigned int *_channels,*_idx,nidx,nchs,nclusters;
		float threshold; 
		short int _threshold;
		const char *_fname;
		_channels = (unsigned int*)[[[notification userInfo] objectForKey:@"channels"] bytes];
		nchs = [[[notification userInfo] objectForKey:@"channels"] length]/sizeof(unsigned int);
		threshold = [[[notification userInfo] objectForKey:@"threshold"] floatValue];
		_threshold = (short int)threshold;
		_fname = [[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding];
		//get the indices
		getLargeWavesForChannels(_fname,NULL,&_idx,&nidx,_channels,nchs,_threshold,NULL);
		if( Clusters == NULL)
		{
			nclusters = 0;
		}
		else
		{
			nclusters = [Clusters count];
		}
		//create a new cluster with these indices
		Cluster *_newcluster = [[Cluster alloc] init];
		[_newcluster setColor: nil];
		[_newcluster setClusterId: [NSNumber numberWithInt: nclusters]];
		[_newcluster addPoints: [NSData dataWithBytes: _idx length: nidx*sizeof(unsigned int)]];
		free(_idx);
		[self insertObject:_newcluster inClustersAtIndex:nclusters];
        [self loadWaveforms:_newcluster];
		[_newcluster release];


	}
	
}

-(void)addPointsToCluster:(Cluster*)cluster
{
    
    NSData *hpoints = [NSData dataWithData: [[self fw] highlightedPoints]];
    NSUInteger nhpoints = [hpoints length]/sizeof(unsigned int);
    [[self fw] hideCluster:selectedCluster];
    
    [selectedCluster removePoints:hpoints];
    [cluster addPoints:hpoints];
    [[self fw] setClusterColors:(GLfloat*)[[cluster color] bytes] forIndices:(unsigned int*)[[cluster points] bytes] length:nhpoints];
    [[[self fw] highlightedPoints] setLength:0];
    [[self fw] setHighlightedPoints:nil];
    
    [[self fw] showCluster:selectedCluster];
    if( [[[self wfv] window] isVisible] )
    {
        [self loadWaveforms:selectedCluster];
    }

}

-(void) setAvailableFeatures:(NSArray*)channels
{
	//sets the features based on the channels
	//unsigned nfeatures = cols;
	[[self dim1] removeAllItems];
	[[self dim2] removeAllItems];
	[[self dim3] removeAllItems];

	NSEnumerator *channelEnumerator = [channels objectEnumerator];
	unsigned int i,k;
	unsigned int *_validChannels = malloc(nvalidChannels*sizeof(unsigned int));
    k = 0;
	for(i=0;i<nchannels;i++)
	{
		if(channelValidity[i])
		{
			_validChannels[k] = i;
			k+=1;
		}
	}
	id ch;
	while( ch = [channelEnumerator nextObject] )
	{
		//NSArray *validFeatures = [featureNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS %@",[NSString stringWithFormat:@"%d",[ch intValue]+1]]];
		NSString *regexp = [NSString stringWithFormat: @"[A-Za-z]*%d",_validChannels[[ch intValue]]+1];
		NSArray *validFeatures = [featureNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES %@",regexp]];

		[[self dim1] addItemsWithObjectValues:validFeatures];
		[[self dim2] addItemsWithObjectValues:validFeatures];

		[[self dim3] addItemsWithObjectValues:validFeatures];
		
	   //[dim1 objectValueOfSelectedItem]
	}
	[[self dim1] selectItemAtIndex:0];
	//notify that soemthing changed
	[self changeDim1:[self dim1]];
	[[self dim2] selectItemAtIndex:1];
	[self changeDim2:[self dim2]];

	[[self dim3] selectItemAtIndex:2];
	[self changeDim3:[self dim3]];			
	
}

- (IBAction) changeAllClusters: (id)sender
{
    //Temporarily remove notifcations
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];
    //NSNumber *state = [NSNumber numberWithInt:[sender state]];
    
    if([sender state] == 0 )
    {
        [Clusters makeObjectsPerformSelector:@selector(makeInactive)];
        [fw hideAllClusters];
		[[fw selectedClusters] removeAllObjects];
		[self setSelectedCluster: nil];
		[[self wfv] setOverlay: NO];
    }
    else {
        [Clusters makeObjectsPerformSelector:@selector(makeActive)];
        [fw showAllClusters];
		[fw setSelectedClusters: [NSMutableArray arrayWithArray: Clusters]];
    }
   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
    
    //[Clusters makeObjectsPerformSelector:@selector(setActive:) withObject: state];
	[clusterController rearrangeObjects];
    
}

- (IBAction) clusterThumbClicked: (id)sender
{
	//never gets called
    //check if we cli
	[self loadWaveforms:[self activeCluster]];
	[[wfv window] orderFront: self];
	//make sure we also update the waverormsImage
	if([[self activeCluster] waveformsImage] == NULL)
	{
		NSImage *img = [[self wfv] image];
		[[self activeCluster] setWaveformsImage:img];
	}
	NSInteger idx = [selectClusterOption indexOfSelectedItem];
	NSString *selection = [selectClusterOption titleOfSelectedItem];
	NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Show" withString:@"Hide"];
	[selectClusterOption removeItemAtIndex:idx];
	[selectClusterOption insertItemWithTitle:new_selection atIndex:idx];
	//make sure the waveforms view receives notification of highlights
	[[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
	
	
}

- (IBAction) performClusterOption: (id)sender
{
    NSString *selection = [sender titleOfSelectedItem];
    //get all selected clusters
    NSPredicate *testForTrue = [NSPredicate predicateWithFormat:@"active == YES"];
    NSArray *candidates = [Clusters filteredArrayUsingPredicate:testForTrue];
    //set the active cluster to the first candidate
	if( [candidates count] > 0 )
	{
		[self setActiveCluster:[candidates objectAtIndex:0]];
	}
	NSLog(@"Performing cluster option %@", selection);
    if( [selection isEqualToString:@"Merge"] )
    {
		/*
        if( [candidates count] ==2 )
        {
            [self mergeCluster: [candidates objectAtIndex: 0] withCluster: [candidates objectAtIndex: 1]];
                        
        }
		*/
		if( [candidates count] > 1 )
		{
			[self mergeClusters: candidates];
		}
		[self setLastOperation: @"Merge"];
    }
    else if ( [selection isEqualToString:@"Delete"] )
    {
        NSEnumerator *clusterEnumerator = [candidates objectEnumerator];
        id aCluster;
        //turn off notifcation while we rearrange the clusters
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];

        while(aCluster = [clusterEnumerator nextObject] )
        {
            [self deleteCluster:aCluster];                                      
        }
        //restore notification alert
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ClusterStateChanged:)
                                                     name:@"ClusterStateChanged" object:nil];
        //[candidates makeObjectsPerformSelector:@selector(makeInactive)];
        //[candidates makeObjectsPerformSelector:@selector(makeInvalid)];
		[self setLastOperation: @"Delete"];
        
    }
	else if( [selection isEqualToString: @"Hide all"])
	{
		//hide all clusters

        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];
		[[self fw] hideAllClusters];
		[allActive setState:0];
		[candidates makeObjectsPerformSelector: @selector(makeInactive)];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ClusterStateChanged:)
                                                     name:@"ClusterStateChanged" object:nil];
		[self setLastOperation: @"Hide all"];
	}
	else if( [selection isEqualToString: @"Show all"])
	{
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ClusterStateChanged" object: nil];
		[[self fw] showAllClusters];
		[allActive setState: 1];
		[[self Clusters] makeObjectsPerformSelector: @selector(makeActive)];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ClusterStateChanged:)
                                                     name:@"ClusterStateChanged" object:nil];
	}
    else if ( [selection isEqualToString:@"Show waveforms"] )
    {
        [self loadWaveforms:[self activeCluster]];
		[[wfv window] orderFront: self];
        //make sure we also update the waverormsImage
        if([[self activeCluster] waveformsImage] == NULL)
        {
            NSImage *img = [[self wfv] image];
            [[self activeCluster] setWaveformsImage:img];
        }
        NSInteger idx = [sender indexOfSelectedItem];
        NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Show" withString:@"Hide"];
        [sender removeItemAtIndex:idx];
        [sender insertItemWithTitle:new_selection atIndex:idx];
        //make sure the waveforms view receives notification of highlights
        [[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
        shouldShowWaveforms = YES;

    }
    else if ( [selection isEqualToString:@"Hide waveforms"] )
    {
        NSInteger idx = [sender indexOfSelectedItem];
        NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Hide" withString:@"Show"];
        [sender removeItemAtIndex:idx];
        [sender insertItemWithTitle:new_selection atIndex:idx];
        [[NSNotificationCenter defaultCenter] removeObserver: [self wfv] name: @"highlight" object: nil];
        [[[self wfv] window] orderOut:self];
		[inputPanel orderOut:self];
        shouldShowWaveforms = NO;
        
    }
    else if( [selection isEqualToString:@"Filter clusters"] )
    {
        [filterClustersPanel orderFront: self];
    }
    else if( [selection isEqualToString:@"Sort L-ratio"])
    {
        //set the sort descript for the controller
        NSMutableArray *descriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"lRatio" ascending:NO]];
        [self setClustersSortDescriptors: descriptors];
    }
    else if( [selection isEqualToString:@"Sort Isolation Distance"])
    {
        //set the sort descript for the controller
        NSMutableArray *descriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"isolationDistance" ascending:NO]];
        [self setClustersSortDescriptors: descriptors];
		//[self setCluster: [[self Clusters] sortUsingDescriptors:descriptors]];
    }
    else if( [selection isEqualToString:@"Sort Isolation Info"] )
    {
        NSMutableArray *descriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"isolationInfo" ascending:NO]];
        [self setClustersSortDescriptors: descriptors];

    }
    else if( [selection isEqualToString:@"Compute Isolation Distance"])
    {
        [self performComputation:@"Compute Isolation Distance" usingSelector:@selector(computeIsolationDistance:)];
        
    }
    else if( [selection isEqualToString:@"Compute Isolation Info"] )
    {
        [self performComputation:@"Compute Isolation Info" usingSelector:@selector(computeIsolationInfo:)];
        //TODO: The above doesn't work for some reason, so try and run this in a normal loop for now to debug
        /*
        NSEnumerator *clusterEnumerator = [candidates objectEnumerator];
        Cluster *_cluster = [clusterEnumerator nextObject];
        while(_cluster)
        {
            [_cluster computeIsolationInfo:[[self fw] getVertexData]];
            _cluster = [clusterEnumerator nextObject];
        }*/
    }
    else if( [selection isEqualToString:@"Shortest ISI"])
    {
		unsigned int _npoints;
        unsigned int *pts;// = (unsigned int*)[[activeCluster points] bytes];
		unsigned long long int*times;
		NSUInteger *tpts;
        pts = (unsigned int*)[[activeCluster isiIdx] bytes];
        times = (unsigned long long int*)[timestamps bytes];
		_npoints = [[activeCluster npoints] unsignedIntValue];
		//get the indices
		tpts = malloc(_npoints*sizeof(NSUInteger));
		[[activeCluster indices] getIndexes: tpts maxCount: _npoints inIndexRange: nil];
        double timeScaleFactor;
        if( (pts == NULL) && (times != NULL))
        {
            [activeCluster computeISIs:timestamps];
            pts = (unsigned int*)[[activeCluster isiIdx] bytes];
        }
        //isiIdx contains the indices of the isis; the first index is the index of the shortest isi
        //only mark if the shortest ISI is less than 1000 microseconds
        timeScaleFactor = [[NSUserDefaults standardUserDefaults] doubleForKey:
                @"timeScaleFactor"];
        if( timeScaleFactor == 0 )
        {
            timeScaleFactor = 1000.0;
            [[NSUserDefaults standardUserDefaults] setDouble:timeScaleFactor forKey:@"timeScaleFactor"];
        }
        if(pts)
        {
            if ( times[tpts[pts[0]+1]]-times[tpts[pts[0]]] < 1.0*timeScaleFactor)
            {
                //check if the point is within the points shown
                NSUInteger maxWaveformsDrawn = [[NSUserDefaults standardUserDefaults] integerForKey:@"maxWaveformsDrawn"];
                if( (tpts[pts[0]+1] > [[[self wfv] globalIndices] lastIndex]) || (tpts[pts[0]] < [[[self wfv] globalIndices] firstIndex]) )
                {
                    //update the waveformsview first
                    [self updateWaveformsFromCluster:activeCluster fromIndex:tpts[pts[0]] toIndex:tpts[MIN(pts[0]+maxWaveformsDrawn,_npoints-1)]];
                    //reset the index
                    [[self wfv] setFirstIndex:pts[0]];
                }
                unsigned int *spts = malloc(2*sizeof(unsigned int));
                spts[0] = pts[0];
                spts[1] = pts[0]+1;
                NSDictionary *_params = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: [NSData dataWithBytes:spts length:2*sizeof(unsigned int)],[activeCluster color],nil] forKeys: [NSArray arrayWithObjects:@"points",@"color",nil]];
                [[NSNotificationCenter defaultCenter] postNotificationName: @"highlight" object: self userInfo: _params ];
                free(spts);
            }
        }
		free(tpts);
		//update the last operation
		[self setLastOperation: @"Shortest ISI"];
    }
    else if ( [selection isEqualToString:@"Remove waveforms"] )
    {
        
        if([fw highlightedPoints] != NULL)
        {
            //remove the currently selected waveforms
			//TODO: this could be a problem if the cluster which is selected is not the same as the one shown in the WaveformsView
            unsigned int *selected = (unsigned int*)[[fw highlightedPoints] bytes];
			unsigned int nselected,i;
			nselected = ([[fw highlightedPoints] length])/sizeof(unsigned int);
			if (nselected == 0) {
				return;
			}
			//check that the point is actually in the cluster
			for(i = 0;i < nselected;i++)
			{
				if( [[selectedCluster indices] containsIndex: selected[i]] == NO)
				{
					//if not, don't do anything:bail out
					return;
				}
			}
            //[[self activeCluster] setActive:0];
            //Cluster *_selectedCluster = [[clusterController selectedObjects] objectAtIndex:0];
			
            //BOOL toggleActive = NO;
			
			//if( [selectedCluster active] == 1 )
			//{
			//	[selectedCluster setActive:0];
			//	toggleActive = YES;
				//[fw hideCluster:selectedCluster];

			//}
			//[[Clusters objectAtIndex:0] setActive: 0];
            //[fw hideCluster:[self activeCluster]];
           
            
            [selectedCluster removePoints:[NSData dataWithBytes: selected length: nselected*sizeof(unsigned int)]];
            //recompute ISI
            //TODO: Not necessary to recompute everything here
            [selectedCluster computeISIs:timestamps];
            //add this point to the noise cluster
            [[Clusters objectAtIndex:0] addPoints:[NSData dataWithBytes: selected length: nselected*sizeof(unsigned int)]];
            //GLfloat *_color = (GLfloat*)[[[Clusters objectAtIndex:0] color] bytes];
            //GLuint *_points = (GLuint*)selected;
            //GLuint _length = nselected/sizeof(unsigned int);
            [[fw highlightedPoints] setLength:0];
			[fw setHighlightedPoints:NULL];
            //TODO: this doesnt' work if we are not drawing the full cluster. In that case, we need to remove the point from the index set. Should I then just convert everything to indexset?
            //[[fw indexset]
           	NSMutableIndexSet *_rindices = [NSMutableIndexSet indexSet]; 
			//copy the indices drawn in FeatureView
			[_rindices addIndexes: [fw indexset]];
			//remove the indices
			for(i=0;i<nselected;i++)
			{
				[_rindices removeIndex: selected[i]];
			}
			//now draw the indices
			[fw showIndices: _rindices];
            //[fw showCluster:selectedCluster];
			if([[wfv window] isVisible])
			{
				
				[wfv hideWaveforms:[wfv highlightWaves]];
				[[wfv highlightWaves] setLength: 0];
				[wfv setHighlightWaves:NULL];
				//might as well just redraw. Hell yeah!
				//[self loadWaveforms:selectedCluster];
			}
		}
        [selectedCluster setWfMean:[NSData dataWithData:[[self wfv] wfMean]]];
        [selectedCluster setWfCov:[NSData dataWithData:[[self wfv] wfStd]]];
        
        //update feature mean and covariance
        [selectedCluster computeFeatureMean: [[self fw] getVertexData]];
        [selectedCluster computeFeatureCovariance:[[self fw] getVertexData]];
        
        [[[[self fw] menu] itemWithTitle:@"Remove points from cluster"] setEnabled:NO];
		[fw setNeedsDisplay:YES];
		if([lastOperation isEqualToString: @"Shortest ISI"])
		{
			//recompute shortest ISI
			[sender selectItemWithTitle: lastOperation];
			[self performClusterOption: sender];
		}
		else
		{
			//
		}
		
    }
    else if( [selection isEqualToString:@"Make Template"] )
    {
        [candidates makeObjectsPerformSelector:@selector(makeTemplate)];
    }
    else if( [selection isEqualToString:@"Undo Template"] )
    {
        [candidates makeObjectsPerformSelector:@selector(undoTemplate)];
    }
	else if([ selection isEqualToString:@"Multi-unit"])
	{
		[candidates makeObjectsPerformSelector:@selector(makeMultiUnit)];
		NSUInteger oidx = [selectClusterOption indexOfItemWithTitle: @"Multi-unit"];
		[selectClusterOption removeItemAtIndex: oidx];
		[selectClusterOption insertItemWithTitle: @"Single-unit" atIndex: oidx];
	}
	else if([ selection isEqualToString:@"Single-unit"])
	{
		[candidates makeObjectsPerformSelector:@selector(makeSingleUnit)];
		NSUInteger oidx = [selectClusterOption indexOfItemWithTitle: @"Single-unit"];
		[selectClusterOption removeItemAtIndex: oidx];
		[selectClusterOption insertItemWithTitle: @"Single-unit" atIndex: oidx];
	}
    else if ([selection isEqualToString:@"Compute XCorr"] )
    {
        NSDictionary *dict = [[candidates objectAtIndex:0] computeXCorr:[candidates objectAtIndex:1] timepoints:timestamps];
        if(dict != NULL)
        {
            [[histView window] orderFront:self];
            [histView drawHistogram:[dict objectForKey:@"counts"] andBins:[dict objectForKey:@"bins"]];
            [histView setNeedsDisplay:YES];
        }
    }
    else if ([selection isEqualToString: @"Show raster"] )
    {
        //TODO: this is just proto-type code. Please make this more efficient
        //Cluster *_cluster = [candidates objectAtIndex:0];
        NSMutableData *ctimes = [NSMutableData dataWithCapacity:([[[self activeCluster] npoints] unsignedIntValue])*sizeof(unsigned long long int)];
        Cluster *_useCluster = nil;
        if( [self activeCluster] != nil )
        {
            _useCluster = [self activeCluster];
        }
        else if( [[self selectedClusters] count]>=1)
        {
            _useCluster = [[clusterController selectedObjects] objectAtIndex:0];
        }
        if( _useCluster != nil )
        {
            NSUInteger idx = [[_useCluster indices] firstIndex];
            while( idx != NSNotFound )
            {
                NSRange _r;
                _r.location = idx*sizeof(unsigned long long int);
                _r.length = sizeof(unsigned long long int);
                [ctimes appendData: [timestamps subdataWithRange:_r]];
                idx = [[_useCluster indices] indexGreaterThanIndex:idx];
            }
            ///register raster view for notifications
            [[NSNotificationCenter defaultCenter] addObserver:[self rasterView] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
            if( [self stimInfo] == NULL )
            {
                if([[NSUserDefaults standardUserDefaults] boolForKey:@"stimInfo"])
                {
                    //attempt to load it
                    [self loadStimInfo];
                }
            }
            if( [self stimInfo] == NULL )
            {
            
                [rasterView createVertices:ctimes withColor:[NSData dataWithData:[_useCluster color]]];
            }
            else
            {
                [rasterView createVertices:ctimes withColor:[NSData dataWithData:[_useCluster color]] andRepBoundaries:[[self stimInfo] repBoundaries]];
            }
            [[rasterView window] makeKeyAndOrderFront:self];
        }
		//replace with Hide raster
		NSUInteger oidx = [selectClusterOption indexOfItemWithTitle: @"Show raster"];
		[selectClusterOption removeItemAtIndex: oidx];
		[selectClusterOption insertItemWithTitle: @"Hide raster" atIndex: oidx];
        shouldShowRaster = YES;
    }
    else if ([selection isEqualToString: @"Hide raster"] )
	{
		[[rasterView window] orderOut: self];
		NSUInteger oidx = [selectClusterOption indexOfItemWithTitle: @"Hide raster"];
		[selectClusterOption removeItemAtIndex: oidx];
		[selectClusterOption insertItemWithTitle: @"Show raster" atIndex: oidx];
		//make sure we also prevent raster view from receiveing notifications about highlights
		[[NSNotificationCenter defaultCenter] removeObserver:[self rasterView]];
		shouldShowRaster = NO;
	}
    else if ([selection isEqualToString: @"Save clusters"] )
    {
        //check to see if the proper hierarchy exists
        //analyze waveforms file to get the different components
        NSString *sessionName = nil;
        NSString *group = nil;
        /*if( [self stimInfo] != nil )
        {
            sessionName = [stimInfo sessionName];
        }
        else
        {*/
            //have to figure out everything from the waveforms file
            //the patterns is [sessionmame][gXXXX]waveforms.bin
        NSString *baseName = [[self waveformsFile] lastPathComponent];
        NSRange _r = [baseName rangeOfString:@"waveforms"];
        
        group = [NSString stringWithFormat:@"group%@",[baseName substringWithRange:NSMakeRange(_r.location-4,4)]];
		currentGroup = [[NSString stringWithString: group] retain];
        sessionName = [baseName substringWithRange:NSMakeRange(0,_r.location-5)];
        //}
        
        NSString *clusterBasePath =  [[[self waveformsFile] stringByDeletingLastPathComponent] stringByAppendingPathComponent:group];
        //now go through the selected clusters and save them
        NSEnumerator *clusterEnumerator = [candidates objectEnumerator];
        Cluster *_useCluster = [clusterEnumerator nextObject];
        int cidx = 1;
        
        BOOL replaceAll = NO;
        //create an NSAlert instance to handle the possible file overwrites
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"Replace"];
        [alert addButtonWithTitle:@"Replace all"];
        [alert addButtonWithTitle:@"Skip"];
        [alert addButtonWithTitle:@"Skip all"];
        [alert setInformativeText:@"If you choose replace, existing data will be lost"];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        while(_useCluster )
        {
            NSString *clusterPath = [clusterBasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"cluster%.2ds", cidx]];
            [[NSFileManager defaultManager] createDirectoryAtPath:clusterPath withIntermediateDirectories:YES attributes:nil error:nil];
            clusterPath = [clusterPath stringByAppendingPathComponent:@"adjspikes.mat"];
            if( ([[NSFileManager defaultManager] fileExistsAtPath:clusterPath] ) && (replaceAll == NO) )
            {
                [alert setMessageText:[NSString stringWithFormat:@"File %@ already exists. Do you want to replace it?", clusterPath]];
                int response = [alert runModal];
                
                if(response == NSAlertSecondButtonReturn )
                {
                    replaceAll = YES;
                }
                else if (response == NSAlertThirdButtonReturn )
                {
                    //skip this cluster
                    _useCluster = [clusterEnumerator nextObject];
                    cidx+=1;
                    continue;
                }
                else if( response == NSAlertThirdButtonReturn+1 )
                {
                    //abort the loop
                    break;
                }
                
            }
            const char *fname = [clusterPath cStringUsingEncoding:NSASCIIStringEncoding];
            double *sptrain;
            int nframes,nreps,nspikes;
            nframes = [[self stimInfo] nframes];
            nreps = [[self stimInfo] nreps];
            double *framepts = (double*)[[[self stimInfo ] framepts] bytes];
            nspikes = [[_useCluster npoints] intValue];
            [_useCluster getSpiketrain:&sptrain fromTimestamps:timestamps];
            writeAdjSpikesObject(fname, framepts, nframes, sptrain, nspikes, nreps);
            free(sptrain);
            cidx+=1;
            _useCluster = [clusterEnumerator nextObject];
        }

    }
    else if ([ selection isEqualToString:@"Create cluster"] )
    {
        //use the currently selected points to create a new cluster
        NSData *clusterPoints = [[self fw] highlightedPoints];
        //only do this if we actually have highlighted some points
		NSLog(@"Creating cluster");
        if( (clusterPoints != nil) && ([clusterPoints length] != 0) )
        {
            unsigned int nclusters = [Clusters count];
            unsigned int _npoints = [clusterPoints length]/sizeof(unsigned int);
            Cluster *newCluster = [[Cluster alloc] init];
            [newCluster setClusterId:[NSNumber numberWithUnsignedInt: nclusters]];
            //the highlighted points in fw corresponds to global coordinates, so we can use them directly.
            [newCluster setPoints:[NSMutableData dataWithData:clusterPoints]];
            [newCluster setNpoints:[NSNumber numberWithUnsignedInt:[clusterPoints length]/sizeof(unsigned int)]];
            //set up color
            float *_color = malloc(3*sizeof(float));
            _color[0] = (float)random()/RAND_MAX;
            _color[1] = (float)random()/RAND_MAX;
            _color[2] = (float)random()/RAND_MAX;
            [newCluster setColor:[NSData dataWithBytes:_color length:3*sizeof(float)]];
            NSMutableIndexSet *index = [NSMutableIndexSet indexSet];
            int i;
            unsigned int* _clusterPoints = (unsigned int*)[clusterPoints bytes];
            for(i=0;i<_npoints;i++)
            {
                [index addIndex:_clusterPoints[i]];
            }
            [newCluster setIndices:index];
            [newCluster createName];
            //update the mean and covariance
            //TODO; this can be done on a separate thread
            [newCluster setFeatureDims:cols];
            [newCluster computeFeatureMean:[[self fw] getVertexData]];
            [newCluster computeFeatureCovariance: [[self fw] getVertexData]];
            //change colors in fw
            //first, remove highlights
            [[self fw] setHighlightedPoints:nil];
			[[[self fw] highlightedClusterPoints] removeAllIndexes];
            [[self fw] setClusterColors: _color forIndices:_clusterPoints length:_npoints];
             free(_color);
            [newCluster makeValid];
			[newCluster makeActive];
            //add cluster to the list
            if([self Clusters] != nil )
            {
                [self insertObject:newCluster inClustersAtIndex:nclusters];
            }
            else
            {
                [self setClusters:[NSMutableArray arrayWithObject: newCluster]];
            }
			[clusterController rearrangeObjects];
            //also add this cluster to the list of clusters in the menu
            if( [[[self clusterMenu] itemWithTitle:@"Add points to cluster"] hasSubmenu] == NO )
            {
                NSMenu *subMenu = [[[NSMenu alloc] init] autorelease];
                [[[self clusterMenu] itemWithTitle:@"Add points to cluster"] setSubmenu:subMenu];
                
            }
            [[[[self clusterMenu] itemWithTitle:@"Add points to cluster"] submenu] addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[newCluster clusterId] unsignedIntValue]] action:@selector(performClusterOption:) keyEquivalent:@""];
            //also add to move points to cluster
            if( [[[self clusterMenu] itemWithTitle:@"Move points to cluster"] hasSubmenu] == NO )
            {
                NSMenu *subMenu = [[[NSMenu alloc] init] autorelease];
                [[[self clusterMenu] itemWithTitle:@"Move points to cluster"] setSubmenu:subMenu];
                
            }
            [[[[self clusterMenu] itemWithTitle:@"Move points to cluster"] submenu] addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[newCluster clusterId] unsignedIntValue]] action:@selector(performClusterOption:) keyEquivalent:@""];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(ClusterStateChanged:)
                                                         name:@"ClusterStateChanged" object:nil];
            [newCluster release];//release since we have already added it to clusters
        }

        
    }
    else if( [selection isEqualToString:@"Add points to cluster"])
    {
        //add the currently selected points to the selected clusters (i.e. the candidates)
        NSData *clusterPoints = [[self fw] highlightedPoints];
        unsigned int _npoints = [clusterPoints length]/sizeof(unsigned int);
        unsigned int* _clusterPoints = (unsigned int*)[clusterPoints bytes];
        NSEnumerator *clusterEnumerator = [candidates objectEnumerator];
        Cluster *firstCluster = [clusterEnumerator nextObject];
        int i;
        while(firstCluster)
        {
            for(i=0;i<_npoints;i++)
            {
                [[firstCluster indices] addIndex:_clusterPoints[i]];
                [[firstCluster points] appendBytes:_clusterPoints+i length:sizeof(unsigned int)];
                [firstCluster setNpoints:[NSNumber numberWithUnsignedInt:[[firstCluster npoints] unsignedIntValue]+1]];
            }
        }
    }
    
    else if ([selection isEqualToString:@"Assign to cluster"] ) 
    {
        //loop through each cluster and compute the probability for each waveform to belong to the given cluster
        NSEnumerator *clusterEnumerator = [[self Clusters] objectEnumerator];
        Cluster *clu = [clusterEnumerator nextObject];
        int i;
        nptHeader spikeHeader;
        const char *fname = [[self waveformsFile] cStringUsingEncoding: NSASCIIStringEncoding];
        getSpikeInfo(fname, &spikeHeader);
        wavesize = (spikeHeader.timepts)*(spikeHeader.channels);
        [[self fw] hideCluster:selectedCluster];
        [[selectedCluster indices] removeAllIndexes];
        while(clu)
        {
            NSUInteger nwaves = [[clu indices] count];
            if(nwaves>0)
            {
                
                NSUInteger *idx = malloc(nwaves*sizeof(NSUInteger));
                [[clu indices] getIndexes:idx maxCount:nwaves inIndexRange:nil];
                //convert to unsigned int
                unsigned int *_idx = malloc(nwaves*sizeof(unsigned int));
                for(i=0;i<nwaves;i++)
                {
                    _idx[i] = (unsigned int)idx[i];
                }
                free(idx);
                //get the waveforms
                short *data = malloc(nwaves*wavesize*sizeof(short int));
                 getWaves(fname, &spikeHeader, _idx, nwaves, data);
                //convert to float
                float *fwaveforms = malloc(nwaves*wavesize*sizeof(float));
                vDSP_vflt16(data, 1, fwaveforms, 1, nwaves*wavesize);
                free(data);
                NSData *prob = [selectedCluster computeWaveformProbability: [NSData dataWithBytes:fwaveforms length:nwaves*wavesize*sizeof(float)] length: nwaves];
				free(fwaveforms);
				//add indexes to cluster
				double *_prob = (double*)[prob bytes];
				[[selectedCluster indices] addIndexes:[[clu indices] indexesPassingTest:^BOOL(NSUInteger idx, BOOL *stop) {
					return _prob[idx] >= 0.9;
				}]];
            }
            clu = [clusterEnumerator nextObject];
            
        }
        [selectedCluster setNpoints:[NSNumber numberWithUnsignedInt:[[selectedCluster indices] count]]];
        //TODO: get rid of this
        unsigned int _npoints = [[selectedCluster npoints] unsignedIntValue];
        NSUInteger *idx = malloc(_npoints*sizeof(NSUInteger));
        [[selectedCluster indices] getIndexes:idx maxCount:_npoints inIndexRange:nil];
        //convert to unsigned int
        unsigned int *_idx = malloc(_npoints*sizeof(unsigned int));
        for(i=0;i<_npoints;i++)
        {
            _idx[i] = (unsigned int)idx[i];
        }
        free(idx);
        [selectedCluster setPoints:[NSMutableData dataWithBytes:_idx length:_npoints*sizeof(unsigned int)]];
        free(_idx);
        [selectedCluster createName];
        //reload the cluster
        [[self fw] showCluster:selectedCluster];
        [self loadWaveforms:selectedCluster];
                
    }
    else if ([selection isEqualToString:@"Find correlated waverforms"])
    {
        //load waveforms data for selected cluster
        NSData *waveforms;
        float *fwaveforms, *sim,norm,threshold;
        dispatch_queue_t _queue;
        Cluster *_newCluster;
        unsigned nclusters,nidx;
        unsigned int *idx;
       	//get threshold from userdefaults 
		threshold = [[NSUserDefaults standardUserDefaults] floatForKey: @"waveformCorrelationThreshold"];
		if( threshold == 0)
		{
			threshold = 0.8;
			[[NSUserDefaults standardUserDefaults] setFloat: threshold forKey: @"waveformCorrelationThreshold"];

		}
        idx = (unsigned int*)[[[self wfv] highlightWaves] bytes];
        if(idx==NULL)
        {
            return;
        }
        nidx = [[[self wfv] highlightWaves] length]/(sizeof(unsigned int));
        if(wavesize==0)
        {
            nptHeader spikeHeader;
            getSpikeInfo([[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding], &spikeHeader);
            wavesize = nvalidChannels*(spikeHeader.timepts);
        }
        _queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		//TODO: make sure that the readWaveformsMethod repsects nvalidChannels
        waveforms = [selectedCluster readWaveformsFromFile:[self waveformsFile]];
        //get the currently selected waveform
        
        float *waveform = malloc(wavesize*sizeof(float));
        [waveforms getBytes:waveform range:NSMakeRange(idx[0]*wavesize*sizeof(float), wavesize*sizeof(float))];
        //compute the norm
        //compute mean
        //vDSP_meanv(waveform, 1, &m, wavesize);
        //m = -m;
        //substract mean
        //vDSP_vsadd(waveform, 1, &m, waveform, 1, wavesize);
        //compute centralized norm
        vDSP_dotpr(waveform, 1, waveform, 1, &norm, wavesize);
        norm = sqrtf(norm);
        //now, loop through each cluster and find the waves that are correlated with this wave
        NSMutableIndexSet *correlatedIdx = [NSMutableIndexSet indexSet];
        NSEnumerator *clusterEn = [Clusters objectEnumerator];
        Cluster *clu;
        //[waveforms release];
        while(clu = [clusterEn nextObject] )
        {
            nidx = [[clu npoints] unsignedIntValue];
            waveforms = [clu readWaveformsFromFile:[self waveformsFile]];
            fwaveforms = (float*)[waveforms bytes];
            sim = malloc(nidx*sizeof(float));
            //compute the cosine between each waveform
            dispatch_apply(nidx, _queue, ^(size_t i) {
                //compute dot product
                float d,_n;
                //vDSP_meanv(fwaveforms+i*wavesize, 1, &_m, wavesize);
                //_m = -_m;
                //vDSP_vsadd(fwaveforms+i*wavesize, 1, &_m, fwaveforms+i*wavesize, 1, wavesize);
                vDSP_dotpr(waveform, 1, fwaveforms+i*wavesize, 1, &d, wavesize);
                vDSP_dotpr(fwaveforms+i*wavesize,1,fwaveforms+i*wavesize,1,&_n,wavesize);
                sim[i] = d/(norm*sqrt(_n));  
            });
            [correlatedIdx addIndexes:[[clu indices] indexesPassingTest:^BOOL(NSUInteger idx, BOOL *stop) {
                return sim[idx] >= threshold;
            }]];
             free(sim);

        }
		if( [correlatedIdx count] >= 2)
		{
			//now we have a bunch of indices from which we can create a new cluster
			_newCluster = [[Cluster alloc] init];
					
			nclusters = [[self Clusters] count];
			[_newCluster setClusterId:[NSNumber numberWithUnsignedInt: nclusters]];
			[_newCluster addIndices:correlatedIdx];
			[_newCluster setTotalNPoints: [NSNumber numberWithUnsignedInt: rows]];
			GLfloat *_color = malloc(3*sizeof(GLfloat));
			_color[0] = ((float)random())/RAND_MAX;
			_color[1] = ((float)random())/RAND_MAX;
			_color[2] = ((float)random())/RAND_MAX;
			[_newCluster setColor:[NSData dataWithBytes:_color length:3*sizeof(GLfloat)]];
			free(_color);
			[_newCluster setFeatureDims: cols];
			[_newCluster computeFeatureMean:[[self fw] getVertexData]];
			[_newCluster makeValid];
			[self insertObject:_newCluster inClustersAtIndex:nclusters];
			[_newCluster makeActive];
		}
    }
    else if( [selection isEqualToString:@"Split among clusters"] )
    {
        Cluster *useCluster, *tmpCluster;
        unsigned int _npoints,*_points,ncandidates,c,q;
        int cid;
        double *_p,threshold,_d,_pp;
        NSData *cfData,*belonginess;
        //use threshold of 0.95
        threshold = 0.95;
        //get the vertex data corresponding to this cluster
        ncandidates = [candidates count];
        useCluster = [self selectedCluster];
        _points = (unsigned int*)[[useCluster points] bytes];
        _npoints = [[useCluster npoints] unsignedIntValue];
        //array to hold the probabilities
        _p = calloc(_npoints*ncandidates,sizeof(double));
        //get the feature data for this cluster
        cfData = [useCluster getRelevantData:[[self fw] getVertexData] withElementSize:sizeof(float)];
        NSEnumerator *clusterEmurator = [candidates objectEnumerator];
        c = 0;
        while( (tmpCluster = [clusterEmurator nextObject]) )
        {
            //compute the probabilty of points for this cluster
            belonginess = [tmpCluster computeBelonginess:cfData];
            if(belonginess != NULL)
            {
                //copy the probabilities so that we can compare them later
                [belonginess getBytes:_p+c*_npoints length:_npoints*sizeof(double)];
            }
            c+=1;

        }
        //now loop through the probabilities
        for(c=0;c<_npoints;c++)
        {
            _d = -1.0;
            cid = -1;
            for(q=0;q<ncandidates;q++)
            {
                _pp = _p[q*_npoints+c];
                if( (_pp > _d) && (_pp > threshold) )
                {
                    _d = _pp;
                    cid = q;
                }
            }
            if(cid > -1 )
            {
                //we have a match, so add the point to the matching cluster
                tmpCluster = [candidates objectAtIndex:cid];
                [tmpCluster addPoints:[NSData dataWithBytes:_points+c length:sizeof(unsigned int)]];
                NSLog(@"Assigned 1 point to cluster %d with probability %.2f", cid,_d);
                
            }
        }
        //we don't need _p anymore
        free(_p);
    }
    else if( [selection isEqualToString:@"Screen waveforms"] )
    {
        NSData *cfData,*belonginess;
        NSMutableData *screenIdx;
        double *_p,threshold;
        NSUInteger _npoints,i;
        threshold = 0.05;
        //get the feature data for this cluster
        //cfData = [[self selectedCluster] getRelevantData:[[self fw] getVertexData] withElementSize:sizeof(float)];
        //compute belonginess
        belonginess = [[self selectedCluster] computeBelonginess:[[self fw] getVertexData]];
		if( belonginess != NULL)
		{
			_npoints = [[[self selectedCluster] npoints] unsignedIntValue];
			_p = (double*)[belonginess bytes];
			//the find points for which the belonginess is less than or equal to the threshold
			screenIdx = [NSMutableData dataWithCapacity:_npoints*sizeof(unsigned int)];
			for(i=0;i<_npoints;i++)
			{
				if( _p[i] < threshold )
				{
					[screenIdx appendBytes:&i length:sizeof(unsigned int)];
				}
			}
			//send a notificaiton to highlight
			[[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:self userInfo:[NSDictionary dictionaryWithObject:screenIdx forKey:@"points"]];
        
		} 
		else
		{
			//Notify that something went wrong
			NSLog(@"Could not compute belonginess for cluster");
		}

    }
	else if( [selection isEqualToString: @"Find best projection"])
	{
		//find the best 3d projection 
		unsigned int i,j,k,*dims,*combis,nclusters,m,*_npoints,s,l;
		int *cluster_indices,npoints,cid;
		double _isoD,isoDmin,bestV;
		float *_means,*_data,*_fmeans,*d,*D,q;
		NSData *vdata, *fdata;
        NSArray *candidates; 
		NSEnumerator *clusterEnum;
		Cluster *cluster;	

		dims = malloc(3*sizeof(unsigned int));
		candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
		nclusters = [candidates count];
		//combis = malloc(3*sizeof(unsigned int));
		//bestV = -HUGE_VAL;
		//gather cids for all selected clusters
        cluster_indices = calloc((params.rows+1),sizeof(int));    
        cluster_indices[0] = (unsigned int)[candidates count];
        NSEnumerator *cluster_enumerator = [[candidates filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"valid==1"]] objectEnumerator];
        cid = 1;
		_means = malloc(nclusters*cols*sizeof(float));
		_npoints = malloc(nclusters*sizeof(unsigned int));
        while( cluster = [cluster_enumerator nextObject] )
        {
            unsigned int *clusteridx = (unsigned int*)[[cluster points] bytes];
            npoints = [[cluster npoints] intValue];
            for(i=0;i<npoints;i++)
            {
                cluster_indices[clusteridx[i]+1] = cid;
            }
			//copy the mean
			memcpy(_means+(cid-1)*cols,(float*)[[cluster mean] bytes],cols*sizeof(float));
			_npoints[cid-1] = [[cluster npoints] unsignedIntValue];
            cid+=1;

        }
		//compute isolation distance
		_data = (float*)[[[self fw] getVertexData] bytes];
		computeIsolationDistance(_data,_means,rows,cols,cluster_indices,nclusters,_npoints,dims,&bestV);
				//update dimensions
		NSLog(@"Best isolation distance: %.3f", bestV);
		[dim1 selectItemAtIndex:dims[0]];
		[dim1 setObjectValue:[dim1 objectValueOfSelectedItem]];
		[self changeDim1:dim1];

		[dim2 selectItemAtIndex:dims[1]];
		[dim2 setObjectValue:[dim2 objectValueOfSelectedItem]];
		[self changeDim2:dim2];

		[dim3 selectItemAtIndex:dims[2]];
		[dim3 setObjectValue:[dim3 objectValueOfSelectedItem]];
		[self changeDim3:dim3];
		free(_means);
		free(_npoints);
        free(dims);
	}
    else if( [selection isEqualToString:@"Show cluster notes"] )
    {
        [[self clusterNotesPanel] orderFront:self];
    }
	else if( [selection isEqualToString: @"Resolve overlaps"])
	{
		//TODO: Interface with the matlab function hmm_decode, which runs an HMM decoder using the selected clusters as templates
		//check that we have the matlab script
		//first we need to save the clusters
		[self saveClusters: self];
		NSTask *hmmTask = [[NSTask alloc] init];
		NSString *hmmPath = [@"~/Documents/research/code/hmmsort/run_hmm_decode.sh" stringByExpandingTildeInPath];
		NSInteger result;
		if( [[NSFileManager defaultManager] fileExistsAtPath:hmmPath] == NO )
		{
			NSOpenPanel *_openPanel = [NSOpenPanel openPanel];
			[_openPanel setTitle: @"Please specify the path to the hmm script"];
			result = [_openPanel runModal];
			if( result == NSFileHandlingPanelOKButton)
			{
				hmmPath = [[[_openPanel URLs] objectAtIndex: 0] path];
			}
		}
		if( currentHighpassFile == nil )
		{
			NSOpenPanel *_openPanel = [NSOpenPanel openPanel];
			[_openPanel setTitle: @"Specify the path to the highpass file"];
			result = [_openPanel runModal];
			if( result == NSFileHandlingPanelOKButton)
			{
				currentHighpassFile = [[[[_openPanel URLs] objectAtIndex: 0] path] retain];
			}
		}

		[hmmTask setCurrentDirectoryPath: currentDir];
		[hmmTask setLaunchPath: hmmPath];
		[hmmTask setArguments: [NSArray arrayWithObjects: @"/Applications/MATLAB_R2010a.app/",
			@"patchLength",@"200000",
			@"p",@"1e-10",@"Group", currentGroup, @"SourceFile",
			currentHighpassFile,@"save",nil]];
		//start the task
		[hmmTask launch];
	}
                                                                                 
}

- (IBAction) saveClusters:(id)sender
{
    //Need to get the points of each cluster, and use those points as indexes for which the point is the
    //cluster number
    //create an array to hold the indices
    //make sure there are clusters to save
    //only save clusters that are active
    NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
    if ([candidates count] > 0)
    {
        NSString *clusterDescriptionString;
        NSMutableArray *clusterDescriptions = [NSMutableArray arrayWithCapacity:[candidates count]];
        int* cluster_indices = calloc((params.rows+1),sizeof(int));
        cluster_indices[0] = (unsigned int)[candidates count];
        NSEnumerator *cluster_enumerator = [[candidates filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"valid==1"]] objectEnumerator];
        int i,npoints,cid;
        id cluster;
        cid = 1;
        while( cluster = [cluster_enumerator nextObject] )
        {
            unsigned int *clusteridx = (unsigned int*)[[cluster points] bytes];
            npoints = [[cluster npoints] intValue];
            for(i=0;i<npoints;i++)
            {
                cluster_indices[clusteridx[i]+1] = cid;
            }
            cid+=1;
            //add the description of this cluster to the description array
            [clusterDescriptions addObject:[cluster description]];
        }
        clusterDescriptionString = [clusterDescriptions componentsJoinedByString:@"\n"];
		NSLog(@"currentBaseName = %@", currentBaseName);
		NSString *clusterFileName = [NSString stringWithFormat: @"%@.cut",currentBaseName];
		//check if the file already exists; if so, open a dialog box to choose a new file name	
		if( ([[NSFileManager defaultManager] fileExistsAtPath: clusterFileName]) || currentBaseName == NULL )
		{
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[savePanel setNameFieldStringValue: clusterFileName];
			
			NSInteger result = [savePanel runModal];
			if(result == NSFileHandlingPanelOKButton )
			{
				clusterFileName = [[savePanel URL] path];
				if( currentBaseName == NULL )
				{
					NSRange range = [[[[savePanel URL] path] lastPathComponent] rangeOfString:@"_" options:NSBackwardsSearch];
					NSString *filebase = [[clusterFileName lastPathComponent] substringToIndex:range.location]; 
					[self setCurrentBaseName: filebase];
				}
			}
		}
		NSString *ext = [clusterFileName pathExtension];
		const char *fname = [clusterFileName cStringUsingEncoding:NSASCIIStringEncoding];
		int res = 0;
		if([ext isEqualToString:@"cut"])
		{
			res = writeCutFile(fname, cluster_indices+1, params.rows);
		}
		else
		{
			NSRange r = [clusterFileName rangeOfString:@"clu"];
			if(r.location != NSNotFound )
			{
				res = writeCutFile(fname, cluster_indices, params.rows+1);
			}
		}

		//check that we can write to the file
		if( res < 0 )
		{
			NSAlert *_alert = [[NSAlert alloc] init];
			[_alert setMessageText: @"Sorry, but you do not appear to have permission to write to this file"];
			NSInteger response = [_alert runModal];
			[_alert release];

		}
		//save cluster info to string
		[clusterDescriptionString writeToFile:[clusterFileName stringByReplacingOccurrencesOfString:ext withString:@"info"] atomically:YES encoding:NSASCIIStringEncoding error:nil];
            
        free(cluster_indices);
        //[cidx_string writeToFile:[NSString stringWithFormat: @"%@.cut",currentBaseName] atomically:YES];
        //now write a file containing the template clusters
        
        NSArray *templates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"isTemplate==1"]];
        NSEnumerator *templateEnumerator = [templates objectEnumerator];
        NSMutableArray *templateIds = [NSMutableArray arrayWithCapacity:[templates count]];
        id template;
        while( template = [templateEnumerator nextObject] )
        {
            [templateIds addObject:[NSString stringWithFormat: @"%d",[[template clusterId] intValue]]];
        }
        NSString *templateIdStr = [templateIds componentsJoinedByString:@"\n"];
		NSString *templateClusterFile = [NSString stringWithFormat: @"%@.scu",currentBaseName];
		//check if file exists
		if( [[NSFileManager defaultManager] fileExistsAtPath:templateClusterFile])
		{
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[savePanel setNameFieldStringValue:templateClusterFile];
			[savePanel beginWithCompletionHandler:^(NSInteger result) 
			 {
				 if(result == NSFileHandlingPanelOKButton )
				 {
					 [templateIdStr writeToFile: [[savePanel URL] path] atomically:YES];
				 }
			 }];
		}
		else
		{
					 [templateIdStr writeToFile: templateClusterFile atomically:YES];
		}
        //[templateIdStr writeToFile:[NSString stringWithFormat:@"%@.scu",currentBaseName] atomically:YES];
        
        //also store the data
        
        [self archiveClusters:self];
    }
}


-(IBAction)saveTemplates:(id)sender
{
    NSArray *templates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"isTemplate==1"]];
    if([templates count] == 0 )
    {
        return;
    }
    NSEnumerator *templateEnumerator = [templates objectEnumerator];
    NSMutableArray *templateIds = [NSMutableArray arrayWithCapacity:[templates count]];
    id template;
    while( template = [templateEnumerator nextObject] )
    {
        [templateIds addObject:[NSString stringWithFormat: @"%d",[[template clusterId] intValue]]];
    }
    NSString *templateIdStr = [templateIds componentsJoinedByString:@"\n"];
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:[NSString stringWithFormat: @"%@.scu",currentBaseName]];
    [savePanel beginWithCompletionHandler:^(NSInteger result) 
     {
         if(result == NSFileHandlingPanelOKButton )
         {
             [templateIdStr writeToFile:[[[savePanel directoryURL] path] stringByAppendingPathComponent: [savePanel nameFieldStringValue]] atomically:YES];
         }
     }];

    
}

- (IBAction)saveFeatureSpace:(id)sender
{
	//save an image of the currently shown figures space
	//show a panel to choose to file to save to
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	//set the suggested file name
	[savePanel setNameFieldStringValue: [NSString stringWithFormat:@"%@.tiff",currentBaseName]];
	//show the panel
	[savePanel beginSheetModalForWindow: [fw window] completionHandler: ^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSData *image = [[fw image] TIFFRepresentation];
			[image writeToFile:[[savePanel URL] path] atomically:YES];
		}
	}];
		
}

-(void)mergeClusters:(NSArray*)clusters
{
	float color[3];
	float *_mean,*_clmean;
	unsigned int i,_clnpoints, nclusters;
	NSMutableString *clusterNames;
	nclusters = [clusters count];
	clusterNames = [NSMutableString stringWithCapacity: 2*nclusters];
    Cluster *new_cluster = [[Cluster alloc] init];
    new_cluster.clusterId = [NSNumber numberWithUnsignedInt:[Clusters count]];
	[new_cluster setTotalNPoints: [NSNumber numberWithUnsignedInt:rows]];
	//loop through clusters
	NSEnumerator *clusterEnumerator = [clusters objectEnumerator];
	Cluster *cl;
	_mean = calloc(cols,sizeof(float));
	while(( cl = [clusterEnumerator nextObject]))
	{
		//add the points to the cluster
		[new_cluster addPoints: [cl points]];
		//make the cluster inactive
		[cl makeInactive];
		//make the cluster invalid; this means it will effectively disappear from the view
		[cl makeInvalid];
		//update the mean
		_clmean = (float*)[[cl mean] bytes];
		_clnpoints = [[cl npoints] unsignedIntValue];
		if(_clmean != NULL )
		{
			for(i=0;i<cols;i++)
			{
				_mean[i]+=_clmean[i]*_clnpoints;
			}
		}
		//add to clusterNames
		[clusterNames appendFormat: @"%@ ", [cl clusterId]];
		
	}
	_clnpoints = [[new_cluster npoints] unsignedIntValue];
	
	for(i=0;i<cols;i++)
	{
		_mean[i] /=_clnpoints; 
	}
	[new_cluster setMean: [NSData dataWithBytes: _mean length: cols*sizeof(float)]];
	[new_cluster setFeatureDims: cols];
	free(_mean);
	//compute covariance matrix; this could also be done incrementally
	[new_cluster computeFeatureCovariance:[[self fw] getVertexData]];
	//set the color
	color[0] = (float)random()/(float)RAND_MAX;
	color[1] = (float)random()/(float)RAND_MAX;
	color[2] = (float)random()/(float)RAND_MAX;
	[new_cluster setColor:[NSData dataWithBytes: color length: 3*sizeof(float)]];
	[new_cluster makeValid];
    [new_cluster computeISIs: timestamps];
 	//set parents	
	[new_cluster setParents: [NSMutableArray arrayWithArray: clusters]];
    nclusters = [Clusters count];
	
    [self insertObject:new_cluster inClustersAtIndex:nclusters];
	if( dataloaded == YES)
	{
		//only do this if data has been loaded; should probably try to make this a bit more general
		[fw setClusterColors:(GLfloat*)[[new_cluster color] bytes] forIndices:(unsigned int*)[[new_cluster points] bytes] length:[[new_cluster npoints] unsignedIntValue]];
	}
    new_cluster.active = 1;
    //make sure we also updated the waveforms image
    [self loadWaveforms: new_cluster];
    //make sure we also update the waverormsImage
    if([new_cluster waveformsImage] == NULL)
    {
        NSImage *img = [[self wfv] image];
        [new_cluster setWaveformsImage:img];
    }
    //make the new cluster the currently selected
    [self setSelectedClusters:[NSIndexSet indexSetWithIndex:nclusters]];
    selectedCluster = new_cluster;
	//reset selection
	[[[self fw] highlightedClusterPoints] removeAllIndexes];
	//record in log
	freopen([ logFilePath cStringUsingEncoding: NSASCIIStringEncoding],"a+",stderr);
	NSLog(@"merged clusters %@ to form cluster %@", clusterNames, [new_cluster clusterId]);
	//update the cluster menus
	NSMenu *addToClustersMenu, *moveToClustersMenu;
    addToClustersMenu = [[[self clusterMenu] itemWithTitle:@"Add points to cluster"] submenu];
    moveToClustersMenu = [[[self clusterMenu] itemWithTitle:@"Move points to cluster"] submenu];
	[addToClustersMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[new_cluster clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];
	[moveToClustersMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[new_cluster clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];

}

-(void)mergeCluster: (Cluster *)cluster1 withCluster: (Cluster*)cluster2
{
    Cluster *new_cluster = [[Cluster alloc] init];
    //new_cluster.name = [[cluster1.name stringByAppendingString: @"+"] stringByAppendingString:cluster2.name];
    //set the new cluster id to the previous number of clusters
    new_cluster.clusterId = [NSNumber numberWithUnsignedInt:[Clusters count]];
    new_cluster.npoints = [NSNumber numberWithUnsignedInt: [[cluster1 npoints] unsignedIntValue] + [[cluster2 npoints] unsignedIntValue]];
    NSMutableData *points = [NSMutableData dataWithCapacity:[[new_cluster npoints] unsignedIntValue]*sizeof(unsigned int)];
    new_cluster.name = [[[[[[cluster1 clusterId] stringValue] stringByAppendingString:@"+"] stringByAppendingString:[[cluster2 clusterId] stringValue]]
                         stringByAppendingString:@":"] stringByAppendingString:[[new_cluster npoints] stringValue]];
    [points appendData:cluster1.points];
    [points appendData:cluster2.points];
    new_cluster.points = points;
    [new_cluster setIndices:[[NSMutableIndexSet alloc] initWithIndexSet:[cluster1 indices]]];
    [[new_cluster indices] addIndexes:[cluster2 indices]];
    //set the new cluster color to that of the first cluster
    NSData *new_color = [cluster1 color];
    [new_cluster setColor: new_color];
    new_cluster.valid = 1;
    //new_cluster.color[0] = cluster1.color[0];
    //new_cluster.color[0] = cluster1.color[0];
    //add the cluster to the list of clusters
    //compute ISI
    [new_cluster computeISIs: timestamps];
    //set the valid flag of the two component clusters to 0
    //cluster1.valid = 0;
    cluster1.active = 0;
    //cluster2.valid = 0;
    cluster2.active = 0;
    //update cluster mean
    float *_mean1,*_mean2,*_mean12;
    _mean12 = malloc(cols*sizeof(float));
    unsigned int _npoints1,_npoints2,i;
    _mean1 = (float*)[[cluster1 mean] bytes];
    _npoints1 = [[cluster1 npoints] unsignedIntValue];
    _mean2 = (float*)[[cluster2 mean] bytes];
    _npoints2 = [[cluster2 npoints] unsignedIntValue];
    //add the two means after scaling by the respective number of points
    for(i=0;i<cols;i++)
    {
        _mean12[i] = (_npoints1*_mean1[i] + _npoints2*_mean2[i])/(_npoints1+_npoints2);
    }
    [new_cluster setMean:[NSData dataWithBytes:_mean12 length:cols*sizeof(float)]];
    free(_mean12);
    //do the same for covariance matrix
    //just use the same variables as above
    _mean1 = (float*)[[cluster1 cov] bytes];
    _mean2 = (float*)[[cluster2 cov] bytes];
    _mean12 = malloc(cols*cols*sizeof(float));
    for(i=0;i<cols*cols;i++)
    {
        _mean12[i] = (_npoints1*_mean1[i] + _npoints2*_mean2[i])/(_npoints1+_npoints2);
    }
    [new_cluster setCov:[NSData dataWithBytes:_mean12 length:cols*cols*sizeof(float)]];
    //[self insertObject:new_cluster inClustersAtIndex:[Clusters indexOfObject: cluster1]];
    //set the new cluste colors
    int nclusters = [Clusters count];
    new_cluster.parents = [NSArray arrayWithObjects:cluster1,cluster2,nil];
    
	if( dataloaded == YES)
	{
		//only do this if data has been loaded; should probably try to make this a bit more general
		[fw setClusterColors:(GLfloat*)[[new_cluster color] bytes] forIndices:(unsigned int*)[[new_cluster points] bytes] length:[[new_cluster npoints] unsignedIntValue]];
	}
    new_cluster.active = 1;
    //make sure we also updated the waveforms image
    [self loadWaveforms: new_cluster];
    //make sure we also update the waverormsImage
    if([new_cluster waveformsImage] == NULL)
    {
        NSImage *img = [[self wfv] image];
        [new_cluster setWaveformsImage:img];
    }
    //make the new cluster the currently selected
    [self setSelectedClusters:[NSIndexSet indexSetWithIndex:nclusters]];
    [self insertObject:new_cluster inClustersAtIndex:nclusters];
    selectedCluster = [[self Clusters] objectAtIndex:nclusters];
    [new_cluster release];//release this since we have already added it to clusters
}

-(void)deleteCluster: (Cluster *)cluster
{
    [cluster makeInactive];
    [cluster makeInvalid];
    //since we want to maintain contigous order, shift the other clusters accordingly
    NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"clusterId>%d", [[cluster clusterId] unsignedIntValue]]];
    [candidates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSUInteger cid = [[obj clusterId] unsignedIntValue];
        [obj setClusterId:[NSNumber numberWithUnsignedInt: cid-1]];
		//update the name as well
		[obj createName];
    }];
    
    NSEnumerator *parentsEnumerator = [[cluster parents] objectEnumerator];
    Cluster *parent;
    while(parent = [parentsEnumerator nextObject] )
    {
        //restore previous cluster colors
        [fw setClusterColors: (GLfloat*)[[parent color] bytes] forIndices: (GLuint*)[[parent points] bytes] length:[[parent npoints] unsignedIntValue]];
        [parent makeValid];
    }
    [fw hideCluster:cluster];
    //give the points back to the noise cluster
    [[Clusters objectAtIndex:0] addPoints:[cluster points]];
    [self removeObjectFromClustersAtIndex: [Clusters indexOfObject:cluster]];
	NSLog(@"deleted cluster %@", [cluster clusterId]);
	//update the cluster menu
	NSMenu *addToClustersMenu, *moveToClustersMenu;
    addToClustersMenu = [[[self clusterMenu] itemWithTitle:@"Add points to cluster"] submenu];
    moveToClustersMenu = [[[self clusterMenu] itemWithTitle:@"Move points to cluster"] submenu];
	//rebuild the menus
	[addToClustersMenu removeAllItems];
	[Clusters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        [addToClustersMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[obj clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];
	}];
	[moveToClustersMenu removeAllItems];
	[Clusters enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        [moveToClustersMenu addItemWithTitle:[NSString stringWithFormat:@"Cluster %d", [[obj clusterId] intValue] ] action:@selector(performClusterOption:) keyEquivalent:@""];
	}];

	//record in log
	freopen([ logFilePath cStringUsingEncoding: NSASCIIStringEncoding],"a+",stderr);
}

- (void)keyDown:(NSEvent *)theEvent
{
    //capture key event, rotate view : left/right -> y-axis, up/down -> x-axis
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    }
	else if ([[theEvent characters] isEqualToString: @"p"])
	{
		//setup a timer that will cycle through the different feature dimensions
		//NSTimer *_timer = [NSTimer scheduledTimerWithTimeInterval:1 target: fw selector:@selector(selectDimensions:) userInfo: nil repeats:YES];
	}
	/*
	else if ([NSNumberFormatter numberFromString: [theEvent characters]] != nil )
	{
		//typed in a number; interpret as choosing waveforms, show waveforms chooser
		[self setSelectedWaveform: [NSNumberFormatter numberFromString: [theEvent characters]]];
		//show the panel
		[ inputPanel orderFront:self];
	}*/
	else {
        [self keyDown:theEvent];
    }
}

-(void)readClusterModel:(NSString*)path
{
    NSString *contents = [NSString stringWithContentsOfFile:path];
    NSArray *lines = [contents componentsSeparatedByString:@"\n"];
    
    //NSScanner *scanner = [ NSScanner scannerWithString:[lines objectAtIndex:2]];
    //NSMutableArray *items = [NSMutableArray arrayWithCapacity:3];
    NSDictionary *dict = [NSDictionary dictionaryWithObjects: [[lines objectAtIndex:2] componentsSeparatedByString:@" "]                                                      forKeys: [NSArray arrayWithObjects:@"ndim",@"nclusters",@"npoints",nil]];
    //the second line contains the scaling
    int nclusters = [[dict valueForKey:@"nclusters"] intValue];
    int ndim = [[dict valueForKey:@"ndim"] intValue];
    int linesPerCluster = ndim+2;
    int i,j,k;
    float *mean = malloc(ndim*sizeof(float));
    float *cov = malloc(ndim*ndim*sizeof(float));
    float det = 0;
    //NSMutableArray *clusterParams = [NSMutableArray arrayWithCapacity:nclusters];
    for(i=0;i<nclusters;i++)
    {
        //NSMutableDictionary *cluster = [NSMutableDictionary dictionaryWithCapacity:3];
        //[cluster setObject: [NSNumber numberWithFloat: [[[[lines objectAtIndex: 3+i*linesPerCluster] componentsSeparatedByString: @" "] objectAtIndex: 1] floatValue]] forKey:@"Mixture"];
        NSScanner *meanScanner = [NSScanner scannerWithString:[lines objectAtIndex:3+i*linesPerCluster+1]];
        
        j = 0;
        while ( [meanScanner isAtEnd] == NO)
        {
            [meanScanner scanFloat:mean+j];
            j+=1;
        }
        //[cluster setObject: [NSData dataWithBytes: mean length: ndim*sizeof(float)] forKey: @"Mean"];
        [[Clusters objectAtIndex:i] setFeatureDims:ndim];
        [[Clusters objectAtIndex:i] setMean: [NSData dataWithBytes: mean length: ndim*sizeof(float)]];
        //now do covariance matrix
        NSRange range;
        range.location = 3+i*linesPerCluster+2;
        range.length = ndim;
        NSScanner *covScanner = [NSScanner scannerWithString: [[lines subarrayWithRange: range] componentsJoinedByString:@" "]];
        j = 0;
        
        while ( [covScanner isAtEnd] == NO )
        {
            [covScanner scanFloat:cov+j];
            j+=1;
        }
        //we only get the lower triangular part
        for(j=0;j<ndim;j++)
        {
            for(k=0;k<ndim;k++)
            {
                cov[j*ndim+k] = cov[k*ndim+j];
            }
        }
        //[cluster setObject: [NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)] forKey: @"Cov"];
        [[Clusters objectAtIndex:i] setCov:[NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)]];
        //compute inverse covariance matrix
		//int sign;
        //int status = matrix_inverse(cov, ndim, &det,&sign);
        //[cluster setObject: [NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)] forKey: @"Covi"];
        //[[Clusters objectAtIndex:i] setCovi:[NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)]];
        //[[Clusters objectAtIndex:i] setDet:det];
        //   [[Clusters objectAtIndex:i] computeBelonginess:[[self fw] getVertexData]];
        //[cluster setObject: [NSNumber numberWithUnsignedInteger: i] forKey: @"ID"];
        //[clusterParams addObject:cluster];
        //we can now go ahead and compute the L-ratio for this cluster
    }
    free(mean);
    free(cov);
    
}
-(void)performComputation:(NSString*)operationTitle usingSelector:(SEL)operationSelector
{
    //set up an operation that will notify the main thread when all the computational tasks have finished
    //TODO: For some reason, this doesn't work. I get a SIGABRT for the allFinished task. Weird
    
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget: self selector:@selector(addClusterOption:) object: 
                       [operationTitle stringByReplacingOccurrencesOfString:@"Compute" withString:@"Sort"]];
    //[op setIsConcurrent]
    NSInvocationOperation *allFinished = [[NSInvocationOperation alloc] initWithTarget:progressPanel selector:@selector(stopProgressIndicator) object:nil];
    [allFinished addDependency:op];
#else
    NSBlockOperation *allFinished = [NSBlockOperation blockOperationWithBlock:^{
        //add operation to add "Sort L-ratio" to the list of available cluster options 
        NSInvocationOperation *op = [[[NSInvocationOperation alloc] initWithTarget: self selector:@selector(addClusterOption:) object: 
                           [operationTitle stringByReplacingOccurrencesOfString:@"Compute" withString:@"Sort"]] autorelease];
        //add operation to stop the progress animation
        NSInvocationOperation *op2 = [[[NSInvocationOperation alloc] initWithTarget:progressPanel selector:@selector(stopProgressIndicator) object:nil] autorelease];
        [[NSOperationQueue mainQueue] addOperation:op];
        [[NSOperationQueue mainQueue] addOperation:op2];
    }];
#endif
    //show progress indicator
    [progressPanel setTitle:operationTitle];
    [progressPanel orderFront:self];
    [progressPanel startProgressIndicator];
	NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
	Cluster *cl;
	NSEnumerator *clusterEnumerator = [candidates objectEnumerator]; 
	while( cl = [clusterEnumerator nextObject])
    {
        //Use NSInvocationOperation here
		NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:cl selector:operationSelector object:[fw getVertexData]] autorelease];
        [allFinished addDependency:operation];
        [queue addOperation:operation];
        /*[queue addOperationWithBlock:^{
            [[Clusters objectAtIndex:i] computeLRatio:[fw getVertexData]];
        }];*/
    }
    [queue addOperation:allFinished];
    //g[queue waitUntilAllOperationsAreFinished];
    //clusterModel = [[NSArray arrayWithArray:clusterParams] retain];
    

}

-(IBAction)archiveClusters:(id)sender
{
    //archive on a separate thread
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        //make sure we save to the correct directory
        NSString *fileName = [[self currentDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.fv",currentBaseName]];
        BOOL success;
        success = [NSKeyedArchiver archiveRootObject: [self Clusters] toFile:fileName];
                            //notify that we successfully saved
        if(success == YES)
        {
            NSLog(@"Successfully saved clusters to file %@", fileName);
        }
        else
        {
            NSLog(@"Clusters could not be saved. Most probably because of a permission issue on the file %@", fileName);
        }
    }];
    [queue addOperation:op];
}

-(void) computeFeature:(NSData*)waveforms withNumberOfSpikes: (NSUInteger)nwaves andChannels:(NSUInteger)channels andTimepoints:(NSUInteger)timepoints
{
	//allocate array for features
	NSUInteger s = [waveforms length];
    //stride is applicable if we are loading x,y,z values
    //NSUInteger stride = s/(nwaves*channels*timepoints*sizeof(float));
	
	float *wfdata = (float*)[waveforms bytes];
	float *sparea = malloc(nwaves*channels*sizeof(float));
    float *spwidth = malloc(nwaves*channels*sizeof(float));
    float *spfft = malloc(nwaves*channels*timepoints*sizeof(float));
    float *sppca = malloc(nwaves*channels*timepoints*sizeof(float));
    //remember, if we are looking at raw waveform data, channel is the last dimension
	//sparea = computeSpikeArea(wfdata,stride*timepoints,channels*nwaves,sparea);
    int ch;
    for(ch = 0;ch<channels;ch++)
    {
        computeSpikeArea(wfdata+ch, timepoints, nwaves, 1, sparea+ch*nwaves);
        computeSpikeWidth(wfdata+ch, timepoints , nwaves, 1, spwidth+ch*nwaves);
        computeSpikeFFT(wfdata+channels, timepoints, nwaves, timepoints, spfft+ch*nwaves*timepoints);
        computeSpikePCA(wfdata+channels, channels, nwaves, timepoints, channels,sppca+ch*nwaves*timepoints);

    }
	//float *spwidth = NSZoneMalloc([self zone], nwaves*channels*sizeof(float));
	    
	unsigned int fvsize = 2*nwaves*channels+2*nwaves*channels*timepoints;
	float *fv = NSZoneCalloc([self zone], fvsize,sizeof(float));
	//dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
	//feature vector needs to have form [x,y,z,x,y,z,...]
    //dispatch_apply(nwaves, q, ^(size_t i)
    size_t i;
	for(i=0;i<nwaves;i++)
	{
		int j,k;
		//write the columns feature by feature, i.e. first area, then width
        //remember we are transposing, i.e. all features for channel 1 first, then channel 2
		for(j=0;j<channels;j++)
		{
			//fv[i*3*channels+j] = sparea[i*channels+j];
            fv[i*channels*(2+2*timepoints)+j] = sparea[i*channels + j];
		}
		for(j=0;j<channels;j++)
		{
			//fv[i*3*channels+channels+j] = spwidth[i*channels+j];
            fv[i*channels*(2+timepoints)+channels+j] = spwidth[i*channels+j];
		}
        //fft has as many coefficients as timepoints
        for(k=0;k<timepoints;k++)
        {
            for(j=0;j<channels;j++)
            {
                fv[i*channels*(2+2*timepoints) + 2*channels + k*channels+j] = spfft[i*channels*timepoints + j*timepoints+k];
            }
        }
        //pca same as fft
        for(k=0;k<timepoints;k++)
        {
            for(j=0;j<channels;j++)
            {
                fv[i*channels*(2+2*timepoints) + 2*channels +2*channels*timepoints+ k*channels+j] = sppca[i*channels*timepoints + j*timepoints+k];
            }
        }

	}//);
	
	//scale each feature
	int l = 0;
	float mx,mi;
    /*
	for(l=0;l<2*channels;l++)
	{
		vDSP_maxv(fv+l, 2*channels, &mx, nwaves);
		vDSP_minv(fv+l, 2*channels, &mi, nwaves);
		//now decide which is the biggest
		mi = fabsf(mi);
		if( mi > mx)
		{
			mx = mi; 
		}
		vDSP_vsdiv(fv+l, 2*channels,&mx,fv+l,2*channels,nwaves);
	}*/
    //scale to be between -1 and 1
    vDSP_maxv(fv, 1, &mx, fvsize);
    vDSP_minv(fv, 1, &mi, fvsize);
    float r = (mx-mi)/2;
    mi = -mi;
    vDSP_vsadd(fv, 1, &mi,fv, 1, fvsize);
    vDSP_vsdiv(fv, 1, &r, fv, 1,fvsize);
    mi = -1;
    vDSP_vsadd(fv, 1, &mi,fv, 1, fvsize);

	//we dont need the individual features any more
	//NSZoneFree([self zone], spwidth);
	
    free(spwidth);
	free(sparea);
    free(spfft);
    free(sppca);
	[fw createVertices:[NSData dataWithBytes: fv length: fvsize*sizeof(float)] withRows:nwaves andColumns:channels*(2+2*timepoints)];
	//set the feature Names
	if( featureNames == NULL )
	{
		featureNames = [[NSMutableArray arrayWithCapacity:2*channels] retain];
	}
	[featureNames removeAllObjects];
	for(ch=0;ch<channels;ch++)
	{
		[featureNames addObject: [NSString stringWithFormat:@"Area%d", ch+1]];
	}
	for(ch=0;ch<channels;ch++)
	{
		[featureNames addObject: [NSString stringWithFormat:@"SpikeWidth%d", ch+1]];
	}
    for(ch=0;ch<channels;ch++)
    {
        for(l=0;l<timepoints;l++)
        {
            [featureNames addObject: [NSString stringWithFormat:@"SpikeFFT%d%d",ch+1,l+1]]; 
        }
    }
    for(ch=0;ch<channels;ch++)
    {
        for(l=0;l<timepoints;l++)
        {
            [featureNames addObject: [NSString stringWithFormat:@"SpikePCA%d%d",ch+1,l+1]]; 
        }
    }
	
	[[self dim1] removeAllItems];
	[[self dim1] addItemsWithObjectValues:featureNames];
    [[self dim1] selectItemAtIndex:0];

	
	[[self dim2] removeAllItems];
	[[self dim2] addItemsWithObjectValues:featureNames];
	[[self dim2] selectItemAtIndex:1];
    
	[[self dim3] removeAllItems];
	[[self dim3] addItemsWithObjectValues:featureNames];
    [[self dim3] selectItemAtIndex:2];
    //make the feature view window visible
    
    [[[self fw] window] orderFront:self];
}

-(void)setSelectedClusters:(NSIndexSet *)indexes
{
	//this should be called when a cluster is selected (by clicking on the thumbnail).Draw the waveforms of (the first) selected cluster
	//TODO: This also gets called when the clusters are being added. Need to find a way to make it respond only after the clusters have been loaded
    //TODO: what happens if we right-click? nothing
	NSUInteger firstIndex = [indexes firstIndex];
    //get active clusters
    //NSArray *candidates = [Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"active == YES"]];
	//TODO: Make this work for multiple selection as well
	if( firstIndex < [Clusters count] )
	{
		//if we have already loaded all clusters
		if( clustersLoaded )
		{
			//start by hiding all clusters	
			[[self fw] hideAllClusters];
		}
		//TODO: This does not work if the clusters were sorted in the NSCollectionView, since the index is valid for the sorted and not
		//the original array
		//Cluster *firstCluster = [Clusters objectAtIndex:firstIndex];
		Cluster *firstCluster = [[clusterController selectedObjects] objectAtIndex:0];
        //TODO: This should be made more general
        /*if( ([[firstCluster clusterId] unsignedIntValue] > 0 ) && ([[firstCluster npoints] unsignedIntValue] < [[NSUserDefaults standardUserDefaults] integerForKey:@"maxWaveformsDrawn"]))
        {*/
        if( [[firstCluster npoints] unsignedIntValue]> 0)
        {
            [[self wfv] setOverlay:NO];
            [self loadWaveforms: firstCluster];
            [[wfv window] orderFront: self];
            //make sure we also update the waveformsImage
            if( [firstCluster waveformsImage] == NULL )
            {
            NSImage *img = [[self wfv] image];
            [firstCluster setWaveformsImage:img];
            }
            
            
        }
        
        //}
        if(shouldShowRaster)
        {
            [[[self rasterView] window] orderFront:self];
        }
        if( [[[self rasterView] window] isVisible] )
        {
            
            if([self stimInfo] == NULL )
            {
                [rasterView createVertices:[firstCluster getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[firstCluster color]];
            }
            else
            {
                [rasterView createVertices:[firstCluster getRelevantData:timestamps withElementSize:sizeof(unsigned long long int)] withColor:[firstCluster color] andRepBoundaries:[[self stimInfo] repBoundaries]];
            }
        
        }
        
        //load cluster in feature view
        //not the best solution
        //hide the previously selected cluster, only if it is not also active
        if(( [self selectedCluster] != nil) && ([selectedCluster active] == NO) )
        {
            [[self fw] hideCluster:selectedCluster];
        }
        [[self fw] showCluster:firstCluster];
        //NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Show" withString:@"Hide"];
		//[selectClusterOption removeItemAtIndex:idx];
		//[selectClusterOption insertItemWithTitle:new_selection atIndex:idx];
		//make sure the waveforms view receives notification of highlights
		[[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
		NSMutableIndexSet *_index = [NSMutableIndexSet indexSet];
		[_index addIndexes: indexes];
		selectedClusters = [[[NSIndexSet alloc] initWithIndexSet: _index] retain];
        [self setSelectedCluster:firstCluster];
		
	}
	
}

-(NSIndexSet*)selectedClusters
{
    return selectedClusters;
}

-(void)setSelectedWaveform:(NSString *)wf
{
	
	//[inputPanel orderOut:self];
	//this is experimental
	//get a number
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	NSNumber *number = [formatter numberFromString:wf]; 
	unsigned int point = [number unsignedIntValue];
	//if( point < [[[self activeCluster] npoints] unsignedIntValue] )
	//if ( point < [[[[clusterController selectedObjects] objectAtIndex:0] npoints] unsignedIntValue] )
	//{
		selectedWaveform = [[NSString stringWithString:wf] retain];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSData dataWithBytes:&point length:sizeof(unsigned int)],@"points",nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:self userInfo:userInfo];
	//}
	[formatter release];
	//
}

-(NSString*)selectedWaveform
{
    return selectedWaveform;
}

-(void)movePointsFromCluster:(Cluster*)fromCluster toCluster:(Cluster *)toCluster
{
        if([fw highlightedPoints] != NULL)
        {
            //remove the currently selected waveforms
			NSIndexSet *_indexSet;
            unsigned int *selected = (unsigned int*)[[fw highlightedPoints] bytes];
			unsigned int nselected,i; 
			nselected = ([[fw highlightedPoints] length])/sizeof(unsigned int);
			
			if (nselected == 0) {
				return;
			}
			//check that all the points are in the cluster
			_indexSet = [fromCluster indices];
			for(i=0;i<nselected;i++)
			{
				if( [_indexSet containsIndex: selected[i]] == NO)
				{
					return;
				}
			}
			[fw hideCluster:fromCluster];

            
            [fromCluster removePoints:[NSData dataWithBytes: selected length: nselected*sizeof(unsigned int)]];
            //recompute ISI
            //TODO: Not necessary to recompute everything here
            [selectedCluster computeISIs:timestamps];
            //add this point to the noise cluster
            [toCluster addPoints:[NSData dataWithBytes: selected length: nselected*sizeof(unsigned int)]];
            [[fw highlightedPoints] setLength:0];
			[fw setHighlightedPoints:NULL];
            [fw showCluster:selectedCluster];
			if([[wfv window] isVisible])
			{
				
				[wfv hideWaveforms:[wfv highlightWaves]];
				[[wfv highlightWaves] setLength: 0];
				[wfv setHighlightWaves:NULL];
				//might as well just redraw. Hell yeah!
			}
		}
        [fromCluster setWfMean:[NSData dataWithData:[[self wfv] wfMean]]];
        [fromCluster setWfCov:[NSData dataWithData:[[self wfv] wfStd]]];
        [[[[self fw] menu] itemWithTitle:@"Remove points from cluster"] setEnabled:NO];
		[fw setNeedsDisplay:YES];

}

-(void)readDescriptor:(NSString*)filename
{
	NSArray *fileContents,*words;
	NSMutableArray *_group,*_channel,*_state,*_type;
	NSEnumerator *lineEnumerator;
	NSString *line,*word;
	NSMutableDictionary *_descriptor;
	NSRange range;

	fileContents = [[NSString stringWithContentsOfFile: filename] componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterset]];
	lineEnumerator = [fileContents objectEnumerator];
	//loop through
	while( (line = [lineEnumerator nextObject]))
	{
		word = [[line componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]] lastObject];
		if( [[line lowercaseString] hasPrefix: @"number of channels"])
		{
			[_descriptor setObject: [NSNumber numberWithIint: [word intValue]] forKey:@"numChannels"];
		}
		else if( [[line lowercaseString] hasPrefix: @"sample rate"])
		{
			[_descriptor setObject: [NSNumber numberWithIint: [word floatValue]] forKey:@"sampleRate"];
		}
		else if( [[line lowercaseString] hasPrefix: @"gain"])
		{
			[_descriptor setObject: [NSNumber numberWithIint: [word floatValue]] forKey:@"gain"];
		}
		else
		{
			words = [line componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			range = [[words firstObject] rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]];
			if (range.location == 0)
			{
				//line begins with anumber
				[_channel addObject: [NSNumber numberWithInt: [[words objectAtIndex: 0] integerValue]]];
				[_type addObject: [[words objectAtIndex: 1] lowercaseString]];
				[_group addObject: [NSNumber numberWithInt: [[words objectAtIndex: 2] integerValue]]];
				[_state addObject: [[words objectAtIndex: 3] lowercaseString]];

			}
		}

	}
	[_descriptor setObject: _channel forKey: @"channel"];
	[_descriptor setObject: _group forKey: @"group"];
	[_descriptor setObject: _type forKey: @"type"];
	[_descriptor setObject: _state forKey: @"state"];
	[self setDescriptor: _descriptor];
}


-(void)dealloc
{
    [timestamps release];
    [queue release];
	[selectedClusters release];
	free(channelValidity);
    free(validChannels);
    [super dealloc];
    
}
@end
