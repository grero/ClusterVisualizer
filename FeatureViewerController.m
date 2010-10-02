//
//  FeatureViewerController.m
//
//  Created by Grogee on 9/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FeatureViewerController.h"

@implementation FeatureViewerController

@synthesize fw;
@synthesize dim1;
@synthesize dim2;
@synthesize dim3;
@synthesize Clusters;
@synthesize ClusterOptions;
@synthesize isValidCluster;

-(void)awakeFromNib
{
    //[self setClusters:[NSMutableArray array]];
    dataloaded = NO;
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
        NSMutableData *data = [NSMutableData dataWithCapacity:100000*sizeof(float)];
        NSMutableArray *feature_names = [NSMutableArray arrayWithCapacity:16];
        //geth the base path
        NSString *path = [[openPanel URL] path];
        NSString *filebase = [[[path lastPathComponent] componentsSeparatedByString:@"_"] objectAtIndex:0]; 
        currentBaseName = [[NSString stringWithString:filebase] retain];
        NSString *directory = [[openPanel directoryURL] path];
        //set the current directory of the process to the the one pointed to by the load dialog
        [[NSFileManager defaultManager] changeCurrentDirectoryPath:directory];
        NSArray *dir_contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: directory error: nil] pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",nil]];
        //get all feature files, i.e. files ending in .fd from the FD directory
        //NSArray *dir_contents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"FD"] error: NULL] 
         //                        pathsMatchingExtensions:[NSArray arrayWithObjects:@"fd",nil]];
        
        NSEnumerator *enumerator = [dir_contents objectEnumerator];
        id file;
        header H;
        float *tmp_data,*tmp_data2;
        int cols=0;
        int rows = 0;
        int i,j,k;
        
        while(file = [enumerator nextObject] )
        {
            if([file hasPrefix:filebase])
            {
                char *filename = [[NSString pathWithComponents: [NSArray arrayWithObjects: directory,file,nil]] cStringUsingEncoding:NSASCIIStringEncoding];
                H = *readFeatureHeader(filename, &H);
                
                tmp_data = malloc(H.rows*H.cols*sizeof(float));
                tmp_data2 = malloc(H.rows*H.cols*sizeof(float));
                tmp_data = readFeatureData(filename, tmp_data);
                //transpose
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
                NSString *fn = [[[file componentsSeparatedByString:@"_"] objectAtIndex:1] stringByDeletingPathExtension]; 
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
        tmp_data2 = [data bytes];
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
        NSRange range;
        range.location = 0;
        range.length = rows*cols*sizeof(float);
        [data replaceBytesInRange:range withBytes:tmp_data length: rows*cols*sizeof(float)];
        free(tmp_data);
        [fw createVertices:data withRows:rows andColumns:cols];
        //[fw loadVertices: [openPanel URL]];
        [dim1 addItemsWithObjectValues:feature_names];
        [dim2 addItemsWithObjectValues:feature_names];
        [dim3 addItemsWithObjectValues:feature_names];
        dataloaded = YES;
    
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
    
}

- (IBAction) loadClusterIds: (id)sender
{
    //TODO: the following is inefficient as it reads the header, which has already been read by the view. Only use this for testing
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    //set a delegate for openPanel so that we can control which files can be opened
    [openPanel setDelegate:[[OpenPanelDelegate alloc] init]];
    //set the basePath to the current basepath so that only cluster files compatible with the currently loaded feature files are allowed
    [[openPanel delegate] setBasePath: currentBaseName];
    [[openPanel delegate] setExtension: @"clu"];
    int result = [openPanel runModal];
    if( result == NSOKButton )
    {
        [[NSNotificationCenter defaultCenter] removeObserver: self];
        //remove all the all clusters
        //[self removeAllObjectsFromClusters];
        char *fname = [[[openPanel URL] path] cStringUsingEncoding:NSASCIIStringEncoding];
        /*
        header H;
        H = *readFeatureHeader("../../test2.hdf5", &H);
        int rows = H.rows;
         */
        unsigned int *cids = malloc((rows+1)*sizeof(unsigned int));
        cids = readClusterIds(fname, cids);
        int i;
        NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:cids[0]];
        //count the number of points in each cluster
        unsigned int *npoints;
        npoints = calloc(cids[0],sizeof(unsigned int));
        float *cluster_colors = malloc(rows*3*sizeof(float));
        for(i=0;i<rows;i++)
        {
            npoints[cids[i+1]]+=1;
        }
        int j;
        for(i=0;i<cids[0];i++)
        {
            Cluster *cluster = [[Cluster alloc] init];
            cluster.name = [NSString stringWithFormat: @"%d",i];
            [cluster setActive: 1];
            cluster.npoints = [NSNumber numberWithUnsignedInt: npoints[i]];
            cluster.indices = [NSMutableIndexSet indexSet];
            cluster.valid = 1;
            //set color
            float color[3];
            color[0] = ((float)rand())/RAND_MAX;
            color[1] = ((float)rand())/RAND_MAX;
            color[2] = ((float)rand())/RAND_MAX;
            cluster.color = [NSData dataWithBytes: color length:3*sizeof(float)];
            unsigned int *points = malloc(npoints[i]*sizeof(unsigned int));
            int k = 0;
            for(j=0;j<rows;j++)
            {
                if(cids[j+1]==i)
                {
                    points[k] = j;
                    k+=1;
                    //set the colors at the same time
                    cluster_colors[3*j] = color[0];
                    cluster_colors[3*j+1] = color[1];
                    cluster_colors[3*j+2] = color[2];
                    [[cluster indices] addIndex: (NSUInteger)j];
                    
                }
                
            }
            cluster.points = [NSData dataWithBytes:points length:npoints[i]*sizeof(unsigned int)];
            free(points);
            [tempArray addObject:cluster]; 
        }
        free(cids);
        free(npoints);
        //tell the view to change the colors
        [fw setClusterColors: cluster_colors forIndices: NULL length: 1];
        //since colors are now ccopied, we can free it
        free(cluster_colors);
        [self setClusters:tempArray];
        [self setIsValidCluster:[NSPredicate predicateWithFormat:@"valid==1"]];
        [self setClusterOptions:[NSArray arrayWithObjects:@"Show all",@"Hide all",@"Merge",@"Delete",nil]];
        [allActive setState:1];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ClusterStateChanged:)
                                                     name:@"ClusterStateChanged" object:nil];
    }
                                                       
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


