//
//  WaveformsView.h
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static GLuint vertexBuffer;
static GLuint indexBuffer;
static GLuint colorBuffer;
static GLfloat *vertices;
//static GLfloat *use_vertices;
static GLfloat *colors;
//static GLfloat *use_colors;
static GLuint *indices;
static float *minmax;

static int nvertices;
static int nindices;
static int wavesize;
static BOOL dataloaded;

static void pushVertices();
static void modifyVertices(GLfloat *vertex_data);
static void modifyIndices(GLuint *index_data);
static void modifyColors(GLfloat *color_data);

@interface WaveformsView : NSOpenGLView {

    
}
-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints;


@end
