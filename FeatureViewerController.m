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
@synthesize filterClustersPredicate;
@synthesize clustersSortDescriptor;
@synthesize clustersSortDescriptors;
@synthesize waveformsFile;
@synthesize activeCluster;
@synthesize selectedClusters;
@synthesize selectedWaveform;
@synthesize featureCycleInterval;
@synthesize releasenotes;
@synthesize rasterView;
@synthesize stimInfo;

-(void)awakeFromNib
{
    //[self setClusters:[NSMutableArray array]];
    dataloaded = NO;
    queue = [[[NSOperationQueue alloc] init] retain];
	currentBaseName = NULL;
	timestamps = NULL;
    [self setFilterClustersPredicate:[NSPredicate predicateWithFormat: @"valid==YES"]];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"showInput" object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"highlight" object: nil];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
												 name:@"performClusterOption" object: nil];

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
	NSAttributedString *reln = [[NSAttributedString alloc] initWithPath:rn documentAttributes:NULL];
	[self setReleasenotes: reln];
	autoLoadWaveforms = YES;
	//set up predicates for filter
	NSPredicateEditorRowTemplate *row = [[[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions: [NSArray arrayWithObjects:[NSExpression expressionForKeyPath:@"valid"],[NSExpression expressionForKeyPath: @"active"],nil] rightExpressions:
										  [NSArray arrayWithObjects:[NSExpression expressionForConstantValue: [NSNumber numberWithInt:1]],[NSExpression expressionForConstantValue:[NSNumber numberWithInt:1]],nil] modifier: NSDirectPredicateModifier operators:
										  [NSArray arrayWithObjects:[NSNumber numberWithInt: NSEqualToPredicateOperatorType],[NSNumber numberWithInt: NSNotEqualToPredicateOperatorType],nil] options:
										 NSCaseInsensitivePredicateOption] autorelease];
										 
									
																					
	[filterPredicates setRowTemplates: [NSArray arrayWithObjects:row,nil]];
    
    //load the rasterview window
    
    
    //setup some usedefaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES], @"autoScaleAxes",
                                      [NSNumber numberWithBool: YES], @"showFeatureAxesLabels",
                                      [NSNumber numberWithBool: NO], @"showWaveformsAxesLabels",
                                      [NSNumber numberWithBool: YES], @"showWaveformsMean",
                                      [NSNumber numberWithBool: YES], @"showWaveformsStd",
                                       [NSNumber numberWithBool: YES],@"stimInfo",nil]];
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
	[openPanel setDelegate:[[OpenPanelDelegate alloc] init]];
	[openPanel setTitle:@"Choose feature file to load"];
	[[openPanel delegate] setExtensions: [NSArray arrayWithObjects:@"fd",@"fet",nil]];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories: YES];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        if(dataloaded == YES)
        {
            [dim1 removeAllItems];
            [dim2 removeAllItems];
            [dim3 removeAllItems];
            [self removeAllObjectsFromClusters];
            
        }
        NSString *directory = [[openPanel directoryURL] path];
        NSString *path = [[openPanel URL] path];
        [self openFeatureFile: path];
		
        
    }
}
        
