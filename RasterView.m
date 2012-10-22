//
//  RasterView.m
//  FeatureViewer
//
//  Created by Roger Herikstad on 5/22/11.
//  Copyright 2011 NUS. All rights reserved.
//

#import "RasterView.h"
#ifndef PI
#define PI 3.141592653589793
#endif

static void drawCircle(GLfloat r, GLuint n)
{
    int i;
    float dt = 2*PI/n;
    float x,y,z;
    z = 0;
    
    glBegin(GL_LINE_LOOP);
    for(i=0;i<n;i++)
    {
        x = r*cos(i*dt);
        y = r*sin(i*dt);
        glVertex3f(x, y, z);
        glColor3f(1.0, 0.0, 0.0);
    }
    glEnd();
}

@implementation RasterView

@synthesize drawHightlightCircle;

-(BOOL)acceptsFirstResponder
{
    return YES;
}
-(void)awakeFromNib
{
    xmin = 0;
    xmax = 1000;
    ymax = 100.0;
    ymin = 0;
    zmin = -1;
    zmax = 1;
    yscale = 1.0;
    xscale = 100;
    dataLoaded = NO;
    picked.x = -100;
    picked.y = -100;
    [self setDrawHightlightCircle:YES];
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
    NSOpenGLPixelFormat *pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
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
        [self setOpenGLContext: [[[NSOpenGLContext alloc] initWithFormat:format shareContext:nil] autorelease]];
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
    [[self openGLContext] makeCurrentContext];
    [NSOpenGLContext clearCurrentContext];
    //[[self openGLContext] release];
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
        [[self openGLContext] makeCurrentContext];
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
-(void)createVertices: (NSData*)points withColor: (NSData*)color
{
    [self createVertices:points withColor:color andRepBoundaries:nil];
}

-(void)createVertices:(NSData *)points withColor:(NSData *)color andRepBoundaries:(NSData*)boundaries
{
    //make sure no points are highlgihted
    highlightedPoints = NULL;
    GLfloat *_color = (GLfloat *)[color bytes];
	npoints = [points length];
	npoints = npoints/sizeof(unsigned long long int);
    	//create an index
	int i;
	GLuint *_indices = NSZoneMalloc([self zone], npoints*sizeof(GLuint));
	GLfloat *_colors = NSZoneMalloc([self zone], 4*npoints*sizeof(GLfloat));
	GLfloat *_vertices = NSZoneMalloc([self zone], 3*npoints*sizeof(GLfloat));
	unsigned long long int *_points = (unsigned long long int*)[points bytes];
    unsigned int tidx,j;
    double *_boundaries = NULL;
    unsigned int _nboundaries = 0;
    double repDuration = [[NSUserDefaults standardUserDefaults] doubleForKey:@"stimulusRepetitionDuration"];
    double tscale = [[NSUserDefaults standardUserDefaults] doubleForKey:@"timeScaleFactor"];
    if(tscale == 0)
    {
        tscale = 1000.0;
    }
    if( repDuration == 0)
    {
        repDuration = 30000.0;
    }
    if(boundaries != nil )
    {
        _boundaries = (double*)[boundaries bytes];
        _nboundaries = [boundaries length]/sizeof(double);
        /*
        if(_boundaries[0]==0)
        {
            //skip zero
            _boundaries+=1;
            _nboundaries-=1;
        }*/
    }

    //xmax
    xmax = -INFINITY;
	ymax = -INFINITY;
	ymin = 0;
    j = 0;
	for(i=0;i<npoints;i++)
	{
		_indices[i] = i;
		_colors[4*i] = _color[0];
		_colors[4*i+1] = _color[1];
		_colors[4*i+2] = _color[2];
		_colors[4*i+3] = 1.0;
		
		_vertices[3*i] = (GLfloat)((double)(_points[i])/tscale);
        
		//_vertices[3*i+1] = 50.0;
        if (_boundaries == NULL )
        {
            tidx = (unsigned int)(_vertices[3*i]/repDuration);
            _vertices[3*i] -= tidx*repDuration;
            //NSLog(@"No stimulus frame information found. Assuming 30 second repetitions");
        }
        else
        {
            while( (_vertices[3*i]>_boundaries[j] ) && (j < _nboundaries) )
            {
                j+=1;
            }
            //get the largest boundary point smaller than _vertices[3*i]
            tidx = j-1;
            _vertices[3*i]-=_boundaries[tidx];
        }
        _vertices[3*i+1] = (GLfloat)(tidx);
        //in the future, the z-value could be used to i.e. segregate into frames
        //for now, use z-value equal to y-value
		_vertices[3*i+2] = 0.3;
		if(_vertices[3*i]>xmax)
            xmax = _vertices[3*i];
        if(_vertices[3*i+1] > ymax )
        {
            ymax = _vertices[3*i+1];
        }
        else if (_vertices[3*i+1] < ymin )
        {
            ymin = _vertices[3*i+1];
        }
	}
    //rescale x-vertex
    for(i=0;i<npoints;i++)
    {
        _vertices[3*i] = (_vertices[3*i]/xmax)*xscale;
    }
    xmax = xscale;
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
    //[self display];
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
    float _xmin,_xmax,_ymin,_ymax,rx,ry;
    rx = xmax-xmin;
    ry = ymax-ymin;
    _xmin = xmin-0.05*rx;
    _xmax = xmax + 0.05*rx;
    _ymin = ymin-0.05*ry;
    _ymax = ymax+0.05*ry;
	glOrtho(_xmin, _xmax, _ymin, _ymax, zmin, zmax);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
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
    if( [self drawHightlightCircle] )
    {
        glPushMatrix();
        glTranslatef(picked.x, picked.y, 0);
        drawCircle(5.0, 150);
        glPopMatrix();
    }

	[[self openGLContext] flushBuffer];
}

-(void) highlightPoints: (NSDictionary *)params
{
    NSData *points = [params objectForKey:@"points"];
    unsigned int *_points = (unsigned int*)[points bytes];
    unsigned int _npoints = [points length]/sizeof(unsigned int);
    if(_npoints > 0)
    {
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, rVertexBuffer);
        float *_vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
        picked.x = _vertices[3*(_points[0])];
        picked.y = _vertices[3*(_points[0])+1];
        glUnmapBuffer(GL_ARRAY_BUFFER);
    }
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

-(void)mouseUp:(NSEvent *)theEvent
{
    //get the current points
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    GLint view[4];
    GLdouble p[16];
    GLdouble m[16];
    
    [[self openGLContext] makeCurrentContext];
    glGetDoublev (GL_MODELVIEW_MATRIX, m);
    glGetDoublev (GL_PROJECTION_MATRIX,p);
    glGetIntegerv( GL_VIEWPORT, view );
    double objXNear, objYNear,objZNear;
    GLfloat depth[2];
    //get the z-component
    glReadPixels(currentPoint.x, currentPoint.y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, depth);
    //get object coordinates
    gluUnProject(currentPoint.x, currentPoint.y, depth[0], m, p, view, &objXNear, &objYNear, &objZNear);
    
    
    double dmin = INFINITY;
    double dT = INFINITY;
    //get a handle for the vertices
    glBindBuffer(GL_ARRAY_BUFFER, rVertexBuffer);
    GLfloat *use_vertices = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
    int i,wfidx;
    //since we are using orthogonal projection, we simply compute the minimum euclidian distance
    for(i=0;i<npoints;i++)
    {
        double v[3];
        double rv = 0;
        v[0] = ((double)use_vertices[3*i]-objXNear);
        rv+=v[0]*v[0];
        v[1] = ((double)use_vertices[3*i+1]-objYNear);
        rv+=v[1]*v[1];
        //v[2] = (use_vertices[3*i+2]-objZNear);
        //rv+=v[2]*v[2];
        
        //this is the distance from the object to the ray
        rv = sqrt(rv);
        //check if it's the smallest so far, and that it's smaller than the threshold, dT
        if( (rv<dmin) )
        {
            dmin = rv;
            wfidx = i;
            if( rv < dT)
            {
                
                wfidx = i;	
            }
        }

    }
    picked.x = use_vertices[3*wfidx];
    picked.y = use_vertices[3*wfidx+1];;
    //if command key was pressed, add the currently selected point to the already highlighted points
    NSMutableData *wfidxData = [NSMutableData dataWithBytes: &wfidx length: sizeof(unsigned int)];
    if( ([theEvent modifierFlags] & NSCommandKeyMask) && (highlightedPoints != NULL) )
    {
        [wfidxData appendData:highlightedPoints];
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, rColorBuffer);
    
    GLfloat *_colors = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
    NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:wfidxData,                                                                    [NSData dataWithBytes: _colors+4*wfidx length:3*sizeof(float)],nil] forKeys: [NSArray arrayWithObjects: @"points",@"color",nil]];
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:self userInfo: params];
    
}
	
@end
