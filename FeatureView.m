//
//  FeatureView.m
//
//  Created by Grogee on 9/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FeatureView.h"
#import "readFeature.h"

@implementation FeatureView

@synthesize indexset;
@synthesize highlightedPoints;

-(BOOL) acceptsFirstResponder
{
    return YES;
}
-(void) awakeFromNib
{
    minmax = calloc(6,sizeof(float));
    minmax[0] = -1;
    minmax[1] = 1;
    minmax[2] = -1;
    minmax[3] = 1;
    minmax[4] = -1;
    minmax[5] = 1;
    
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAllRenderers,YES,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 16,
    };
    //_pixelFormat =[[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] retain];
    /*_pixelFormat = [[FeatureView defaultPixelFormat] retain];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector:@selector(_surfaceNeedsUpdate:)
                                                 name: NSViewGlobalFrameDidChangeNotification object: self];
    */
     //[self setOpenGLContext: [[NSOpenGLContext alloc] initWithFormat:[NSOpenGLView defaultPixelFormat] shareContext:nil]];
    
}

- (id) initWithFrame:(NSRect)frameRect 
{
    
    /*self = [super initWithFrame:frameRect];
    if(self == nil)
    {
        return nil;
    }
    /*[self setOpenGLContext: [[NSOpenGLContext alloc] initWithFormat:[NSOpenGLView defaultPixelFormat] shareContext:nil]];
    [[self openGLContext] makeCurrentContext];*/
    
    return [self initWithFrame:frameRect pixelFormat: [FeatureView defaultPixelFormat]];
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
        
        //receive notification about change in highlight
        [[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(receiveNotification:) 
                                                     name:@"highlight" object: nil];
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

+(NSOpenGLPixelFormat*) defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAAllRenderers,YES,
        NSOpenGLPFADoubleBuffer, YES,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 32,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    return pixelFormat;
    //return [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
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
        [[self openGLContext] update];
    }
}

- (void) loadVertices: (NSURL*)url
{
    char *path = [[url path] cStringUsingEncoding:NSASCIIStringEncoding];
    header H;
    //H = *readFeatureHeader("../../test2.hdf5", &H);
    H = *readFeatureHeader(path, &H);
    //check if vertices has already been allocated
    vertices = malloc(H.rows*H.cols*sizeof(GLfloat));
    //vertices = readFeatureFile("../../test2.hdf5", vertices);
    vertices = readFeatureFile(path, vertices);
    minmax = realloc(minmax,2*H.cols*sizeof(float));
    int c;
    for(c=0;c<H.cols;c++)
    {
        minmax[2*c] = -1;
        minmax[2*c+1] = 1;
    }
    //minmax = getMinMax(minmax, vertices, H.rows, H.cols);
    draw_dims[0] = 0;
    draw_dims[1] = 1;
    draw_dims[2] = 3;
    rows = H.rows;
    cols = H.cols;
    //cluster indices
    //cids = malloc((rows+1)*sizeof(unsigned int));
    ///cids = readClusterIds("../../a101g0001waveforms.clu.1", cids);
    //use_colors = malloc(cids[0]*3*sizeof(GLfloat));
    //create colors to use; highly simplistic, need to change this, but let's use it for now
    /*
    for(c=0;c<cids[0];c++)
    {
        use_colors[3*c] = ((float)rand())/RAND_MAX;
        use_colors[3*c + 1] = ((float)rand())/RAND_MAX;
        use_colors[3*c + 2] = ((float)rand())/RAND_MAX;
    }
    */
    ndraw_dims = 3;
    nindices = rows;
    NSRange range;
    range.location = 0;
    range.length = rows;
    indexset = [[NSMutableIndexSet indexSetWithIndexesInRange:range] retain];
    use_vertices = malloc(rows*ndraw_dims*sizeof(GLfloat));
    indices = malloc(nindices*sizeof(GLuint));
    colors = malloc(nindices*3*sizeof(GLfloat));
    

    [[self openGLContext] makeCurrentContext];
    modifyVertices(use_vertices);
    modifyIndices(indices);
    modifyColors(colors);
    pushVertices();
    [self setNeedsDisplay:YES];
    //[self selectDimensions];
}