-(void) openFeatureFile:(NSString*)path
{
	//data object to hold the feature data
	NSString *directory = [path stringByDeletingLastPathComponent];
	NSMutableData *data = [NSMutableData dataWithCapacity:100000*sizeof(float)];
	float *tmp_data,*tmp_data2;
	int cols=0;
	int rows = 0;
	int i,j,k;
	BOOL anyLoaded = NO;
	NSMutableArray *feature_names = [NSMutableArray arrayWithCapacity:16];
	NSString *filebase;
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
		currentBaseName = [[NSString stringWithString:filebase] retain];
		//set the current directory of the process to the the one pointed to by the load dialog
		[[NSFileManager defaultManager] changeCurrentDirectoryPath:directory];
		//get all feature files, i.e. files ending in .fd from the FD directory
		//NSArray *dir_contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"FD"] error: NULL] 
		 //                        pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",nil]];
		//get waveforms file
					
		NSEnumerator *enumerator = [dir_contents objectEnumerator];
		id file;
		header H;
		//float *tmp_data,*tmp_data2;
					
		//TODO: parallelize this
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
				char *filename = [[NSString pathWithComponents: [NSArray arrayWithObjects: directory,file,nil]] cStringUsingEncoding:NSASCIIStringEncoding];
				H = *readFeatureHeader(filename, &H);
				
				tmp_data = NSZoneMalloc([self zone], H.rows*H.cols*sizeof(float));
				tmp_data2 = NSZoneMalloc([self zone], H.rows*H.cols*sizeof(float));
				tmp_data = readFeatureData(filename, tmp_data);
				if(tmp_data == NULL)
				{
					//create an alert
					NSAlert *alert = [NSAlert alertWithMessageText:@"Feature file could not be loaded" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
					[alert runModal];
					NSZoneFree([self zone], tmp_data);
					NSZoneFree([self zone], tmp_data2);
					continue;
					
				}
				//transpose
				for(i=0;i<H.rows;i++)
				{ 
					for(j=0;j<H.cols;j++)
					{
						tmp_data2[j*H.rows+i] = tmp_data[i*H.cols+j];
					}
				}
				//find max
				float max,min;
				float l;
				vDSP_maxv(tmp_data2,1,&max,H.rows*(H.cols));
				//find min
				vDSP_minv(tmp_data2,1,&min,H.rows*(H.cols));
				l = max-min;
				//scale each feature to be between -1 and +1 if autoscale is requested
                //note that this is an overall scaling, so it should not distort the relationship
                //between dimensions
                if( [[NSUserDefaults standardUserDefaults] boolForKey:@"autoScaleAxes"] == YES )
                {
                    for(j=0;j<(H.rows)*(H.cols);j++)
                    {
                        tmp_data2[j] = 2*(tmp_data2[j]-min)/l-1;
                    }
				}

	
				[data appendBytes:tmp_data2 length: H.rows*H.cols*sizeof(float)];
				NSZoneFree([self zone], tmp_data);
				NSZoneFree([self zone], tmp_data2);
				cols+=H.rows;
				//feature names
				//get basename
				NSString *fn = [[[[file lastPathComponent] componentsSeparatedByString:@"_"] lastObject] stringByDeletingPathExtension]; 
				for(j=0;j<H.rows;j++)
				{
					[feature_names addObject: [fn stringByAppendingFormat:@"%d",j+1]];
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
		if( anyLoaded == NO)
		{
			return;
		}
		//need to reshape
		tmp_data = NSZoneMalloc([self zone], rows*cols*sizeof(float));
		tmp_data2 = (float*)[data bytes];
		for(i=0;i<rows;i++)
		{
			for(k=0;k<cols/H.rows;k++)
			{
				for(j=0;j<H.rows;j++)
				{
					tmp_data[i*cols+k*H.rows+j] = tmp_data2[k*rows*H.rows + i*H.rows+j];
				}
			}
		}
		//free(temp_data);
	}
	
	else if([[[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:1] isEqualToString:@"fet"]) 
	{
		//the file is a .fet file; it will have all the features written in ascii format, one row per line
		//the first line contains the number of columns
		filebase = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
		NSLog(@"LastComponent: %@",[path lastPathComponent]);
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
		}
		[data appendBytes:tmp_data length:rows*cols*sizeof(float)];
		tmp_data2 = (float*)[data bytes];
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
	
	//scale data
	//float max,min,l;
	//this was not a good idea; scale the whole dataset instead
	/*
	for(i=0;i<cols;i++)
	{
		//find max
		vDSP_maxv(tmp_data+i,cols,&max,rows);
		//find min
		vDSP_minv(tmp_data+i,cols,&min,rows);
		//scale the data
		l = max-min;
		/*min *=-1;
		vDSP_addv(tmp_data2+i,cols,&min,
		vDSP_vsdiv(tmp_data2+i,cols,&l,tmp_data+i,cols,rows*cols);
		for(j=0;j<rows;j++)
		{
			tmp_data[j*cols+i] = 2*(tmp_data[j*cols+i]-min)/l-1;
		}
	}
	 */
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
	[data replaceBytesInRange:range withBytes:tmp_data length: rows*cols*sizeof(float)];
	 
	NSZoneFree([self zone], tmp_data);
	[fw createVertices:data withRows:rows andColumns:cols];
	//[fw loadVertices: [openPanel URL]];
	[dim1 addItemsWithObjectValues:feature_names];
	[dim2 addItemsWithObjectValues:feature_names];
	[dim3 addItemsWithObjectValues:feature_names];
	dataloaded = YES;
	
	//get time data
	//NSLog(@"XYZF: Is this going to work?");
	//NSLog(@"Filebase: %@",filebase);
	if (([self waveformsFile] == NULL ) && (autoLoadWaveforms == YES) )
	{
        //waveforms file usually resides in a directory above the feature file
		NSArray *waveformfiles = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [directory stringByDeletingLastPathComponent] error: nil] 
								   pathsMatchingExtensions:[NSArray arrayWithObjects:@"bin",nil]] filteredArrayUsingPredicate:
								  [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", filebase]];
		//NSString *waveformsPath = @"";
		if( [waveformfiles count] == 1 )
		{
            [self setWaveformsFile: [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent: [waveformfiles objectAtIndex:0]]];
			char *waveformsPath = [waveformsFile cStringUsingEncoding: NSASCIIStringEncoding];
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
			free(times);
			free(times_indices);
		}
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
    [dim1 setEditable:NO];
    [dim1 selectItemAtIndex:0];
    [dim2 setEditable:NO];
    [dim2 selectItemAtIndex:1];
    [dim3 setEditable:NO];
    [dim3 selectItemAtIndex:2];
	featureNames = [[NSMutableArray arrayWithArray:feature_names] retain];
	//register featureview for notification about change in highlight
	//feature view only received notification from waveforms view
	//[[NSNotificationCenter defaultCenter] addObserver: fw selector:@selector(receiveNotification:) 
	//											 name:@"highlight" object: [self wfv]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) 
												 name:@"setFeatures" object:nil];
	
    
    if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"stimInfo"] boolValue]==YES)
    {
        NSString *stimInfoFile = NULL;
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
            if( [[NSFileManager defaultManager] fileExistsAtPath:stimInfoFile] == NO)
            {
                stimInfoFile=NULL;
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
    }
	//only reset clusters if data has already been loaded
    if( ([self Clusters] != nil) && (dataloaded == YES ) )
    {
        [self removeAllObjectsFromClusters];
    }
    
}

- (IBAction) loadClusterIds: (id)sender
{
     
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    //set a delegate for openPanel so that we can control which files can be opened
    [openPanel setDelegate:[[OpenPanelDelegate alloc] init]];
    //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
    
	[[openPanel delegate] setBasePath: currentBaseName];
    [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"clu",@"fv",@"overlap",@"cut",nil]];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        [self openClusterFile:[[openPanel URL] path]];
    }
        
                                                       
}

