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
	rotatex = 0.0;
	rotatey = 0.0;
	rotatez = 0.0;
	originx = 0.0;
	originy = 0.0;
	originz = -2.0;
	scale = 1.0;
    
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
	}
    return self;
}

-(void) _surfaceNeedsUpdate:(NSNotification*)notification
{
	[self reshape];
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
        minmax[2*cl] = -1.5;
        minmax[2*cl+1] = 1.5;
    }
	scale = 1.0;
    //minmax = getMinMax(minmax, vertices, rows, cols);
    draw_dims[0] = 0;
    draw_dims[1] = 1;
    draw_dims[2] = 3;
    ndraw_dims = 3;
    use_vertices = malloc(rows*ndraw_dims*sizeof(GLfloat));
    indices = malloc(nindices*sizeof(GLuint));
    colors = malloc(nindices*3*sizeof(GLfloat));
    [[self openGLContext] makeCurrentContext];
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]+1], 1.1*minmax[2*draw_dims[2]]);
	//glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);

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
		//make sure we are in the current context
        [[self openGLContext] makeCurrentContext];
		//glMatrixMode(GL_PROJECTION);
        //glLoadIdentity();
        //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
        
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
	[[self openGLContext] makeCurrentContext];
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
		//float *centroid = NSZoneMalloc([self zone], 3*sizeof(float));
		float *cluster_minmax = NSZoneCalloc([self zone], 6,sizeof(float));
		
        for(j=0;j<new_size;j++)
        {
            tmp_indices[nindices+j] = points[j];
			//compute centroid
			//centroid[0] += vertices[points[j]*cols + draw_dims[0]];
			//centroid[1] += vertices[points[j]*cols + draw_dims[1]];
			//centroid[2] += vertices[points[j]*cols + draw_dims[2]];
			//compute min/max
			cluster_minmax[0] = MIN(cluster_minmax[0],vertices[points[j]*cols + draw_dims[0]]);
			cluster_minmax[1] = MAX(cluster_minmax[1],vertices[points[j]*cols + draw_dims[0]]);
			
			cluster_minmax[2] = MIN(cluster_minmax[2],vertices[points[j]*cols + draw_dims[1]]);
			cluster_minmax[3] = MAX(cluster_minmax[3],vertices[points[j]*cols + draw_dims[1]]);
			
			cluster_minmax[4] = MIN(cluster_minmax[4],vertices[points[j]*cols + draw_dims[2]]);
			cluster_minmax[5] = MAX(cluster_minmax[5],vertices[points[j]*cols + draw_dims[2]]);
			

        }
		scale = 1.0;
		for(j=0;j<3;j++)
		{
			scale = MAX(scale,1.0/(cluster_minmax[2*j+1]-cluster_minmax[2*j]));		
		}
		scale = 1.0/scale;
						
		
        //this does not work for a 64 bit application, as NSUInteger is then 64 bit, while the tm_indices is 32 bit.
        //int count = [indexset getIndexes:(NSUInteger*)tmp_indices maxCount:nindices+new_size inIndexRange:nil];
        //glBufferData(GL_ELEMENT_ARRAY_BUFFER, new_size*sizeof(GLuint), tmp_indices, GL_DYNAMIC_DRAW);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
		nindices += new_size;

		//normalize
		//centroid[0]/=new_size;
		//centroid[1]/=new_size;
		//centroid[2]/=new_size;
		//originx = -centroid[0];
		//originy = -centroid[1];
		//originz = -centroid[1];
        //NSZoneFree([self zone], centroid);
		[indexset addIndexes: [cluster indices]];
		//TODO: Change the viewport to scale to the new set of points
		//calculate the centroid of the cluster in the current space
		[self changeZoom];
        //[self setNeedsDisplay:YES];
    }
}

