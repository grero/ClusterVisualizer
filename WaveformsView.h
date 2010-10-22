//
//  WaveformsView.h
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>

static GLuint wfVertexBuffer;
static GLuint wfIndexBuffer;
static GLuint wfColorBuffer;
static GLfloat *wfVertices;
//static GLfloat *use_vertices;
static GLfloat *wfColors;
//static GLfloat *use_colors;
static GLuint *wfIndices;
static float *wfMinmax;
static unsigned int num_spikes;
static unsigned int nWfVertices;
static unsigned int nWfIndices;
static unsigned int wavesize;
static int highlightWave;
static BOOL wfDataloaded;

static void wfPushVertices();
static void wfModifyVertices(GLfloat *vertex_data);
static void wfModifyIndices(GLuint *index_data);
static void wfModifyColors(GLfloat *color_data);

@interface WaveformsView : NSView {

    @private
    NSOpenGLContext *_oglContext;
    NSOpenGLPixelFormat *_pixelFormat;
    
}
//OpenGL related functions
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


//others
-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints;
-(void) highlightWaveform:(NSUInteger)wfidx;

@end