- (void)openClusterFile:(NSString*)path;
{
    [[NSNotificationCenter defaultCenter] removeObserver: self name: @"ClusterStateChanged" object: nil];
    //remove all the all clusters
    //[self removeAllObjectsFromClusters];
    //NSString *filename = [[openPanel URL] path];
    
    NSString *extension = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:1];
    float *cluster_colors;
    NSMutableArray *tempArray;
    //check if data is loaded
    if(dataloaded==NO)
    {
        //need to load the data before loading the clusters
        
        //get the basename
        NSString *basename = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
        NSString *directory = [path stringByDeletingLastPathComponent];
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
    if( [extension isEqualToString:@"fv"] )
    {
        tempArray = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        //get cluster colors
        //NSMutableData *_cluster_colors = [NSMutableData dataWithCapacity:params.rows*3*sizeof(float)];
        cluster_colors = NSZoneMalloc([self zone], params.rows*3*sizeof(float));
        id _cluster;
        NSEnumerator *_clustersEnumerator = [tempArray objectEnumerator];
        int i;
        while( _cluster = [_clustersEnumerator nextObject] )
        {
            unsigned int *_points = (unsigned int*)[[_cluster points] bytes];
            unsigned int _npoints = [[_cluster npoints] intValue];
            float *_color = (float*)[[_cluster color] bytes];
            for(i=0;i<_npoints;i++)
            {
                cluster_colors[3*_points[i]] = _color[0];
                cluster_colors[3*_points[i]+1] = _color[1];
                cluster_colors[3*_points[i]+2] = _color[2];
            }
        }
        [tempArray makeObjectsPerformSelector:@selector(makeValid)];
        
    }
    else 
	{
        if( [extension isEqualToString:@"cut"] || [extension isEqualToString:@"clu"] )
        {
			int offset = 1;
			if( [extension isEqualToString:@"cut"] )
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
			int *cids = NSZoneMalloc([self zone], (rows+1)*sizeof(int));
			//cids = readClusterIds(fname, cids);
			NSArray *lines = [[NSString stringWithContentsOfFile:path encoding: NSASCIIStringEncoding error: NULL] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			//iteratae through lines
			NSEnumerator *lines_enum = [lines objectEnumerator];
			id line;
			NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
			int cidx = 0;
			while ( (line = [lines_enum nextObject] ) )
			{
				NSNumber *q = [formatter numberFromString:line];
				//if line is not a string, q is nil
				if( q )
				{
					cids[cidx] = [q intValue];
					cidx+=1;
				}
				
			}
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
			cluster_colors = NSZoneMalloc([self zone],rows*3*sizeof(float));
			for(i=0;i<rows;i++)
			{
				if( cids[i+offset] >= 0 )
				{
					npoints[cids[i+offset]]+=1;
				}
			}
			for(i=0;i<maxCluster;i++)
			{
				Cluster *cluster = [[Cluster alloc] init];
				cluster.clusterId = [NSNumber numberWithUnsignedInt:i];
				//cluster.name = [NSString stringWithFormat: @"%d",i];
				
				
				cluster.npoints = [NSNumber numberWithUnsignedInt: npoints[i]];
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
			}
			NSZoneFree([self zone], cids);
			free(npoints);
			//free(cluster_colors);

			//tell the view to change the colors
		}
		else if ([extension isEqualToString:@"overlap"])
		{
			char *fname = [path cStringUsingEncoding:NSASCIIStringEncoding];
			uint64_t nelm = getFileSize(fname)/sizeof(uint64_t);
			unsigned ncols = nelm/2;
			uint64_t *overlaps = NSZoneMalloc([self zone], nelm*sizeof(uint64_t));
			overlaps = readOverlapFile(fname, overlaps, nelm);
			//since the overlaps are assumed to ordered according to clusters, with cluster ids in the first column, we can easily get
			//the maximum numbers of clusters
			unsigned int maxCluster = overlaps[ncols-2]+1;
			unsigned i,j;
				
			cluster_colors = NSZoneMalloc([self zone], 3*ncols*sizeof(float));
			tempArray = [NSMutableArray arrayWithCapacity:maxCluster];

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
				[cluster updateDescription];
				[tempArray addObject:cluster];
			}
			//now loop through the overlap matrix, adding points to the clusters as we go along
			unsigned int cid,wfidx,npoints;
			cid = maxCluster+1;
			Cluster *cluster;
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
			//free overlaps since we don't need it
			NSZoneFree([self zone], overlaps);
			[tempArray makeObjectsPerformSelector:@selector(createName)];	
			
		}
        
    }
	//turn off the first cluster, since it's usually the noise cluster
	[[tempArray objectAtIndex:0] makeInactive];
	if( dataloaded == YES )
	{
		//only do this if data has been loaded
		[fw setClusterColors: cluster_colors forIndices: NULL length: 1];
	}
    //since colors are now ccopied, we can free it
    NSZoneFree([self zone],cluster_colors);
	[self setClusters:tempArray];
    [self setIsValidCluster:[NSPredicate predicateWithFormat:@"valid==1"]];
    
    
    [selectClusterOption removeAllItems];
    NSMutableArray *options = [NSMutableArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Filter clusters",@"Remove waveforms",@"Make Template",@"Undo Template",@"Compute XCorr",@"Compute Isolation Distance",@"Show raster",nil];
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
	id cluster;
	while( (cluster=[clusterEn nextObject] ) ) 
	{
		if( [[cluster clusterId] unsignedIntValue] > 0 )
		{
			[self loadWaveforms: cluster];
			//make sure we also update the waverormsImage
			if([cluster waveformsImage] == NULL)
			{
				NSImage *img = [[self wfv] image];
				[cluster setWaveformsImage:img];
			}
		}
		//add set the feature dimension
		[cluster setFeatureDims: params.cols];
		
	}
	[[wfv window] orderOut: self];
	[self performComputation:@"Compute Feature Mean" usingSelector:@selector(computeFeatureMean:)];
	[allActive setState:1];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
	    //check for model file
    NSString *modelFilePath = [path stringByReplacingOccurrencesOfString: extension withString: @"model"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: modelFilePath ] )
    {
        [self readClusterModel:modelFilePath];
        [options addObject: @"Compute L-ratio"];
    }
    [selectClusterOption addItemsWithTitles:options];
    //once we have loaded the clusters, start up a timer that will ensure that data gets arhived automatically every 5 minutes
    archiveTimer = [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(archiveClusters) userInfo:nil repeats: YES];
}

