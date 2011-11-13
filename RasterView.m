//
//  RasterView.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 5/22/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "RasterView.h"


@implementation RasterView

-(BOOL)acceptsFirstResponder
{
    return YES;
}
-(void)awakeFromNib
{
	int i = 0;
    xmin = 0;
    xmax = 1000;
    ymax = 100.0;
    ymin = 0;
    zmin = -1;
    zmax = 1;
}

+(NSOpenGLPixelFormat*) defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAllRenderers,YES,
        NSOpenGLPFADoubleBuffer, YES,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 16,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    return pixelFormat;
}



-(id) initWithFrame:(NSRect)frameRect
{
    return [self initWithFrame:frameRect pixelFormat: [RasterView defaultPixelFormat]];
	
}

-(id) initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format
{
    self = [super initWithFrame:frameRect];
    if( self != nil)
    {
        _pixelFormat = [format retain];
        [self setOpenGLContext: [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil]];
        [[self openGLContext] makeCurrentContext];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector:@selector(_surfaceNeedsUpdate:)
                                                     name: NSViewGlobalFrameDidChangeNotification object: self];        
    }
    return self;
}

-(void) _surfaceNeedsUpdate:(NSNotification*)notification
{
    [self update];
}

-(void) lockFocus
{
    NSOpenGLContext *context = [self openGLContext];
    
    [super lockFocus];
    if( [context view] != self )
    {
        [context setView:self];
    }
    [context makeCurrentContext];
}

-(BOOL) isOpaque
{
    return YES;
}

-(void) setOpenGLContext:(NSOpenGLContext *)context
{
    _oglContext = [context retain];
}

-(NSOpenGLContext*)openGLContext
{
    return _oglContext;
}

-(void)clearGLContext
{
    [[self openGLContext] clearCurrentContext];
    [[self openGLContext] release];
}

-(void)setPixelFormat:(NSOpenGLPixelFormat *)pixelFormat
{
    _pixelFormat = [pixelFormat retain];
}

-(NSOpenGLPixelFormat*)pixelFormat
{
    return _pixelFormat;
}

-(void)update
{
    if( [[self openGLContext] view] == self)
    {
		[self reshape];
        [[self openGLContext] update];
    }
}

- (void) reshape
{
    NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
}


-(void) prepareOpenGL
{
	[[self openGLContext] makeCurrentContext];
	NSRect bounds = [self bounds];
	glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
	glClearColor(0,0, 0, 0);
    glClearDepth(1.0);
	glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
	glShadeModel(GL_SMOOTH);
    glPointSize(4.0);
	glEnable(GL_BLEND);
    glEnable(GL_POINT_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_DST_ALPHA);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	[[self openGLContext] flushBuffer];
	
}