-(void) hideCluster: (Cluster *)cluster
{
	[[self openGLContext] makeCurrentContext];
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
		//reset origin
		originx = 0.0;
		originy = 0.0;
		originz = -2.0;        
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
    //reset the colors before doing the new colors
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
    
    for(i=0;i<_npoints;i++)
    {
        _colors[idx[i]*3] = 1-_color[0];
        _colors[idx[i]*3+1] = 1-_color[1];
        _colors[idx[i]*3+2] = 1-_color[2];
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
    //glRotated(5, 0, 1, 0);
    [self setNeedsDisplay:YES];
}

-(void) rotateX
{
    //glRotated(5, 1, 0, 0);
    [self setNeedsDisplay:YES];
}

-(void) rotateZ
{
    //glRotated(5, 0, 0, 1);
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
    
    //glMatrixMode(GL_PROJECTION);
    //glLoadIdentity();
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);

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
	//finally connect the corners
	glColor4f(0.5f,0.85f,0.35f,1.0f);
	glLineWidth(1.0);
	int i;
	float d = 0;
	for(i=0;i<=10;i++)
	{
		d = 0.2*i;
		glBegin(GL_LINES);
		//y
		glVertex3f(-.99+d, -.99, -.99);
		glVertex3f(-.99+d, 1.01, -.99);
		
		glVertex3f(-.99, -.99, -.99+d);
		glVertex3f(-.99, 1.01, -.99+d);

		//z
		glVertex3f(-.99+d, -.99, -0.99);
		glVertex3f(-.99+d, -.99, 1.01);
		
		glVertex3f(-.99, -.99+d, -0.99);
		glVertex3f(-.99, -.99+d, 1.01);
		
		//x
		glVertex3f(-.99, -0.99, -.99+d);
		glVertex3f(1.01, -.99, -.99+d);
				   
	    glVertex3f(-.99, -.99+d, -0.99);
	    glVertex3f(1.01, -.99+d, -.99);
		
		/*glVertex3f(1.0, 1.0, 1.0);
		 glVertex3f(1.0, 1.0, -1.0);*/
		
		glEnd();
	}
	
	
    //glColor4f(0.5f,0.85f,0.35f,0.1f);
    
	//front size
	//glBegin(GL_LINE_LOOP);
    /*glBegin(GL_QUADS);
	glVertex3f(-1.0, -1.0, 1.0);
	glVertex3f(1.0,-1.0,1.0);
	glVertex3f(1.0,1.0,1.0);
	glVertex3f(-1.0,1.0,1.0);
	glEnd();*/
	//back side
	/*
	glBegin(GL_QUADS);
	glVertex3f(-1.0, -1.0, -1.0);
	glVertex3f(1.0,-1.0,-1.0);
	glVertex3f(1.0,1.0,-1.0);
	glVertex3f(-1.0,1.0,-1.0);
	
    glEnd();
	
	//floor
	glBegin(GL_QUADS);
	glVertex3f(-1.0, -1.0, -1.0);
	glVertex3f(1.0,-1.0,-1.0);
	glVertex3f(1.0,-1.0,1.0);
	glVertex3f(-1.0,-1.0,1.0);
	glEnd();
	
	//side
	glBegin(GL_QUADS);
	glVertex3f(-1.0, -1.0, -1.0);
	glVertex3f(-1.0, 1.0, -1.0);
	glVertex3f(-1.0, 1.0, 1.0);
	glVertex3f(-1.0, -1.0, 1.0);

	
	glEnd();*/
	    
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
    //glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //glDepthRange(minmax[4],minmax[5]);
    //}
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
	
    glClear(GL_DEPTH_BUFFER_BIT);
	if(dataloaded)
    {
		//glMatrixMode(GL_PROJECTION);

		//glLoadIdentity();
		//glRotatef(rotatey,0, 1, 0);
		//glRotatef(rotatez, 0, 0,1);
		//glOrtho(scale*1.1*minmax[2*draw_dims[0]], scale*1.1*minmax[2*draw_dims[0]+1], scale*1.1*minmax[2*draw_dims[1]], 
		//		scale*1.1*minmax[2*draw_dims[1]+1], scale*1.1*minmax[2*draw_dims[2]], scale*1.1*minmax[2*draw_dims[2]+1]);
		
		//TODO: Don't do this; use gluLookAt
		//gluLookAt(100, 100, 100, 0, 0, 0, 0, 1, 0);
		//glScalef(scale, scale,scale);
		//glMatrixMode(GL_PROJECTION);
		//glLoadIdentity();
		//glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 
		//		1.1*minmax[2*draw_dims[1]+1], minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
		//glFrustum(1.5*minmax[2*draw_dims[0]], 1.5*minmax[2*draw_dims[0]+1], 1.5*minmax[2*draw_dims[1]], 
		//		   1.5*minmax[2*draw_dims[1]+1], 1.5*minmax[2*draw_dims[2]], 1.5*minmax[2*draw_dims[2]+1]);
		//glFrustum(-2, 2, -2,2, 2, 6);
        glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glTranslatef(originx, originy, originz);

		/*
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		//glRotatef(rotatey,0, 1, 0);
		//glRotatef(rotatez, 0, 0,1);
		glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 
				1.1*minmax[2*draw_dims[1]+1], minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();*/
		//glMatrixMode(GL_MODELVIEW);
		//glLoadIdentity();
		//glTranslatef(originx/2, originy/2, originz/2);
		//glTranslatef(0, 0, -2.0);
		//glTranslatef(originx, originy, originz);


		glRotatef(rotatey,0, 1, 0);
		glRotatef(rotatez, 0, 0,1);

		//glScalef(scale, scale, scale);

		drawAnObject();

		drawFrame();
		
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
    

    glClearColor(0,0, 0, 0);
    glClearDepth(1.0);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    glShadeModel(GL_SMOOTH);
    glPointSize(4.0);
    glEnable(GL_BLEND);
    glEnable(GL_POINT_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_DST_ALPHA);
	glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 2, 6);
	gluLookAt(0, 0, 2.0, 0, 0, 0.0, 0, 1, 0);

    [context flushBuffer];
    //[self update];
    
    
       
}
- (void) reshape
{
    //reshape the view
    NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
	glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);

	glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 2, 6);
	gluLookAt(0, 0, 2.0, 0, 0, 0.0, 0, 1, 0);

    //glMatrixMode(GL_PROJECTION);
    //glLoadIdentity();
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
    [self setNeedsDisplay:YES];    
}