-(void) createVertices: (NSData*)vertex_data withRows: (NSUInteger)r andColumns: (NSUInteger)c
{
    rows = r;
    cols = c;
    nindices = rows;
    if(dataloaded)
    {
        //data has already been loaded, i.e. we are requesting to draw another set of features
        dataloaded = NO;
        free(vertices);
        free(use_vertices);
        free(indices);
        free(colors);
    }
    vertices = malloc(rows*cols*sizeof(GLfloat));
    [vertex_data getBytes:vertices length: rows*cols*sizeof(float)];
    minmax = realloc(minmax,2*cols*sizeof(float));
    int cl;
    for(cl=0;cl<cols;cl++)
    {
        minmax[2*cl] = -1.0;
        minmax[2*cl+1] = 1.0;
    }
    //minmax = getMinMax(minmax, vertices, rows, cols);
    draw_dims[0] = 0;
    draw_dims[1] = 1;
    draw_dims[2] = 3;
    ndraw_dims = 3;
    use_vertices = malloc(rows*ndraw_dims*sizeof(GLfloat));
    indices = malloc(nindices*sizeof(GLuint));
    colors = malloc(nindices*3*sizeof(GLfloat));
    [[self openGLContext] makeCurrentContext];
    glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]+1], 1.1*minmax[2*draw_dims[2]]);
    modifyVertices(use_vertices);
    modifyIndices(indices);
    modifyColors(colors);
    pushVertices();
    [self setNeedsDisplay:YES];
    
}

-(NSData*)getVertexData
{
    NSData *data = [NSData dataWithBytesNoCopy:vertices length:rows*cols*sizeof(float)];
    return data;
}

-(void) selectDimensions:(NSDictionary*)dims
{
    
    int dim = [[dims valueForKey: @"dim"] intValue];
    int f = [[dims valueForKey:@"dim_data"] intValue];

    int dim_data = f;
    if( ((dim >= 0) && (dim < ndraw_dims)) && ((dim_data>=0) && (dim_data<cols)))
    {
        draw_dims[dim] = dim_data;
        //set openGL viewport based on vertices
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
        
        //get the data from the GPU
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        GLfloat *vertex_pointer = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
        modifyVertices(vertex_pointer);
        glUnmapBuffer(GL_ARRAY_BUFFER);
        /*
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
        GLuint *index_pointer = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER,GL_WRITE_ONLY);
        modifyIndices(index_pointer);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);*/
        [self setNeedsDisplay: TRUE];
    }
}

-(void) showCluster: (Cluster *)cluster
{
    int cid = [cluster.name intValue];
    //do this in a very inane way for now, just to see if it works
    int i;
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    GLuint *tmp_indices = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
    if(tmp_indices!=NULL)
    {
        unsigned int *points = (unsigned int*)[[cluster points] bytes];
        int new_size = [[cluster npoints] intValue];
        //new_size = [cluster.indices count];
        //tmp_indices = realloc(tmp_indices, new_size*sizeof(GLuint));
        int j = 0;
        /*for(i=0;i<rows;i++)
        {
            if(cids[i+1]==cid)
            {
                tmp_indices[j] = i;
                j+=1;
            }
        }*/
        for(j=0;j<new_size;j++)
        {
            tmp_indices[nindices+j] = points[j];
        
        }
        [indexset addIndexes: [cluster indices]];
        //this does not work for a 64 bit application, as NSUInteger is then 64 bit, while the tm_indices is 32 bit.
        //int count = [indexset getIndexes:(NSUInteger*)tmp_indices maxCount:nindices+new_size inIndexRange:nil];
        nindices += new_size;
        //glBufferData(GL_ELEMENT_ARRAY_BUFFER, new_size*sizeof(GLuint), tmp_indices, GL_DYNAMIC_DRAW);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
        [self setNeedsDisplay:YES];
    }
}

-(void) hideCluster: (Cluster *)cluster
{
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    GLuint *tmp_indices = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
    if(tmp_indices != NULL)
    {
        unsigned int *points = (unsigned int*)[[cluster points] bytes];
        int new_size = [[cluster npoints] intValue];
        //new_size = [[cluster indices] count];
        if(new_size>0)
        {
            int i,j,k,found;
            i = 0;
            //TODO: The following is a very naiv way of doing intersection. Should fix this 
            //      One way to fix make it more efficient is to make sure the indices are sorted. This can
            //      be done by maintaining a heap, for instance. 
            for(j=0;j<nindices;j++)
            {
                found = 0;
                for(k=0;k<new_size;k++)
                {
                    if(tmp_indices[j]==points[k])
                    {
                        found=1;
                        //once we've found a match, abort
                        break;
                    }
                }
                if(found==0)
                {
                    tmp_indices[i] = tmp_indices[j];
                    i+=1;
                }
            }
            //alternative to the above: Use IndexSets
            //NSMutableIndexSet *tmp = [NSMutableIndexSet 
            int count = [indexset count];
            [indexset removeIndexes: [cluster indices]];
            NSRange range;
            range.location = 0;
            range.length =nindices;
            //count = [indexset getIndexes: tmp_indices maxCount: nindices-new_size inIndexRange: nil];
            nindices-=new_size;
            if(nindices<0)
                nindices=0;
        }
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
        [self setNeedsDisplay:YES];

    }
}

