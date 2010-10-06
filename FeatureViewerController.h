//
//  FeatureViewerController.h
//
//  Created by Grogee on 9/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>
#import "FeatureView.h"
#import "WaveformsView.h"
#import "Cluster.h"
#import "readFeature.h"
#import "nptLoadingEngine.h"
#import "OpenPanelDelegate.h"

@interface FeatureViewerController : NSController/* Specify a superclass (eg: NSObject or NSView) */ {
    
    NSMutableArray *Clusters;
    NSMutableArray *ClusterOptions;
    NSPredicate *isValidCluster, *filterClustersPredicate;
    NSData *vertex_data;
    header params;
    BOOL dataloaded;
    //name of current cluster set
    NSString *currentBaseName;
    IBOutlet FeatureView *fw;
    IBOutlet WaveformsView *wfv;
    IBOutlet NSComboBox *dim1;
    IBOutlet NSComboBox *dim2;
    IBOutlet NSComboBox *dim3;
    IBOutlet NSButton *allActive;
    IBOutlet NSPanel *filterClustersPanel;
    
}
-(void)insertObject:(Cluster *)p inClustersAtIndex:(NSUInteger)index;
-(void)removeObjectFromClustersAtIndex:(NSUInteger)index;
-(void)removeAllObjectsFromClusters;
-(void)setClusters:(NSMutableArray *)a;
-(NSArray*)Clusters;


-(void)setClusterOptions:(NSMutableArray *)a;
-(NSArray*)ClusterOptions;
-(void)insertObject:(NSString *)p inClusterOptionsAtIndex:(NSUInteger)index;
-(void)removeObjectFromClusterOptionsAtIndex:(NSUInteger)index;


-(void)ClusterStateChanged:(NSNotification*)notification;
-(void)mergeCluster: (Cluster *)cluster1 withCluster: (Cluster*)cluster2;
-(void)deleteCluster: (Cluster *)cluster;
-(void)loadWaveforms: (Cluster*)cluster;

- (IBAction) loadFeatureFile: (id)sender;
- (IBAction) loadClusterIds: (id)sender;
//- (IBAction) loadWaveforms: (id)sender;
- (IBAction) changeDim1: (id)sender;
- (IBAction) changeDim2: (id)sender;
- (IBAction) changeDim3: (id)sender;
- (IBAction) changeAllClusters: (id)sender;
- (IBAction) performClusterOption: (id)sender;
- (IBAction) saveClusters:(id)sender;

//@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet FeatureView *fw;
@property (assign) IBOutlet WaveformsView *wfv;
@property (assign) IBOutlet NSComboBox *dim1;
@property (assign) IBOutlet NSComboBox *dim2;
@property (assign) IBOutlet NSComboBox *dim3;
@property (retain,readwrite) NSMutableArray *Clusters;
@property (retain,readwrite) NSMutableArray *ClusterOptions;
@property (retain, readwrite) NSPredicate *isValidCluster;
@property (retain, readwrite) NSPredicate *filterClustersPredicate;
@end