-(void)ClusterStateChanged:(NSNotification*)notification
{
    if( [[notification object] active] )
    {
        [fw showCluster:[notification object]];
    }
    else {
        [fw hideCluster: [notification object]];
    }

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
    }
    else {
        [Clusters makeObjectsPerformSelector:@selector(makeActive)];
    }
    [fw hideAllClusters];
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
                [cluster_indices setObject: [NSNumber numberWithUnsignedInteger: (NSUInteger)clusteridx[i]] forKey:[cluster name]];
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
        [cidx_string writeToFile:@"FeatureViewer.clusters" atomically:YES];
    }
}

-(void)mergeCluster: (Cluster *)cluster1 withCluster: (Cluster*)cluster2
{
    Cluster *new_cluster = [[Cluster alloc] init];
    new_cluster.name = [[cluster1.name stringByAppendingString: @"+"] stringByAppendingString:cluster2.name];
    new_cluster.npoints = [NSNumber numberWithUnsignedInt: [[cluster1 npoints] unsignedIntValue] + [[cluster2 npoints] unsignedIntValue]];
    NSMutableData *points = [NSMutableData dataWithCapacity:[[new_cluster npoints] unsignedIntValue]*sizeof(unsigned int)];
    [points appendData:cluster1.points];
    [points appendData:cluster2.points];
    new_cluster.points = points;
    //set the new cluster color to that of the first cluster
    new_cluster.color = [NSData dataWithData: cluster1.color];
    new_cluster.valid = 1;
    //new_cluster.color[0] = cluster1.color[0];
    //new_cluster.color[0] = cluster1.color[0];
    //add the cluster to the list of clusters
    
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
    [fw setClusterColors:[[new_cluster color] bytes] forIndices:[[new_cluster points] bytes] length:[[new_cluster npoints] unsignedIntValue]];
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

@end
