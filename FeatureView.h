//
//  FeatureView.h
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Cluster.h"

static GLuint vertexBuffer;
static GLuint indexBuffer;
static GLuint colorBuffer;
static GLfloat *vertices;
static GLfloat *use_vertices;
static GLfloat *colors;
static GLfloat *use_colors;
static GLuint *indices;
static int nvertices;
static int nindices;

static unsigned int *cids;
int draw_dims[3];
int ndraw_dims;
int rows;
int cols;
static float *minmax;

static void pushVertices();
static void modifyVertices(GLfloat *vertex_data);
static void modifyIndices(GLuint *index_data);
static void modifyColors(GLfloat *color_data);
static BOOL dataloaded;

@interface FeatureView : NSOpenGLView {

    NSMutableIndexSet *indexset;
    
}

@property (retain,readwrite) NSMutableIndexSet *indexset;
-(void) loadVertices;
-(void) selectDimensions:(NSDictionary*)dims;
-(void) showCluster: (Cluster *)cluster;
-(void) hideCluster: (Cluster *)cluster;
-(void) setClusterColors: (GLfloat*)cluster_colors forIndices: (GLuint*)cluster_indices length:(NSUInteger)length;
-(void) rotateY;
-(void) rotateX;
-(void) rotateZ;
//-(void) pushVertices;

@end
