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

-(void)awakeFromNib
{
    //[self setClusters:[NSMutableArray array]];
    dataloaded = NO;
    queue = [[[NSOperationQueue alloc] init] retain];
	currentBaseName = NULL;
    [self setFilterClustersPredicate:[NSPredicate predicateWithFormat: @"valid==YES"]];
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
                        
            
            while(file = [enumerator nextObject] )
            {
                if([file hasPrefix:filebase])
                {
                    char *filename = [[NSString pathWithComponents: [NSArray arrayWithObjects: directory,file,nil]] cStringUsingEncoding:NSASCIIStringEncoding];
                    H = *readFeatureHeader(filename, &H);
                    
                    tmp_data = malloc(H.rows*H.cols*sizeof(float));
                    tmp_data2 = malloc(H.rows*H.cols*sizeof(float));
                    tmp_data = readFeatureData(filename, tmp_data);
                    if(tmp_data == NULL)
                    {
                        //create an alert
                        NSAlert *alert = [NSAlert alertWithMessageText:@"Feature file could not be loaded" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
                        [alert runModal];
                        free(tmp_data);
                        return;
                        
                    }
                    //transpose
                    for(i=0;i<H.rows;i++)
                    { 
                        for(j=0;j<H.cols;j++)
                        {
                            tmp_data2[j*H.rows+i] = tmp_data[i*H.cols+j];
                        }
                    }
                    //scale
                    //vDSP_vsdiv(
                    [data appendBytes:tmp_data2 length: H.rows*H.cols*sizeof(float)];
                    free(tmp_data);
                    free(tmp_data2);
                    cols+=H.rows;
                    //feature names
                    //get basename
                    NSString *fn = [[[[file lastPathComponent] componentsSeparatedByString:@"_"] lastObject] stringByDeletingPathExtension]; 
                    for(j=0;j<H.rows;j++)
                    {
                        [feature_names addObject: [fn stringByAppendingFormat:@"%d",j+1]];
                    }
                    
                }
                
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
            //need to reshape
            tmp_data = malloc(rows*cols*sizeof(float));
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
        float max,min,l;
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
            vDSP_vsdiv(tmp_data2+i,cols,&l,tmp_data+i,cols,rows*cols);*/
            for(j=0;j<rows;j++)
            {
                tmp_data[j*cols+i] = 2*(tmp_data[j*cols+i]-min)/l-1;
            }
        }
        [data replaceBytesInRange:range withBytes:tmp_data length: rows*cols*sizeof(float)];
        free(tmp_data);
        [fw createVertices:data withRows:rows andColumns:cols];
        //[fw loadVertices: [openPanel URL]];
        [dim1 addItemsWithObjectValues:feature_names];
        [dim2 addItemsWithObjectValues:feature_names];
        [dim3 addItemsWithObjectValues:feature_names];
        dataloaded = YES;
        
        //get time data
		//NSLog(@"XYZF: Is this going to work?");
		//NSLog(@"Filebase: %@",filebase);
        NSArray *waveformfiles = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath: directory error: nil] 
                                   pathsMatchingExtensions:[NSArray arrayWithObjects:@"bin",nil]] filteredArrayUsingPredicate:
                                  [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", filebase]];
        //NSString *waveformsPath = @"";
        if( [waveformfiles count] == 1 )
        {
            [self setWaveformsFile: [waveformfiles objectAtIndex:0]];
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
	//register featureview for notification about change in highlight
	[[NSNotificationCenter defaultCenter] addObserver: fw selector:@selector(receiveNotification:) 
												 name:@"highlight" object: nil];

	//only reset clusters if data has already been loaded
    if( ([self Clusters] != NULL) && (dataloaded == YES ) )
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
    [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"clu",@"fv",@"overlap",nil]];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        [self openClusterFile:[[openPanel URL] path]];
    }
        
                                                       
}