-(void)zoomIn
{
	scale = scale*0.9;
	[self changeZoom];
}

-(void)zoomOut
{
	scale = scale*1.1;
	[self changeZoom];
}

-(void)resetZoom
{
	scale = 1.0;
	[self changeZoom];

}

-(void) changeZoom
{
	//to be called after zoom factor has changed
	glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 2, 6);
	gluLookAt(0, 0, 2.0, 0, 0, 0.0, 0, 1, 0);
	
	[self setNeedsDisplay:YES];
	
}
-(void) receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"highlight"])
    {
        [self highlightPoints:[notification userInfo]];
    }
}



- (void)keyDown:(NSEvent *)theEvent
{
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    //capture key event, rotate view : left/right -> y-axis, up/down -> x-axis
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
	}
	else if ([formatter numberFromString: [theEvent characters]] != nil )	
	{
		
		//send off a notification indicating that we should show the waveform picker panel
		NSDictionary *params  = [NSDictionary dictionaryWithObjectsAndKeys:[theEvent characters],@"selected",nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: params];
	
    } 
	else 
	{
        if( [[theEvent characters] isEqualToString:@"+" ] )
		{
			[self zoomIn];
		}
		else if ([[ theEvent characters] isEqualToString:@"-"] )
		{
			[self zoomOut];
		}
    }
	[formatter release];
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
	//glMatrixMode(GL_MODELVIEW);
    //glRotated(-5, 0, 0, 1);
	rotatez+=-5;
    //[self setNeedsDisplay:YES];
	[self display];
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
	//only rotate if the current context belongs to me
	//if([[NSOpenGLContext currentContext] isEqualTo:[self openGLContext]])
	//{
	//glRotated(5, 0, 0, 1);
	rotatez+=5;
	//[self setNeedsDisplay:YES];
	[self display];
	//}
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
    //glRotated(5, 0, 1, 0);
	rotatey+=5;
    //[self setNeedsDisplay:YES];
	[self display];
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
    //glRotated(-5, 0, 1, 0);
	rotatey-=5;
    //[self setNeedsDisplay:YES];
	[self display];

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

-(void)scrollWheel:(NSEvent *)theEvent
{
	if( [theEvent deltaX] > 1 )
	{
		[self moveLeft:self];
	}
	else if( [theEvent deltaX] < -1 )
	{
		[self moveRight:self];
	}
	if( [theEvent deltaY] > 1 )
	{
		[self moveUp:self];
	}
	else if ([theEvent deltaY] < -1 )
	{
		[self moveDown:self];
	}
}

-(void)magnifyWithEvent:(NSEvent *)event
{
	if( [event type] == NSEventTypeMagnify )
	{
		/*scale = scale+0.01*[event magnification];
		[[self openGLContext] makeCurrentContext];
		glMatrixMode(GL_MODELVIEW);
		//glLoadIdentity();
		glScaled(scale, scale, scale);
		[self setNeedsDisplay: YES];*/
	}
}

-(void)mouseDragged:(NSEvent *)theEvent
{
	//shift the origin by some amount
	BOOL needDisplay = NO;
	if( [theEvent deltaX] < -1 )
	{
		originx-=0.1;
		needDisplay = YES;
	}
	else if( [theEvent deltaX] > 1 )
	{
		originx+=0.1;
		needDisplay = YES;

	}
	if( [theEvent deltaY] < -1 )
	{
		originy+=0.1;
		needDisplay = YES;

	}
	else if( [theEvent deltaY] > 1 )
	{
		originy-=0.1;
		needDisplay = YES;

	}
	[self setNeedsDisplay:needDisplay];
			  
}

-(void)rightMouseDragged:(NSEvent *)theEvent
{
	BOOL needDisplay = NO;
	if( [theEvent deltaY] < -1 )
	{
		originz-=0.1;
		needDisplay = YES;
	}
	else if( [theEvent deltaY] > 1 )
	{
		originz+=0.1;
		needDisplay = YES;
		
	}
	[self setNeedsDisplay:needDisplay];
	
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