-(void)createVertices: (NSData*)points
{
	npoints = [points length];
	npoints = npoints/sizeof(unsigned long long int);
	//create an index
	int i;
	GLuint *_indices = NSZoneMalloc([self zone], npoints*sizeof(GLuint));
	GLfloat *_colors = NSZoneMalloc([self zone], 4*npoints*sizeof(GLfloat));
	GLfloat *_vertices = NSZoneMalloc([self zone], 3*npoints*sizeof(GLfloat));
	unsigned long long int *_points = (unsigned long long int*)[points bytes];
    unsigned int tidx;
    //xmax
    xmax = -INFINITY;
	for(i=0;i<npoints;i++)
	{
		_indices[i] = i;
		_colors[3*i] = 1.0;
		_colors[3*i+1] = 0.0;
		_colors[3*i+2] = 0.0;
		_colors[3*i+3] = 1.0;
		
		_vertices[3*i] = (GLfloat)((double)(_points[i])/1000);
        
		//_vertices[3*i+1] = 50.0;
        tidx = (unsigned int)(_vertices[3*i]/30000.0);
        _vertices[3*i] -= tidx*30000.0;
        _vertices[3*i+1] = (GLfloat)(tidx);
		_vertices[3*i+2] = 0.3;
		if(_vertices[3*i]>xmax)
            xmax = _vertices[3*i];
        if(_vertices[3*i+1] > ymax )
            ymax = _vertices[3*i+1];
	}
	[[self openGLContext] makeCurrentContext];
	glGenBuffers(1,&rIndexBuffer);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, rIndexBuffer);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, npoints*sizeof(GLuint), _indices, GL_DYNAMIC_DRAW);
	
	glGenBuffers(1, &rColorBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, rColorBuffer);
	glBufferData(GL_ARRAY_BUFFER, 4*npoints*sizeof(GLfloat), _colors, GL_DYNAMIC_DRAW);
	
	glGenBuffers(1, &rVertexBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, rVertexBuffer);
	glBufferData(GL_ARRAY_BUFFER,3*npoints*sizeof(GLfloat), _vertices, GL_DYNAMIC_DRAW);
	
	NSZoneFree([self zone], _indices);
	NSZoneFree([self zone], _colors);
	NSZoneFree([self zone], _vertices);
	[self setNeedsDisplay:YES];
}

-(void)drawRect:(NSRect)bounds
{
	[[self openGLContext] makeCurrentContext];
	glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
	
	glClearColor(0.0,0.0,0.0,1.0);
	glClearDepth(1.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(xmin, xmax, ymin, ymax, zmin, zmax);
	//glMatrixMode(GL_MODELVIEW);
	//glLoadIdentity();
	
	glBindBuffer(GL_ARRAY_BUFFER, rVertexBuffer);
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(3, GL_FLOAT, 0, (void*)0);
	
	glBindBuffer(GL_ARRAY_BUFFER, rColorBuffer);
	glEnableClientState(GL_COLOR_ARRAY);
	glColorPointer(4, GL_FLOAT, 0, (void*)0);
	
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, rIndexBuffer);
	glIndexPointer(GL_UNSIGNED_INT, 0, (void*)0);
	glEnableClientState(GL_INDEX_ARRAY);
	
	glDrawElements(GL_POINTS,npoints,GL_UNSIGNED_INT, (void*)0);
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_INDEX_ARRAY);
	[[self openGLContext] flushBuffer];
}

-(void) highlightPoints: (NSDictionary *)params
{
    NSData *points = [params objectForKey:@"points"];
    unsigned int *_points = (unsigned int*)[points bytes];
    unsigned int _npoints = [points length]/sizeof(unsigned int);
    unsigned int i,k;
    //change colors; first reset colors of already highlihted points
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, rColorBuffer);
    GLfloat *_colors = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    if (highlightedPoints != NULL )
    {
        unsigned int *_hpoints = (unsigned int*)[highlightedPoints bytes];
        unsigned int _nhpoints = [highlightedPoints length]/(sizeof(unsigned int));
        for(i=0;i<_nhpoints;i++)
        {
            k = _hpoints[i];
            _colors[4*k] = 1-_colors[4*k];
            _colors[4*k+1] = 1-_colors[4*k+1];
            _colors[4*k+2] = 1-_colors[4*k+2];

        }
        [highlightedPoints setData:[NSData dataWithData:points]];
    }
    else
    {
        highlightedPoints = [[NSMutableData dataWithData:points] retain];
    }
    for(i=0;i<_npoints;i++)
    {
        k = _points[i];
        _colors[4*k] = 1-_colors[4*k];
        _colors[4*k+1] = 1-_colors[4*k+1];
        _colors[4*k+2] = 1-_colors[4*k+2];

                                   
    }
    //done with color buffer
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [self setNeedsDisplay:YES];
}

-(void) receiveNotification: (NSNotification*)notification
{
    if( [[notification name] isEqualToString:@"highlight"] )
    {
        [self highlightPoints:[notification userInfo]];
    }
}
	
@end
