//
//  RasterView.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 5/22/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static GLuint rVertexBuffer;
static GLuint rIndexBuffer;
static GLuint rColorBuffer;

@interface RasterView : NSView {
@private
    NSOpenGLContext *_oglContext;
    NSOpenGLPixelFormat *_pixelFormat;
	GLuint npoints;
    float xmin,xmax,ymin,ymax,zmin,zmax;
    NSMutableData *highlightedPoints;
	
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


-(void) createVertices: (NSData*)points;
-(void) highlightPoints: (NSDictionary*)params;

-(void) receiveNotification: (NSNotification*)notification;
@end
