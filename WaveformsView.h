//
//  WaveformsView.h
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>
#import "GLString.h"

static GLuint wfVertexBuffer;
static GLuint wfIndexBuffer;
static GLuint wfColorBuffer;
static GLuint wfPixelBuffer;
static GLfloat *wfVertices;
//static GLfloat *use_vertices;
static GLfloat *wfColors;
//static GLfloat *use_colors;
static GLuint *wfIndices;
static float *wfMinmax;
static float *chMinMax;
static float xmin,xmax,ymin,ymax;
static unsigned int num_spikes;
static unsigned int nWfVertices;
static unsigned int nWfIndices;
static unsigned int wavesize;
static unsigned int waveIndexSize;
static unsigned int chs;
static unsigned int timepts;
static unsigned int channelHop;
static int highlightWave;
static BOOL wfDataloaded;

static void wfPushVertices();
static void wfModifyVertices(GLfloat *vertex_data);
static void wfModifyIndices(GLuint *index_data);
static void wfModifyColors(GLfloat *color_data, GLfloat *color);

@interface WaveformsView : NSView {

    @private
    NSOpenGLContext *_oglContext;
    NSOpenGLPixelFormat *_pixelFormat;
    NSData *drawingColor,*highlightColor;
    NSMutableData *highlightWaves;
	NSMutableArray *highlightedChannels;
    
    
}

@property (retain,readwrite) NSMutableData *highlightWaves;
@property (retain,readwrite) NSMutableArray *highlightedChannels;

//OpenGL related functions
+(NSOpenGLPixelFormat*)defaultPixelFormat;
-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format;
-(void) setOpenGLContext: (NSOpenGLContext*)context;
-(NSOpenGLContext*)openGLContext;
-(void) clearGLContext;
-(void) prepareOpenGL;
-(void) update;
-(void) drawLabels;
-(void) setPixelFormat:(NSOpenGLPixelFormat*)pixelFormat;
-(NSOpenGLPixelFormat*)pixelFormat;
-(void) _surfaceNeedsUpdate:(NSNotification *)notification;
-(void) setColor:(NSData*)color;
-(NSData*)getColor;
-(NSData*)getHighlightColor;
-(BOOL)isOpaque;
//others
-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints andColor: (NSData*)color;
-(void) highlightWaveform:(NSUInteger)wfidx;
-(void) highlightWaveforms:(NSData*)wfidx;
-(void) highlightChannels:(NSArray*)channels;
-(void) receiveNotification:(NSNotification*)notification;
-(void) hideWaveforms:(NSData*)wfidx;
-(NSImage*)image;
-(void) createAxis;

@end