-(void) hideAllClusters
{
    nindices = 0;
    [self setNeedsDisplay:YES];
}

-(void) showAllClusters
{
    nindices = rows;
    [self setNeedsDisplay:YES];
}

-(void) highlightPoints:(NSDictionary*)params
{
    //draw selected points in complementary color
    NSData *points = [params objectForKey: @"points"];
    NSData *color = [params objectForKey:@"color"];
    unsigned int* _points = (unsigned int*)[points bytes];
    unsigned int _npoints = (unsigned int)([points length]/sizeof(unsigned int));
    //get the indices to redraw
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, indexBuffer);
    GLuint *tmp_idx = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
    int i;
    GLuint *idx = malloc(_npoints*sizeof(GLuint));
    for(i=0;i<_npoints;i++)
    {
        idx[i] = tmp_idx[_points[i]];
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    GLfloat *_color = (GLfloat*)[color bytes];
    
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    GLfloat *_colors = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    for(i=0;i<_npoints;i++)
    {
        _colors[idx[i]*3] = 1-_color[0];
        _colors[idx[i]*3+1] = 1-_color[1];
        _colors[idx[i]*3+2] = 1-_color[2];
    }
    if(highlightedPoints != NULL )
    {
        unsigned int* _hpoints = (unsigned int*)[highlightedPoints bytes];
        unsigned int _nhpoints = (unsigned int)([highlightedPoints length]/sizeof(unsigned int));
        //GLfloat *_bcolor = (GLfloat*)[bcolor bytes];
        for(i=0;i<_nhpoints;i++)
        {
            _colors[_hpoints[i]*3] = _color[0];
            _colors[_hpoints[i]*3+1] = _color[1];
            _colors[_hpoints[i]*3+2] = _color[2];
        }
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    if( highlightedPoints == NULL)
    {
        [self setHighlightedPoints: [NSMutableData dataWithBytes: idx length: _npoints*sizeof(GLuint)]];
    }
    else {
        [[self highlightedPoints] setData: [NSMutableData dataWithBytes: idx length: _npoints*sizeof(GLuint)]];
        
    }

    [self setNeedsDisplay:YES];
}

-(void) rotateY
{
    glRotated(5, 0, 1, 0);
    [self setNeedsDisplay:YES];
}

-(void) rotateX
{
    glRotated(5, 1, 0, 0);
    [self setNeedsDisplay:YES];
}

-(void) rotateZ
{
    glRotated(5, 0, 0, 1);
    [self setNeedsDisplay:YES];
}

-(void) setClusterColors: (GLfloat*)cluster_colors forIndices: (GLuint*)cluster_indices length:(NSUInteger)length
{
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    GLfloat *tmp_colors = glMapBuffer(GL_ARRAY_BUFFER,GL_WRITE_ONLY);
    int i;
    if( cluster_indices != NULL)
        for(i=0;i<length;i++)
        {
            tmp_colors[3*cluster_indices[i]] = cluster_colors[0];//[3*i];
            tmp_colors[3*cluster_indices[i]+1] = cluster_colors[1];//[3*i+1];
            tmp_colors[3*cluster_indices[i]+2] = cluster_colors[2];//[3*i+2];
        }
    else 
    {
        //if cluster_indices is NULL, assume we are changing everthing
        for(i=0;i<rows;i++)
        {
            tmp_colors[3*i] = cluster_colors[3*i];
            tmp_colors[3*i+1] = cluster_colors[3*i+1];
            tmp_colors[3*i+2] = cluster_colors[3*i+2];
        }
    }

    //make sure we give the buffer back
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [self setNeedsDisplay:YES];
}
 

static void modifyVertices(GLfloat *vertex_data)
{
    //create vertices for drawing
    int i,j;
    
    //int ndraw_dims = 3;
    //nindices = rows;
    
    
    for(i=0;i<rows;i++)
    {
        //indices[i] = i;
        for(j=0;j<ndraw_dims;j++)
        {
            //indices[i*ndraw_dims+j] = i*ndraw_dims +j;
            vertex_data[i*ndraw_dims+j] = vertices[i*cols+draw_dims[j]];
        }
    }
    
    
}

static void modifyIndices(GLuint *index_data)
{
    int i;
    
    for(i=0;i<rows;i++)
    {
        index_data[i] = i;
    }
    
}

static void modifyColors(GLfloat *color_data)
{
    int i;
    for(i=0;i<rows;i++)
    {
        color_data[3*i] = 1.0f;//use_colors[3*cids[i+1]];
        color_data[3*i+1] = 0.85f;//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = 0.35f;//use_colors[3*cids[i+1]+2];
    }
}

static void pushVertices()
{
    //set up index buffer
    int k = 0;
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);

    glGenBuffers(1,&indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nindices*sizeof(GLuint),indices, GL_DYNAMIC_DRAW);
    //generate 1 buffer of type vertexBuffer
    
    glGenBuffers(1,&colorBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat),colors,GL_DYNAMIC_DRAW);
    
    //bind vertexBuffer
    glGenBuffers(1,&vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat), use_vertices, GL_DYNAMIC_DRAW);
    
    
    dataloaded = YES;
    
    
}
static void drawFrame()
{
    glColor3f(1.0f,0.85f,0.35f);
    glBegin(GL_TRIANGLES);
    glVertex3f(vertices[0], vertices[1],vertices[2]);
    glVertex3f(vertices[4],vertices[5],vertices[6]);
    glVertex3f(vertices[8],vertices[9],vertices[10]);
    glEnd();
    
}