- (void)openClusterFile:(NSString*)path;
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
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
        NSString *featurePath = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_.fd", basename]];
        [self openFeatureFile:featurePath];
    }
    if( [extension isEqualToString:@"fv"] )
    {
        tempArray = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        //get cluster colors
        //NSMutableData *_cluster_colors = [NSMutableData dataWithCapacity:params.rows*3*sizeof(float)];
        cluster_colors = malloc(params.rows*3*sizeof(float));
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
        
			char *fname = [path cStringUsingEncoding:NSASCIIStringEncoding];
			//TODO: Check if there is also an overlap present; if so, load it as well
			/*
			 header H;
			 H = *readFeatureHeader("../../test2.hdf5", &H);
			 int rows = H.rows;
			 */
			unsigned int *cids = malloc((rows+1)*sizeof(unsigned int));
			cids = readClusterIds(fname, cids);
			//find the maximum cluster number
			//TODO: this is quick and dirty; should try and speed this up
			unsigned int maxCluster = 0;
			int i;

			for(i=0;i<rows;i++)
			{
				if( cids[i+1] > maxCluster )
				{
					maxCluster = cids[i+1];
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
				npoints[cids[i+1]]+=1;
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
					if(cids[j+1]==i)
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
			free(cids);
			free(npoints);
			free(cluster_colors);

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
			unsigned i;
			
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
				
				[tempArray addObject:cluster];
			}
			//now loop through the overlap matrix, adding points to the clusters as we go along
			unsigned int cid,wfidx,npoints;
			cid = maxCluster+1;
			Cluster *cluster;
			for(i=0;i<ncols;i++)
			{
				wfidx = overlaps[ncols+i];
				if( overlaps[i] != cid )
				{
					cid = overlaps[i];
					cluster = [tempArray objectAtIndex:cid];
				}
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
	if( dataloaded == YES )
	{
		//only do this if data has been loaded
		[fw setClusterColors: cluster_colors forIndices: NULL length: 1];
	}
    //since colors are now ccopied, we can free it
    [self setClusters:tempArray];
    [self setIsValidCluster:[NSPredicate predicateWithFormat:@"valid==1"]];
    
    
    [selectClusterOption removeAllItems];
    NSMutableArray *options = [NSMutableArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",
                               @"Show waveforms",@"Filter clusters",@"Remove waveforms",@"Make Template",@"Undo Template",@"Compute XCorr",nil];
    if(timestamps!=NULL)
    {
        //only allow isi computation if timestamps are loaded
        [options addObject:@"Shortest ISI"];
    }
    
    //[selectClusterOption addItemsWithTitles: [NSArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Show waveforms",@"Filter clusters",
    //                                         @"Compute Isolation Distance",nil]];
    //[self setClusterOptions:[NSArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",@"Show waveforms",@"Filter clusters",nil]];
    
    [allActive setState:1];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
    //check for model file
    NSString *modelFilePath = [path stringByReplacingOccurrencesOfString: extension withString: @"model"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: modelFilePath ] )
    {
        [self readClusterModel:modelFilePath];
        [options addObject: @"Compute Isolation Distance"];
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
    [[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) 
                                                 name:@"highlight" object:nil];

    
}

- (void) loadWaveforms: (Cluster*)cluster
{
    if (waveformsFile == NULL)
    {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        //set a delegate for openPanel so that we can control which files can be opened
        [openPanel setDelegate:[[OpenPanelDelegate alloc] init]];
        //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
        [[openPanel delegate] setBasePath: currentBaseName];
        [[openPanel delegate] setExtensions: [NSArray arrayWithObjects: @"bin",nil]];
        int result = [openPanel runModal];
        if( result == NSOKButton )
        {
            //test
            //Cluster *cluster = [Clusters objectAtIndex: 3];
            [self setWaveformsFile:[[openPanel URL] path]];
        }
    }
    if (waveformsFile != NULL)
    {
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
        [[wfv window] orderFront: self];
        [wfv createVertices:[NSData dataWithBytes:fwaveforms length:wfSize*sizeof(float)] withNumberOfWaves: npoints channels: (NSUInteger)spikeHeader.channels andTimePoints: (NSUInteger)spikeHeader.timepts 
                   andColor:[cluster color]];
        free(waveforms);
        free(fwaveforms);
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
        }
    }
    else {
        [fw hideCluster: [notification object]];
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
    [[Clusters filteredArrayUsingPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: 
                                                                                               [NSCompoundPredicate notPredicateWithSubpredicate:predicate],
                                                                                               isActive,nil]]] makeObjectsPerformSelector:@selector(makeInactive)];
    //Activate those clusters for which the predicate is true and which are inactive
    [[Clusters filteredArrayUsingPredicate: [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects: 
                                                                                                [NSCompoundPredicate notPredicateWithSubpredicate:isActive],
                                                                                                 predicate,nil]]] makeObjectsPerformSelector:@selector(makeActive)];
}

- (IBAction) changeDim1: (id)sender
{
    [fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
}

- (IBAction) changeDim2: (id)sender
{
    [fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
    
}
- (IBAction) changeDim3: (id)sender
{
    [fw selectDimensions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:2],@"dim", [NSNumber numberWithInt: [sender indexOfSelectedItem]],@"dim_data",nil]];
    
}