-(void) openWaveformsFile: (NSString*)path
{
    //since we do not, in general want to load the entire waveforms file, we load instead a random subset
    //hide the feature view since we dont need it
    [[fw window ] orderOut: self];
    //we also dont' want the FeatureView to receive any notifications
    [[NSNotificationCenter defaultCenter] removeObserver: fw];
    [self setWaveformsFile:path];
    char *fpath = [[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding];
    nptHeader spikeHeader;
    spikeHeader = *getSpikeInfo(fpath,&spikeHeader);
    int _npoints = 1000;
    unsigned int *_points = NSZoneMalloc([self zone], _npoints*sizeof(unsigned int));
    int i;
    for(i=0;i<_npoints;i++)
    {
        _points[i] = (unsigned int)((((float)rand())/RAND_MAX)*(spikeHeader.num_spikes));
    }
    Cluster *cluster = [[Cluster alloc] init];
    [cluster setPoints:[NSMutableData dataWithBytes:_points length:_npoints*sizeof(unsigned int)]];
    [cluster setNpoints:[NSNumber numberWithUnsignedInt: _npoints]];
    float color[3];
    color[0] = ((float)rand())/RAND_MAX;
    color[1] = ((float)rand())/RAND_MAX;
    color[2] = ((float)rand())/RAND_MAX;
    cluster.color = [NSData dataWithBytes: color length:3*sizeof(float)];
    NSZoneFree([self zone], _points);
    [self loadWaveforms:cluster];
    //allow the waveforms view to receive notification about highlights
    [[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];

    
}

- (void) loadWaveforms: (Cluster*)cluster
{
    if (waveformsFile == NULL)
    {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        //set a delegate for openPanel so that we can control which files can be opened
        [openPanel setDelegate:[[OpenPanelDelegate alloc] init]];
		[openPanel setTitle:@"Choose waveforms to load"];
        //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
        [[openPanel delegate] setBasePath: currentBaseName];
        [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"bin",nil]];
        int result = [openPanel runModal];
        if( result == NSOKButton )
        {
            //test
            //Cluster *cluster = [Clusters objectAtIndex: 3];
            [self setWaveformsFile:[[openPanel URL] path]];
			[[wfv window] orderFront: self];
        }
    }
    if (waveformsFile != NULL)
    {
		//TODO: Look for reorder file in the same directory
		NSString *reorderPath = [[[self waveformsFile] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"reorder.txt"];
		NSMutableData *reorder_index = NULL;
		if ([[NSFileManager defaultManager] fileExistsAtPath:reorderPath ] )
		{
			NSArray *reorder = [[NSString stringWithContentsOfFile:reorderPath] componentsSeparatedByString:@" "];
			int count = [reorder count];
			reorder_index = [NSMutableData dataWithCapacity:count*sizeof(unsigned int)];
			int i;
			unsigned int T = 0;
			for(i=0;i<count;i++)
			{
				T = [[reorder objectAtIndex:i] integerValue]-1;
				[reorder_index appendBytes:&T length:sizeof(T)]; 
			}
		}
		
        char *path = [[self waveformsFile] cStringUsingEncoding:NSASCIIStringEncoding];         
        unsigned int npoints = [[cluster npoints] unsignedIntValue];
        
        nptHeader spikeHeader;
        spikeHeader = *getSpikeInfo(path,&spikeHeader);
        unsigned int wfSize = npoints*spikeHeader.channels*spikeHeader.timepts;
        short int *waveforms = malloc(wfSize*sizeof(short int));
        waveforms = getWaves(path, &spikeHeader, (unsigned int*)[[cluster points] bytes], npoints, waveforms);
        
        //convert to float
        float *fwaveforms = malloc(wfSize*sizeof(float));
        vDSP_vflt16(waveforms, 1, fwaveforms, 1, wfSize);
		free(waveforms);
		
        [[wfv window] orderFront: self];
        [wfv createVertices:[NSData dataWithBytes:fwaveforms length:wfSize*sizeof(float)] withNumberOfWaves: npoints channels: (NSUInteger)spikeHeader.channels andTimePoints: (NSUInteger)spikeHeader.timepts 
                   andColor:[cluster color] andOrder:reorder_index];
        free(fwaveforms);
		nchannels = spikeHeader.channels;
		//setup self to recieve notification on feature computation
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"computeSpikeWidth" object:nil];
		if(timestamps==NULL)
        {
            //load time stamps if not already loaded
            unsigned long long int *times = malloc(spikeHeader.num_spikes*sizeof(unsigned long long int));
            unsigned int *times_indices = malloc(spikeHeader.num_spikes*sizeof(unsigned int));
            int i;
            for(i=0;i<spikeHeader.num_spikes;i++)
            {
                times_indices[i] = i;
            }
            times = getTimes(path, &spikeHeader, times_indices, spikeHeader.num_spikes, times);
            timestamps = [[NSData dataWithBytes:times length:spikeHeader.num_spikes*sizeof(unsigned long long int)] retain];
			            free(times);
            free(times_indices);
            //add the ISI options to cluster options
            [selectClusterOption addItemWithTitle:@"Shortest ISI"];
			

        }
		//[rasterView createVertices:timestamps];
		//[[rasterView window] orderFront:self];

	}
		
    
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
    if( [[notification object] active] )
    {
        [fw showCluster:[notification object]];
        [self setActiveCluster:[notification object]];
		//we don't want to do this any more since we are using selectedClusters to manage what to draw in
		//the waveformsview
		/*
        if([[[self wfv] window] isVisible])
        {
            //if we are showing waveforms
            [self loadWaveforms:[notification object]];
            //if no image has been created for this cluster,create one
            if( [[self activeCluster] waveformsImage] == NULL )
            {
                //BOOL cd = [[self wfv] canDraw];
                NSImage *img = [[self wfv] image];
                [[self activeCluster] setWaveformsImage:img];
                
            }
        }*/
        //update the raster
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
        if( [[[self wfv] window] isVisible] )
        {
            [self loadWaveforms: [notification object]];
        }
        

    }
    else {
        [fw hideCluster: [notification object]];
        if([[self activeCluster] isEqualTo:[notification object]] )
        {
            //if the cluster we de-selected was the active one (i.e. last selected)
            [self setActiveCluster:nil];
        }
    }
    
}

-(void)setFilterClustersPredicate:(NSPredicate *)predicate
{
    filterClustersPredicate = [predicate retain];
    //[fw hideAllClusters];
    NSPredicate *isActive = [NSPredicate predicateWithFormat:@"active==YES"];
    //[[Clusters filteredArrayUsingPredicate:[NSCompoundPredicate notPredicateWithSubpredicate: predicate]] makeObjectsPerformSelector:@selector(makeInactive)];
    //[allActive setState: 0];
    //Inactive those clusters for which the predicate is not true and which are already active
    [[Clusters filteredArrayUsingPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:                                                                                                [NSCompoundPredicate notPredicateWithSubpredicate:predicate],                                                                                               isActive,nil]]] makeObjectsPerformSelector:@selector(makeInactive)];
    //Activate those clusters for which the predicate is true and which are inactive
    [[Clusters filteredArrayUsingPredicate: [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:                                                                                                 [NSCompoundPredicate notPredicateWithSubpredicate:isActive],                                                                                                 predicate,nil]]] makeObjectsPerformSelector:@selector(makeActive)];
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
		int currentDim1 = [featureNames indexOfObject:[dim1 objectValueOfSelectedItem]];
		int currentDim2 = [featureNames indexOfObject:[dim2 objectValueOfSelectedItem]];
		int currentDim3 = [featureNames indexOfObject:[dim3 objectValueOfSelectedItem]];

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
		[dim1 selectItemAtIndex:currentDim1];
		[dim1 setObjectValue:[dim1 objectValueOfSelectedItem]];
		[self changeDim1:dim1];
		
		
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
		[self computeFeature:[[notification userInfo] objectForKey: @"data"] 
				withChannels:[[[notification userInfo] objectForKey:@"channels"] unsignedIntValue]
			   andTimepoints:[[[notification userInfo] objectForKey:@"timepoints"] unsignedIntValue]];
	}
	else if ( [[notification name] isEqualToString:@"showInput" ] )
	{
		//show the input panel
		NSNumber *number = [[notification userInfo] objectForKey:@"selected"];
		
		[self setSelectedWaveform: [number stringValue]];
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
        if( [[notification object] isKindOfClass:[Cluster class]] )
        {
            [[self fw] highlightPoints:[notification userInfo] inCluster: [notification object]];
        }
        /*
		else if (([self selectedClusters] != nil) && ([[self selectedClusters] count] >= 1 ) ) 
		{
        
            [[self fw] highlightPoints:[notification userInfo] inCluster:[[self Clusters] objectAtIndex:[selectedClusters firstIndex]]];
        
		}
         */
		else
		{
			//no cluster selected
			[[self fw] highlightPoints:[notification userInfo] inCluster:[self activeCluster]];

		}
	}
	else if ([[notification name] isEqualToString:@"performClusterOption"] )
	{
		//set the selected object
		//check that the option is valid
		NSUInteger idx = [[selectClusterOption itemTitles] indexOfObject:[[notification userInfo] objectForKey:@"option"]];
		if (idx != NSNotFound )
		{
			[selectClusterOption selectItemAtIndex: idx];
			[self performClusterOption:selectClusterOption];
		}
		//[[self ClusterOptions]] 
	}
	
}