static void drawAnObject()
{
    //glColor3f(1.0f,0.85f,0.35f);
    //activate the dynamicbuffer
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glEnableClientState(GL_VERTEX_ARRAY);
    //bind the vertexbuffer
    
    //glVertexPointer(2, GL_FLOAT, sizeof(vertexStatic), (void*)offsetof(vertexStatic,position));
    //set the vertex pointer
    //offsetof
    //activate vertex point; 3 points per vertex, each point of type GL_FLOAT, stride of 0 (i.e. tightly pakced), and use existing
    //vetex data, i.e. vertexBuffer activated above.
    glVertexPointer(3, GL_FLOAT, 0, (void*)0);
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glEnableClientState(GL_COLOR_ARRAY);
    glColorPointer(3, GL_FLOAT, 0, (void*)0);
    //bind the indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    //draw eveything for now
    //glDrawArrays(GL_POINT, 0, nvertices/3);
    //draw using the indices
    //Draw nindices elements of type GL_POINTS, use the loaded indexBuffer
    glDrawElements(GL_POINTS, nindices, GL_UNSIGNED_INT,(void*)0);
    //glDrawRangeElement
}

-(void) drawRect :(NSRect) bounds
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
    //if(bounds != [self bounds] )
    //{
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //glDepthRange(minmax[4],minmax[5]);
    //}
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
    glClear(GL_DEPTH_BUFFER_BIT);
    if(dataloaded)
    {
        drawAnObject();
        //drawFrame();
    }
    glFlush();
    [[self openGLContext] flushBuffer];

}
- (void) prepareOpenGL
{
    //prepare openGL context
    dataloaded = NO;
    //_oglContext = [[NSOpenGLContext alloc] initWithFormat: [self pixelFormat] shareContext:nil];
    float *rot = calloc(3, sizeof(float));
    rotation = [NSMutableData dataWithBytes:rot length:3];
    free(rot);
    NSOpenGLContext *context = [self openGLContext];
    NSRect bounds = [self bounds];
    
    [context makeCurrentContext];
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
    [context flushBuffer];
    //[self update];
    
    
       
}
- (void) reshape
{
    //reshape the view
    NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //glMatrixMode(GL_PROJECTION);
    //glLoadIdentity();
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
    [self setNeedsDisplay:YES];    
}

-(void) receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"highlight"])
    {
        [self highlightPoints:[notification object]];
    }
}



- (void)keyDown:(NSEvent *)theEvent
{
    //capture key event, rotate view : left/right -> y-axis, up/down -> x-axis
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    } else {
        [self keyDown:theEvent];
    }
}

