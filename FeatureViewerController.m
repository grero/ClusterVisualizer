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

-(void)awakeFromNib
{
    //[self setClusters:[NSMutableArray array]];
}

-(BOOL) acceptsFirstResponder
{
    return YES;
}

-(IBAction) loadFeatureFile: (id)sender
{
    [fw loadVertices];
    //load feature anems
    NSArray *feature_names = [[NSString stringWithContentsOfFile:@"../../feature_names.txt"] componentsSeparatedByString:@"\n"];
    [dim1 addItemsWithObjectValues:feature_names];
    [dim2 addItemsWithObjectValues:feature_names];
    [dim3 addItemsWithObjectValues:feature_names];
    
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
    
    header H;
    H = *readFeatureHeader("../../test2.hdf5", &H);
    int rows = H.rows;
    unsigned int *cids = malloc((rows+1)*sizeof(unsigned int));
    cids = readClusterIds("../../a101g0001waveforms.clu.1", cids);
    int i;
    NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:cids[0]];
    //count the number of points in each cluster
    int *npoints;
    npoints = calloc(cids[0],sizeof(int));
    for(i=0;i<rows;i++)
    {
        npoints[cids[i+1]]+=1;
    }
    int j;
    for(i=0;i<cids[0];i++)
    {
        Cluster *cluster = [[Cluster alloc] init];
        cluster.name = [NSString stringWithFormat: @"%d",i];
        cluster.active = 1;
        cluster.npoints = [NSNumber numberWithInt: npoints[i]];
        unsigned int *points = malloc(npoints[i]*sizeof(unsigned int));
        int k = 0;
        for(j=0;j<rows;j++)
        {
            if(cids[j+1]==i)
            {
                points[k] = j;
                k+=1;
            }
            
        }
        cluster.points = [NSData dataWithBytes:points length:npoints[i]*sizeof(unsigned int)];
        free(points);
        [tempArray addObject:cluster]; 
    }
    free(cids);
    free(npoints);
    
    
    [self setClusters:tempArray];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ClusterStateChanged:)
                                                 name:@"ClusterStateChanged" object:nil];
                                                       
}

-(void)insertObject:(Cluster *)p inClustersAtIndex:(NSUInteger)index {
    [Clusters insertObject:p atIndex:index];
}

-(void)removeObjectFromClustersAtIndex:(NSUInteger)index {
    [Clusters removeObjectAtIndex:index];
}

-(void)setClusters:(NSMutableArray *)a {
    Clusters= a;
}

-(NSArray*)Clusters {
    return Clusters;
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
    NSInteger state = [sender state];
    
    [Clusters makeObjectsPerformSelector:@selector(setActive:) withObject: (NSInteger*)state];
    
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