-(void) setAvailableFeatures:(NSArray*)channels
{
	//sets the features based on the channels
	unsigned nfeatures = cols;
	[dim1 removeAllItems];
	[dim2 removeAllItems];
	[dim3 removeAllItems];

	NSEnumerator *channelEnumerator = [channels objectEnumerator];
	id ch;
	while( ch = [channelEnumerator nextObject] )
	{
		//NSArray *validFeatures = [featureNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS %@",[NSString stringWithFormat:@"%d",[ch intValue]+1]]];
		NSString *regexp = [NSString stringWithFormat: @"[A-Za-z]*%d",[ch intValue]+1];
		NSArray *validFeatures = [featureNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES %@",regexp]];

		[dim1 addItemsWithObjectValues:validFeatures];
		[dim2 addItemsWithObjectValues:validFeatures];

		[dim3 addItemsWithObjectValues:validFeatures];
		
	   //[dim1 objectValueOfSelectedItem]
	}
	[dim1 selectItemAtIndex:0];
	//notify that soemthing changed
	[self changeDim1:dim1];
	[dim2 selectItemAtIndex:1];
	[self changeDim2:dim2];

	[dim3 selectItemAtIndex:2];
	[self changeDim3:dim3];			
	
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
    }
    else {
        [Clusters makeObjectsPerformSelector:@selector(makeActive)];
        [fw showAllClusters];
    }
   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
    
    //[Clusters makeObjectsPerformSelector:@selector(setActive:) withObject: state];
    
}