- (IBAction) changeAllClusters: (id)sender
{
    //Temporarily remove notifcations
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (IBAction) performClusterOption: (id)sender
{
    NSString *selection = [sender titleOfSelectedItem];
    //get all selected clusters
    NSPredicate *testForTrue = [NSPredicate predicateWithFormat:@"active == YES"];
    NSArray *candidates = [Clusters filteredArrayUsingPredicate:testForTrue];
    //set the active cluster to the first candidate
    [self setActiveCluster:[candidates objectAtIndex:0]];
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
        [[NSNotificationCenter defaultCenter] removeObserver:self];

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
        [[NSNotificationCenter defaultCenter] addObserver:[self wfv] selector:@selector(receiveNotification:) 
                                                     name:@"highlight" object:nil];

    }
    else if ( [selection isEqualToString:@"Hide waveforms"] )
    {
        NSInteger idx = [sender indexOfSelectedItem];
        NSString *new_selection = [selection stringByReplacingOccurrencesOfString:@"Hide" withString:@"Show"];
        [sender removeItemAtIndex:idx];
        [sender insertItemWithTitle:new_selection atIndex:idx];
        [[NSNotificationCenter defaultCenter] removeObserver: [self wfv] name: @"highlight" object: nil];
        [[[self wfv] window] orderOut:self];
        
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
        if ( times[tpts[pts[0]+1]]-times[tpts[pts[0]]] < 1000)
        {
        
            unsigned int *spts = malloc(2*sizeof(unsigned int));
            spts[0] = pts[0];
            spts[1] = pts[0]+1;
            NSDictionary *params = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:
                                                                         [NSData dataWithBytes:spts length:2*sizeof(unsigned int)],[activeCluster color],nil]
                                                               forKeys: [NSArray arrayWithObjects:@"points",@"color",nil]];
            [[NSNotificationCenter defaultCenter] postNotificationName: @"highlight" object: params];
            free(spts);
        }
    }
    else if ( [selection isEqualToString:@"Remove waveforms"] )
    {
        
        if([fw highlightedPoints] != NULL)
        {
            //remove the currently selected waveforms
            unsigned int *selected = (unsigned int*)[[fw highlightedPoints] bytes];
            //unsigned int nselected = [[fw highlightedPoints] length]/sizeof(unsigned int);
            [[self activeCluster] setActive:0];
            [[Clusters objectAtIndex:0] setActive: 0];
            //[fw hideCluster:[self activeCluster]];
           
            
            [[self activeCluster ] removePoints:[NSData dataWithBytes: selected length: [[fw highlightedPoints] length]]];
            //recompute ISI
            //TODO: Not necessary to recompute everything here
            [[self activeCluster] computeISIs:timestamps];
            //add this point to the noise cluster
            [[Clusters objectAtIndex:0] addPoints:[fw highlightedPoints]];
            GLfloat *_color = (GLfloat*)[[[Clusters objectAtIndex:0] color] bytes];
            GLuint *_points = [[fw highlightedPoints] bytes];
            GLuint _length = [[fw highlightedPoints] length]/sizeof(unsigned int);
            //set the colors of the new cluster
            [fw setClusterColors:_color forIndices:_points length:_length];
            [[self activeCluster] setActive:1];
            //[[Clusters objectAtIndex:0] setActive: 1];
            //[fw showCluster:[self activeCluster]];
            //reset the highlighted waves
            /*
            NSDictionary *params = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:
                                                                         [NSData dataWithBytes:NULL length:0],[activeCluster color],nil]
                                                               forKeys: [NSArray arrayWithObjects:@"points",@"color",nil]];
            
            //remove the highlights
            [fw highlightPoints:params];
             */
            [[fw highlightedPoints] setLength:0];
            if([[wfv window] isVisible])
            {
                [wfv hideWaveforms:[wfv highlightWaves]];
                [[wfv highlightWaves] setLength: 0];
            }
            [fw setNeedsDisplay:YES];
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
        [cidx_string writeToFile:[NSString stringWithFormat: @"%@.clusters",currentBaseName] atomically:YES];
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
        [templateIdStr writeToFile:[NSString stringWithFormat:@"%@.scu",currentBaseName] atomically:YES];
        
        //also store the data
        
        [self archiveClusters];
    }
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
    } else {
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

-(void)dealloc
{
    [timestamps release];
    [queue release];
    [super dealloc];
    
}
@end