-(IBAction)moveUp:(id)sender
{
    /*//rotate about z-axis
    float rot;
    NSRange range;
    range.location = 2*sizeof(float);
    range.length = sizeof(float);
    [rotation getBytes: &rot range:range];
    rot-=5.0;
    [rotation replaceBytesInRange:range withBytes:&rot];*/
    glRotated(-5, 0, 0, 1);
    [self setNeedsDisplay:YES];
}

-(IBAction)moveDown:(id)sender
{
    /*float rot;
    NSRange range;
    range.location = 2*sizeof(float);
    range.length = sizeof(float);
    [rotation getBytes: &rot range:range];
    rot+=5.0;
    [rotation replaceBytesInRange:range withBytes:&rot];*/
    //rotate about z-axis
    glRotated(5, 0, 0, 1);
    [self setNeedsDisplay:YES];
}

-(IBAction)moveLeft:(id)sender
{
    /*
    float rot;
    NSRange range;
    range.location = sizeof(float);
    range.length = sizeof(float);
    [rotation getBytes: &rot range:range];
    rot+=5.0;
    [rotation replaceBytesInRange:range withBytes:&rot];
    //rotate about y-axis*/
    glRotated(5, 0, 1, 0);
    [self setNeedsDisplay:YES];
}

-(IBAction)moveRight:(id)sender
{
    /*float rot;
    NSRange range;
    range.location = sizeof(float);
    range.length = sizeof(float);
    [rotation getBytes: &rot range:range];
    rot-=5.0;
    [rotation replaceBytesInRange:range withBytes:&rot];*/
    //rotate about y-axis
    glRotated(-5, 0, 1, 0);
    [self setNeedsDisplay:YES];

}

-(void)mouseUp:(NSEvent *)theEvent
{
    if([theEvent modifierFlags] == NSCommandKeyMask)
    {
        //only select points if Command key is pressed
        //get current point in view coordinates
        NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
        //now we will have to figure out which waveform(s) contains this point
        //scale to data coorindates
        NSPoint dataPoint;
        NSRect viewBounds = [self bounds];
        //scale to data coordinates
        //take into account rotation
        //compute appropriate 2-D projection; initial projection is the x-y plane
       
        GLint view[4];
        GLdouble p[16];
        GLdouble m[16];
        GLdouble z;
        [[self openGLContext] makeCurrentContext];
        glGetDoublev (GL_MODELVIEW_MATRIX, m);
        glGetDoublev (GL_PROJECTION_MATRIX,p);
        glGetIntegerv( GL_VIEWPORT, view );
        double objX,objY,objZ;
        gluUnProject(currentPoint.x, currentPoint.y, 1, m, p, view, &objX, &objY, &objZ);
        
        
        //(dataPoint.x,dataPoint.y) and the waveforms vectors
        float *D = malloc(2*nindices*sizeof(float));
        float *d = malloc(nindices*sizeof(float));
        float *po = malloc(3*sizeof(float));
        vDSP_Length imin;
        float fmin;
        po[0] = -(float)objX;
        po[1] = -(float)objY;
        po[2] = -(float)objZ;
        //substract the point
        vDSP_vsadd(use_vertices,3,po,D,2,nindices);
        vDSP_vsadd(use_vertices+1,3,po+1,D+1,2,nindices);
        //vDSP_vsadd(vertices+2,3,po+2,D+1,2,nvertices);
        //sum of squares
        vDSP_vdist(D,2,D+1,2,d,1,nindices);
        //find the index of the minimu distance
        vDSP_minvi(d,1,&fmin,&imin,nindices);
        //imin now holds the index of the vertex closest to the point
        //find the number of wfVertices per waveform
        free(po);
        free(d);
        free(D);
        //3 points per waveform
        unsigned int wfidx = imin/(3);
        
        //get the current drawing color
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        float *color = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
        
        NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSData dataWithBytes: &wfidx 
                                                                                                            length: sizeof(unsigned int)],
                                                                    [NSData dataWithBytes: color+imin length:3*sizeof(float)],nil] forKeys: [NSArray arrayWithObjects: @"points",@"color",nil]];
        glUnmapBuffer(GL_ARRAY_BUFFER);
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:params];
        [self highlightPoints:params];
    }
}

-(void)dealloc
{
    free(vertices);
    free(use_vertices);
    free(indices);
    free(minmax);
    free(colors);
    //free(cids);
    free(use_colors);
    free(indexset);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [super dealloc];
}

@end