- (IBAction) clusterThumbClicked: (id)sender
{
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
    if( [selection isEqualToString:@"Merge"] )
    {
        if( [candidates count] ==2 )
        {
            [self mergeCluster: [candidates objectAtIndex: 0] withCluster: [candidates objectAtIndex: 1]];
        }
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
    else if( [selection isEqualToString:@"Compute Isolation Distance"])
    {
        [self performComputation:@"Compute Isolation Distance" usingSelector:@selector(computeIsolationDistance:)];
        
    }
    else if( [selection isEqualToString:@"Shortest ISI"])
    {
        unsigned int *tpts = (unsigned int*)[[activeCluster points] bytes];
        unsigned int *pts = (unsigned int*)[[activeCluster isiIdx] bytes];
        unsigned long long int* times = (unsigned long long int*)[timestamps bytes];
        if( (pts == NULL) & (times != NULL))
        {
            [activeCluster computeISIs:timestamps];
            pts = (unsigned int*)[[activeCluster isiIdx] bytes];
        }
        //isiIdx contains the indices of the isis; the first index is the index of the shortest isi
        //only mark if the shortest ISI is less than 1000 microseconds
        if(pts)
        {
            if ( times[tpts[pts[0]+1]]-times[tpts[pts[0]]] < 1000)
            {
            
                unsigned int *spts = malloc(2*sizeof(unsigned int));
                spts[0] = pts[0];
                spts[1] = pts[0]+1;
                NSDictionary *_params = [NSDictionary dictionaryWithObjects: 
                                        [NSArray arrayWithObjects:                                                                             [NSData dataWithBytes:spts length:2*sizeof(unsigned int)],[activeCluster color],nil] forKeys: [NSArray arrayWithObjects:@"points",@"color",nil]];
                [[NSNotificationCenter defaultCenter] postNotificationName: @"highlight" userInfo: _params];
                free(spts);
            }
        }
    }
    else if ( [selection isEqualToString:@"Remove waveforms"] )
    {
        
        if([fw highlightedPoints] != NULL)
        {
            //remove the currently selected waveforms
            unsigned int *selected = (unsigned int*)[[fw highlightedPoints] bytes];
			unsigned int nselected = ([[fw highlightedPoints] length]);
			if (nselected == 0) {
				return;
			}
            //[[self activeCluster] setActive:0];
            Cluster *selectedCluster = [[clusterController selectedObjects] objectAtIndex:0];
			BOOL toggleActive = NO;
			
			if( [selectedCluster active] == 1 )
			{
				[selectedCluster setActive:0];
				toggleActive = YES;
				[fw hideCluster:selectedCluster];

			}
			//[[Clusters objectAtIndex:0] setActive: 0];
            //[fw hideCluster:[self activeCluster]];
           
            
            [selectedCluster removePoints:[NSData dataWithBytes: selected length: nselected]];
            //recompute ISI
            //TODO: Not necessary to recompute everything here
            [selectedCluster computeISIs:timestamps];
            //add this point to the noise cluster
            [[Clusters objectAtIndex:0] addPoints:[NSData dataWithBytes: selected length: nselected]];
            GLfloat *_color = (GLfloat*)[[[Clusters objectAtIndex:0] color] bytes];
            GLuint *_points = (GLuint*)selected;
            GLuint _length = nselected/sizeof(unsigned int);
            //set the colors of the new cluster
            //[fw setClusterColors:_color forIndices:_points length:_length];
            if( toggleActive == YES )
			{
				[selectedCluster setActive:1];
				[fw showCluster:selectedCluster];

			}
            //[[Clusters objectAtIndex:0] setActive: 1];
            //reset the highlighted waves
            /*
            NSDictionary *params = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:
                                                                         [NSData dataWithBytes:NULL length:0],[activeCluster color],nil]
                                                               forKeys: [NSArray arrayWithObjects:@"points",@"color",nil]];
            
            //remove the highlights
            [fw highlightPoints:params];
             */
            [[fw highlightedPoints] setLength:0];
			[fw setHighlightedPoints:NULL];
		
			if([[wfv window] isVisible])
			{
				
				[wfv hideWaveforms:[wfv highlightWaves]];
				[[wfv highlightWaves] setLength: 0];
				[wfv setHighlightWaves:NULL];
				//might as well just redraw. Hell yeah!
				//[self loadWaveforms:selectedCluster];
			}
		}
		[fw setNeedsDisplay:YES];
		
    }
    else if( [selection isEqualToString:@"Make Template"] )
    {
        [candidates makeObjectsPerformSelector:@selector(makeTemplate)];
    }
    else if( [selection isEqualToString:@"Undo Template"] )
    {
        [candidates makeObjectsPerformSelector:@selector(undoTemplate)];
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
        NSUInteger idx = [[[self activeCluster] indices] firstIndex];
        while( idx != NSNotFound )
        {
            NSRange _r;
            _r.location = idx*sizeof(unsigned long long int);
            _r.length = sizeof(unsigned long long int);
            [ctimes appendData: [timestamps subdataWithRange:_r]];
            idx = [[[self activeCluster] indices] indexGreaterThanIndex:idx];
        }
        ///register raster view for notifications
        [[NSNotificationCenter defaultCenter] addObserver:[self rasterView] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
        if( [self stimInfo] == NULL )
        {
            [rasterView createVertices:ctimes withColor:[NSData dataWithData:[[self activeCluster] color]]];
        }
        else
        {
            [rasterView createVertices:ctimes withColor:[NSData dataWithData:[[self activeCluster] color]] andRepBoundaries:[[self stimInfo] repBoundaries]];
        }
		[[rasterView window] makeKeyAndOrderFront:self];
    }
        
                                                                                 
}

- (IBAction) saveClusters:(id)sender
{
    //Need to get the points of each cluster, and use those points as indexes for which the point is the
    //cluster number
    //create an array to hold the indices
    //make sure there are clusters to save
    if ([Clusters count] > 0)
    {
        //NSMutableArray *cluster_indices = [NSMutableArray arrayWithCapacity:params.rows];
        //NSMutableIndexSet *index = [NSMutableIndexSet indexSet];
		
        NSMutableDictionary *cluster_indices = [NSMutableDictionary dictionaryWithCapacity:params.rows];
        //enumreate all valid clusters
        //do it the "c" way
        //FILE *cluster_file = fopen("FeatureViewer.clusters","w");
        
        NSEnumerator *cluster_enumerator = [[Clusters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat: @"valid==1"]] objectEnumerator];
        int i;
        int npoints;
        id cluster;
        while( cluster = [cluster_enumerator nextObject] )
        {
            unsigned int *clusteridx = (unsigned int*)[[cluster points] bytes];
            npoints = [[cluster npoints] intValue];
            for(i=0;i<npoints;i++)
            {
                [cluster_indices setObject: [NSNumber numberWithUnsignedInteger: (NSUInteger)clusteridx[i]] forKey:[cluster clusterId]];
                //[index addIndex:(NSUInteger)clusteridx[i]];
            }
        }
        //now, join the components by sorting according to the index
        //this allows me to try out blocks!! wohooo
        //basically, I'm just telling the dictionary containing the cluster names and indices to sort itself by comparing the values
        //i.e. the indices
        NSString *cidx_string = [[cluster_indices keysSortedByValueUsingComparator: ^(id obj1, id obj2) {
            if ([obj1 unsignedIntValue] < [obj2 unsignedIntValue] ) {
                return (NSComparisonResult)NSOrderedAscending;
            }
            else
            {
                return (NSComparisonResult)NSOrderedDescending;
            }

            
        }] componentsJoinedByString:@"\n"];
		//open panel to get filename

		NSSavePanel *savePanel = [NSSavePanel savePanel];
		[savePanel setNameFieldStringValue:[NSString stringWithFormat: @"%@.cut",currentBaseName]];
		/*
		[savePanel beginWithCompletionHandler:^(NSInteger result) 
		 {
			 if(result == NSFileHandlingPanelOKButton )
			 {
				 [cidx_string writeToFile:[savePanel nameFieldStringValue] atomically:YES];
			 }
		 }];*/
		NSInteger result = [savePanel runModal];
		if(result == NSFileHandlingPanelOKButton )
		{
			[cidx_string writeToFile:[[[savePanel directoryURL] path] stringByAppendingPathComponent: [savePanel nameFieldStringValue]] atomically:YES];
		}
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
		[savePanel setNameFieldStringValue:[NSString stringWithFormat: @"%@.scu",currentBaseName]];
		[savePanel beginWithCompletionHandler:^(NSInteger result) 
		 {
			 if(result == NSFileHandlingPanelOKButton )
			 {
				 [templateIdStr writeToFile:[[[savePanel directoryURL] path] stringByAppendingPathComponent: [savePanel nameFieldStringValue]] atomically:YES];
			 }
		 }];
        //[templateIdStr writeToFile:[NSString stringWithFormat:@"%@.scu",currentBaseName] atomically:YES];
        
        //also store the data
        
        [self archiveClusters];
    }
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
			[image writeToFile:[savePanel nameFieldStringValue] atomically:YES];
		}
	}];
		
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
    //[self insertObject:new_cluster inClustersAtIndex:[Clusters indexOfObject: cluster1]];
    //set the new cluste colors
    int nclusters = [Clusters count];
    new_cluster.parents = [NSArray arrayWithObjects:cluster1,cluster2,nil];
    [self insertObject:new_cluster inClustersAtIndex:nclusters];
	if( dataloaded == YES)
	{
		//only do this if data has been loaded; should probably try to make this a bit more general
		[fw setClusterColors:[[new_cluster color] bytes] forIndices:[[new_cluster points] bytes] length:[[new_cluster npoints] unsignedIntValue]];
	}
    new_cluster.active = 1;
}

