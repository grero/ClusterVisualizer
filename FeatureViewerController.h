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
#import "utils.h"
#import "ProgressPanel.h"
#import "HistogramView.h"
#import "fileReaders.h"
#import "computeFeatures.h"
#import "RasterView.h"

@interface FeatureViewerController : NSController {
    
    NSMutableArray *Clusters;
    NSMutableArray *ClusterOptions;
    Cluster *activeCluster;
    NSArray *clusterModel;
    NSPredicate *isValidCluster, *filterClustersPredicate;
    NSMutableArray *clustersSortDescriptors;
    NSSortDescriptor *clustersSortDescriptor;
    NSData *vertex_data;
    NSData *timestamps;
	NSMutableArray *featureNames;
    header params;
    BOOL dataloaded;
	NSInteger nchannels;
    //name of current cluster set
    NSString *currentBaseName;
    NSString *waveformsFile;
    NSOperationQueue *queue;
    NSTimer *archiveTimer, *cycleTimer;
    IBOutlet FeatureView *fw;
    IBOutlet WaveformsView *wfv;
    IBOutlet NSComboBox *dim1;
    IBOutlet NSComboBox *dim2;
    IBOutlet NSComboBox *dim3;
    IBOutlet NSButton *allActive;
    IBOutlet NSPanel *filterClustersPanel;
    IBOutlet NSPopUpButton *selectClusterOption;  
    IBOutlet ProgressPanel *progressPanel;
    IBOutlet HistogramView *histView;
	IBOutlet RasterView *rasterView;
    
    
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
-(id)objectInClustersAtIndex: (NSUInteger)index;

-(void)addClusterOption:(NSString*)option;

-(void)ClusterStateChanged:(NSNotification*)notification;
-(void)mergeCluster: (Cluster *)cluster1 withCluster: (Cluster*)cluster2;
-(void)deleteCluster: (Cluster *)cluster;
-(void)loadWaveforms: (Cluster*)cluster;
-(void)readClusterModel:(NSString*)path;
-(void)performComputation:(NSString*)operationTitle usingSelector:(SEL)operationSelector;
-(void)archiveClusters;
-(void) openFeatureFile:(NSString*)path;
-(void) openWaveformsFile: (NSString*)path;
-(void) openClusterFile:(NSString *)path;
-(void) setAvailableFeatures:(NSArray*)channels;
-(void) receiveNotification:(NSNotification*)notification;
//This might go away
-(void) computeFeature:(NSData*)waveforms withChannels:(NSUInteger)channels andTimepoints:(NSUInteger)timepoints;
//
- (IBAction) loadFeatureFile: (id)sender;
- (IBAction) loadClusterIds: (id)sender;

//- (IBAction) loadWaveforms: (id)sender;
- (IBAction) changeDim1: (id)sender;
- (IBAction) changeDim2: (id)sender;
- (IBAction) changeDim3: (id)sender;
- (IBAction) changeAllClusters: (id)sender;
- (IBAction) performClusterOption: (id)sender;
- (IBAction) saveClusters:(id)sender;
- (IBAction) cycleDims: (id)sender;
-(void)cycleDimensionsUsingTimer:(NSTimer*)timer;

//@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet FeatureView *fw;
@property (assign) IBOutlet WaveformsView *wfv;
@property (assign) IBOutlet NSComboBox *dim1;
@property (assign) IBOutlet NSComboBox *dim2;
@property (assign) IBOutlet NSComboBox *dim3;
@property (assign) IBOutlet HistogramView *histView;
@property (assign) IBOutlet RasterView *rasterView;

@property (retain,readwrite) NSMutableArray *Clusters;
@property (retain,readwrite) NSMutableArray *ClusterOptions;
@property (retain, readwrite) NSPredicate *isValidCluster;
@property (retain, readwrite) NSPredicate *filterClustersPredicate;
@property (retain, readwrite) NSSortDescriptor *clustersSortDescriptor;
@property (retain, readwrite) NSMutableArray *clustersSortDescriptors;
@property (retain, readwrite) NSString *waveformsFile;
@property (assign,readwrite) Cluster *activeCluster;
@end
