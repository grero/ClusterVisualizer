//
//  FeatureView.h
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/glu.h>
#import "Cluster.h"
#import "GLString.h"


static GLuint vertexBuffer;
static GLuint indexBuffer;
static GLuint colorBuffer;
static GLfloat *vertices;
static GLfloat *use_vertices;
static GLfloat *colors;
static GLfloat *use_colors;
static GLfloat base_color[3];
static GLuint *indices;
static GLfloat pickedPoint[3];
static int nvertices;
static int nindices;

static unsigned int *cids;
int draw_dims[3];
int ndraw_dims;
int rows;
int cols;
static float *minmax;
static float scale;
static float rotatex,rotatey,rotatez;
static float originx,originy,originz;

static void pushVertices();
static void drawBox();
static void modifyVertices(GLfloat *vertex_data);
static void modifyIndices(GLuint *index_data);
static void modifyColors(GLfloat *color_data);
static BOOL dataloaded;
static BOOL picked;

@interface FeatureView : NSView {

    NSMutableIndexSet *indexset;
    NSMutableData *highlightedPoints;
    NSData *highlightedClusterPoints;
    NSMutableData *rotation;
    @private
    NSOpenGLContext* _oglContext;
    NSOpenGLPixelFormat* _pixelFormat;
	GLString *glabelX,*glabelY,*glabelZ;
    BOOL drawAxesLabels,appendHighlights;
    Cluster *currentCluster;
    NSMutableArray *selectedClusters;
    
    
}

@property (retain,readwrite) NSMutableIndexSet *indexset;
@property (retain,readwrite) NSMutableData *highlightedPoints;
@property (retain,readwrite) NSData *highlightedClusterPoints;

+(NSOpenGLPixelFormat*)defaultPixelFormat;
-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format;
-(void) setOpenGLContext: (NSOpenGLContext*)context;
-(NSOpenGLContext*)openGLContext;
-(void) clearGLContext;
-(void) prepareOpenGL;
-(void) update;
-(void) setPixelFormat:(NSOpenGLPixelFormat*)pixelFormat;
-(NSOpenGLPixelFormat*)pixelFormat;
-(void) _surfaceNeedsUpdate:(NSNotification *)notification;
- (void) loadVertices: (NSURL*)url;
-(void) createVertices: (NSData*)vertex_data withRows: (NSUInteger)r andColumns: (NSUInteger)c ;
-(void) selectDimensions:(NSDictionary*)dims;
-(void) showCluster: (Cluster *)cluster;
-(void) hideCluster: (Cluster *)cluster;
-(void) hideAllClusters;
-(void) showAllClusters;
-(void) setClusterColors: (GLfloat*)cluster_colors forIndices: (GLuint*)cluster_indices length:(NSUInteger)length;
-(void) highlightPoints:(NSDictionary*)params inCluster: (Cluster*)cluster;
-(void) receiveNotification:(NSNotification*)notification;
-(void) rotateY;
-(void) rotateX;
-(void) rotateZ;
-(void) zoomIn;
-(void) zoomOut;
-(void) resetZoom;
-(void) changeZoom;
-(void) drawLabels;
-(void) setDrawLabels: (BOOL)_drawLabels;
-(NSImage*)image;
//-(void) drawBox;
-(NSData*)getVertexData;
//-(void) pushVertices;

@end