-(void)deleteCluster: (Cluster *)cluster
{
    [cluster makeInactive];
    [cluster makeInvalid];
    
    NSEnumerator *parentsEnumerator = [[cluster parents] objectEnumerator];
    id parent;
    while(parent = [parentsEnumerator nextObject] )
    {
        //restore previous cluster colors
        [fw setClusterColors: (GLfloat*)[[parent color] bytes] forIndices: (GLuint*)[[parent points] bytes] length:[[parent npoints] unsignedIntValue]];
        [parent makeValid];
    }
    [fw hideCluster:cluster];
    [self removeObjectFromClustersAtIndex: [Clusters indexOfObject:cluster]];
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
		NSTimer *_timer = [NSTimer scheduledTimerWithTimeInterval:1 target: fw selector:@selector(selectDimensions:) userInfo: nil repeats:YES];
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
    NSDictionary *dict = [NSDictionary dictionaryWithObjects: [[lines objectAtIndex:2] componentsSeparatedByString:@" "] 
                                                     forKeys: [NSArray arrayWithObjects:@"ndim",@"nclusters",@"npoints",nil]];
    //the second line contains the scaling
    int nclusters = [[dict valueForKey:@"nclusters"] intValue];
    int ndim = [[dict valueForKey:@"ndim"] intValue];
    int linesPerCluster = ndim+2;
    int i;
    float *mean = malloc(ndim*sizeof(float));
    float *cov = malloc(ndim*ndim*sizeof(float));
    //NSMutableArray *clusterParams = [NSMutableArray arrayWithCapacity:nclusters];
    for(i=0;i<nclusters;i++)
    {
        //NSMutableDictionary *cluster = [NSMutableDictionary dictionaryWithCapacity:3];
        //[cluster setObject: [NSNumber numberWithFloat: [[[[lines objectAtIndex: 3+i*linesPerCluster] componentsSeparatedByString: @" "] objectAtIndex: 1] floatValue]] forKey:@"Mixture"];
        NSScanner *meanScanner = [NSScanner scannerWithString:[lines objectAtIndex:3+i*linesPerCluster+1]];
        
        int j = 0;
        while ( [meanScanner isAtEnd] == NO)
        {
            [meanScanner scanFloat:mean+j];
            j+=1;
        }
        //[cluster setObject: [NSData dataWithBytes: mean length: ndim*sizeof(float)] forKey: @"Mean"];
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
        //[cluster setObject: [NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)] forKey: @"Cov"];
        [[Clusters objectAtIndex:i] setCov:[NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)]];
        //compute inverse covariance matrix
        int status = matrix_inverse(cov, ndim);
        //[cluster setObject: [NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)] forKey: @"Covi"];
        [[Clusters objectAtIndex:i] setCovi:[NSData dataWithBytes:cov length:ndim*ndim*sizeof(float)]];
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
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget: self selector:@selector(addClusterOption:) object: 
                           [operationTitle stringByReplacingOccurrencesOfString:@"Compute" withString:@"Sort"]];
        //add operation to stop the progress animation
        NSInvocationOperation *op2 = [[NSInvocationOperation alloc] initWithTarget:progressPanel selector:@selector(stopProgressIndicator) object:nil];
        [[NSOperationQueue mainQueue] addOperation:op];
        [[NSOperationQueue mainQueue] addOperation:op2];
    }];
