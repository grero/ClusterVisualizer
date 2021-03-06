//
//  RasterView.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 5/22/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/glu.h>

static GLuint rVertexBuffer;
static GLuint rIndexBuffer;
static GLuint rColorBuffer;

static void drawCircle(GLfloat r, GLuint n);

@interface RasterView : NSView {
@private
    NSOpenGLContext *_oglContext;
    NSOpenGLPixelFormat *_pixelFormat;
	GLuint npoints;
    float xmin,xmax,ymin,ymax,zmin,zmax,xscale,yscale;
    NSMutableData *highlightedPoints;
    BOOL drawHighlightCircle,dataLoaded;
    NSPoint picked;
	
}

//OpenGL related functions
+(NSOpenGLPixelFormat*)defaultPixelFormat;
-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format;
-(void) setOpenGLContext: (NSOpenGLContext*)context;
-(NSOpenGLContext*)openGLContext;
-(void) clearGLContext;
-(void) prepareOpenGL;
-(void) update;
-(void) reshape;
-(void) setPixelFormat:(NSOpenGLPixelFormat*)pixelFormat;
-(NSOpenGLPixelFormat*)pixelFormat;
-(void) _surfaceNeedsUpdate:(NSNotification *)notification;
-(void)createVertices:(NSData *)points withColor:(NSData *)color andRepBoundaries:(NSData*)boundaries;

-(void) createVertices: (NSData*)points withColor:(NSData*)color;
-(void) highlightPoints: (NSDictionary*)params;

-(void) receiveNotification: (NSNotification*)notification;

@property (assign,readwrite) BOOL drawHightlightCircle;

@end