#endif
    //show progress indicator
    [progressPanel setTitle:operationTitle];
    [progressPanel orderFront:self];
    [progressPanel startProgressIndicator];
    int i;
    int nclusters = [Clusters count];
    for(i=0;i<nclusters;i++)
    {
        //Use NSInvocationOperation here
        NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:[Clusters objectAtIndex:i]
                                                                                selector:operationSelector object:[fw getVertexData]];
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

-(void)archiveClusters
{
    //archive on a separate thread
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
                            [NSKeyedArchiver archiveRootObject: [self Clusters] toFile:[NSString stringWithFormat:@"%@.fv",currentBaseName]];
    }];
    [queue addOperation:op];
}

-(void) computeFeature:(NSData*)waveforms withChannels:(NSUInteger)channels andTimepoints:(NSUInteger)timepoints
{
	//allocate array for features
	NSUInteger s = [waveforms length];
	NSUInteger nwaves = s/(3*channels*timepoints*sizeof(float));
	
	float *wfdata = (float*)[waveforms bytes];
	float *sparea = NSZoneMalloc([self zone], nwaves*channels*sizeof(float));
	sparea = computeSpikeArea(wfdata,3*timepoints,channels*nwaves,sparea);

	//float *spwidth = NSZoneMalloc([self zone], nwaves*channels*sizeof(float));
	float *spwidth = malloc(nwaves*channels*sizeof(float));
	spwidth = computeSpikeWidth(wfdata, 3*timepoints, channels*nwaves, spwidth);
	
		
	float *fv = NSZoneMalloc([self zone], 2*nwaves*channels*sizeof(float));
	dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
	dispatch_apply(nwaves, q, ^(size_t i)
	//for(i=0;i<nwaves;i++)
	{
		int j;
		//write the columns feature by feature, i.e. first area, then width
		for(j=0;j<channels;j++)
		{
			fv[i*2*channels+j] = sparea[i*channels+j];
		}
		for(j=0;j<channels;j++)
		{
			fv[i*2*channels+channels+j] = spwidth[i*channels+j];
		}
	});
	
	//scale each feature
	int l = 0;
	float mx,mi;
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
	}
	
	//we dont need the individual features any more
	//NSZoneFree([self zone], spwidth);
	free(spwidth);
	NSZoneFree([self zone], sparea);
	[fw createVertices:[NSData dataWithBytes: fv length: 2*channels*nwaves] withRows:nwaves andColumns:2*channels];
	//set the feature Names
	if( featureNames == NULL )
	{
		featureNames = [[NSMutableArray arrayWithCapacity:2*channels] retain];
	}
	[featureNames removeAllObjects];
	int ch = 0;
	for(ch=0;ch<channels;ch++)
	{
		[featureNames addObject: [NSString stringWithFormat:@"Area%d", ch+1]];
	}
	for(ch=0;ch<channels;ch++)
	{
		[featureNames addObject: [NSString stringWithFormat:@"SpikeWidth%d", ch+1]];
	}
	
	[dim1 removeAllItems];
	[dim1 addItemsWithObjectValues:featureNames];
	
	[dim2 removeAllItems];
	[dim2 addItemsWithObjectValues:featureNames];
	
	[dim3 removeAllItems];
	[dim3 addItemsWithObjectValues:featureNames];
}

-(void)setSelectedClusters:(NSIndexSet *)indexes
{
	//this should be called when a cluster is selected (by clicking on the thumbnail).Draw the waveforms of (the first) selected cluster
    //TODO: what happens if we right-click? nothing
	NSUInteger firstIndex = [indexes firstIndex];
	if( firstIndex < [Clusters count] )
	{
		//TODO: This does not work if the clusters were sorted in the NSCollectionView, since the index is valid for the sorted and not
		//the original array
		//Cluster *firstCluster = [Clusters objectAtIndex:firstIndex];
		Cluster *firstCluster = [[clusterController selectedObjects] objectAtIndex:0];
		[self loadWaveforms: firstCluster];
		[[wfv window] orderFront: self];
		//make sure we also update the waveformsImage
		if([firstCluster waveformsImage] == NULL)
		{
			NSImage *img = [[self wfv] image];
			[firstCluster setWaveformsImage:img];
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
		NSInteger idx = [selectClusterOption indexOfSelectedItem];
		NSString *selection = [selectClusterOption titleOfSelectedItem];
		NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Show" withString:@"Hide"];
		[selectClusterOption removeItemAtIndex:idx];
		[selectClusterOption insertItemWithTitle:new_selection atIndex:idx];
		//make sure the waveforms view receives notification of highlights
		[[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) name:@"highlight" object:nil];
		selectedClusters = [[[NSIndexSet alloc] initWithIndexSet:indexes] retain];
	}
	
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

-(void)dealloc
{
    [timestamps release];
    [queue release];
	[selectedClusters release];
    [super dealloc];
    
}
@end
