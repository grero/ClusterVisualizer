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
@synthesize highlightedPoints,highlightedClusterPoints;
@synthesize showFrame;

-(BOOL) acceptsFirstResponder
{
    return YES;
}
-(void) awakeFromNib
{
    minmax = calloc(6,sizeof(float));
	selectionRec = NSMakeRect(0,0,0,0);
	drawRect = NO;
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
    base_color[0] = 1.0f;
	base_color[1] = 0.85f;
	base_color[2] = 0.35f;
    drawAxesLabels = NO;
    appendHighlights = NO;
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
    
    //register for defaults updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:NSUserDefaultsDidChangeNotification object:nil];

	picked = NO;
    selectedClusters = [[NSMutableArray  arrayWithCapacity:10] retain];
    
}

- (id) initWithFrame:(NSRect)frameRect 
{
    
    /*self = [super initWithFrame:frameRect];
    if(self == nil)
    {
        return nil;
    }
    [self setOpenGLContext: [[NSOpenGLContext alloc] initWithFormat:[NSOpenGLView defaultPixelFormat] shareContext:nil]];
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
        vertexBuffer = 0;
        indexBuffer = 0;
        colorBuffer = 0;
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
        [[self openGLContext] update];
    }
}

- (void) loadVertices: (NSURL*)url
{
    float *use_vertices,*colors,*_vertices;
    int i,j;
    GLuint *indices;
    const char *path = [[url path] cStringUsingEncoding:NSASCIIStringEncoding];
    header H;
    //H = *readFeatureHeader("../../test2.hdf5", &H);
    H = *readFeatureHeader(path, &H);
    //check if vertices has already been allocated
    _vertices = malloc(H.rows*H.cols*sizeof(GLfloat));
    //vertices = readFeatureFile("../../test2.hdf5", vertices);
    _vertices = readFeatureFile(path, _vertices);
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
    draw_dims[2] = 2;
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
    //push the data to the GPU
    if(vertexBuffer==0)
    {
        glGenBuffers(1,&vertexBuffer);
    }
    //bind vertexBuffer
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat), use_vertices, GL_DYNAMIC_DRAW);
    //push the indices
    free(use_vertices);
    
    indices = malloc(nindices*sizeof(GLuint));
    for(i=0;i<nindices;i++)
    {
        indices[i] = i;
    }
    if(indexBuffer ==0)
    {
        glGenBuffers(1, &indexBuffer);
    }
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nindices*sizeof(GLuint), indices, GL_DYNAMIC_DRAW);
    
    //push the colors to the GPU
    colors = malloc(nindices*3*sizeof(GLfloat));
    for(i=0;i<nindices;i++)
    {
        colors[3*i] = 0.85f;
        colors[3*i+1] = 0.56f;
        colors[3*i+2] = 0.36f;
    }
    if(colorBuffer == 0)
    {
        glGenBuffers(1,&colorBuffer);
    }
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat), colors, GL_DYNAMIC_DRAW);
    free(colors);
	//modifyVertices(use_vertices);
    //modifyIndices(indices);
    //modifyColors(colors);
    //pushVertices();
    //notify that data has been loaded
    dataloaded = YES;

    /*modifyVertices(use_vertices);
    modifyIndices(indices);
    modifyColors(colors);
    pushVertices();*/
    [self setNeedsDisplay:YES];
    //[self selectDimensions];
}

-(void) createVertices: (NSData*)vertex_data withRows: (NSUInteger)r andColumns: (NSUInteger)c
{
    float *use_vertices, *colors,*indices;
    rows = r;
    cols = c;
	//allocate space for cluster centroid
	CM = calloc(cols,sizeof(float));
    nindices = rows;
	//create an indexset
	NSRange rng;
	rng.location = 0;
	rng.length = rows;
	indexset = [[NSMutableIndexSet indexSetWithIndexesInRange:rng] retain];
    if(dataloaded)
    {
        //data has already been loaded, i.e. we are requesting to draw another set of features
        dataloaded = NO;
        //free(use_vertices);
        //free(indices);
        //free(colors);
    }
    //float *_vertices = malloc(rows*cols*sizeof(GLfloat));
    //check if vertices already exists
    if(vertices != NULL )
    {
        [vertices release];

    }
    //vertices = [[NSData dataWithData:vertex_data] retain];
	//make a copy of vertex data and retain it
	vertices = [[vertex_data copy] retain];
    
    //[vertex_data getBytes:vertices length: rows*cols*sizeof(float)];
    float *_vertices = (float*)[vertices bytes];
    minmax = realloc(minmax,2*cols*sizeof(float));
    int cl;
    //this only works if we have rescaled the axis
    for(cl=0;cl<cols;cl++)
    {
        minmax[2*cl] = -1.5;
        minmax[2*cl+1] = 1.5;
    }
	scale = 1.0;
    draw_dims[0] = 0;
    draw_dims[1] = 1;
    draw_dims[2] = 2;
    ndraw_dims = 3;
    //I don't really need a separate variable for this; just use whatever is on the GPU
    use_vertices = malloc(rows*ndraw_dims*sizeof(GLfloat));
    int i,l,nbatches,batchsize,rem;
    dispatch_queue_t queue;
    batchsize = 1000;
    nbatches = rows/batchsize;
    rem = rows - nbatches*batchsize;
    //for(i=0;i<rows;i++)
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(nbatches, queue, ^(size_t i) 
    {
        //indices[i] = i;
        int j,k;
        for(k=i*batchsize;k<(i+1)*batchsize;k++)
        {
            for(j=0;j<ndraw_dims;j++)
            {
                //indices[i*ndraw_dims+j] = i*ndraw_dims +j;
                use_vertices[k*ndraw_dims+j] = _vertices[k*cols+draw_dims[j]];
            }
        }
    });
    //do the remainder
    for(i=nbatches*batchsize;i<rows;i++)
    {
        for(l=0;l<ndraw_dims;l++)
        {
            //indices[i*ndraw_dims+j] = i*ndraw_dims +j;
            use_vertices[i*ndraw_dims+l] = _vertices[i*cols+draw_dims[l]];
        }
    }
               
    [[self openGLContext] makeCurrentContext];
    //push the data to the GPU
    if(vertexBuffer==0)
    {
        glGenBuffers(1,&vertexBuffer);
    }
    //bind vertexBuffer
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat), use_vertices, GL_DYNAMIC_DRAW);
    //push the indices
    free(use_vertices);
    
    indices = malloc(nindices*sizeof(GLuint));
    for(i=0;i<nindices;i++)
    {
        indices[i] = i;
    }
    if(indexBuffer ==0)
    {
        glGenBuffers(1, &indexBuffer);
    }
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nindices*sizeof(GLuint), indices, GL_DYNAMIC_DRAW);
    
    //push the colors to the GPU
    colors = malloc(nindices*3*sizeof(GLfloat));
    for(i=0;i<nindices;i++)
    {
        colors[3*i] = 0.85f;
        colors[3*i+1] = 0.56f;
        colors[3*i+2] = 0.36f;
    }
    if(colorBuffer == 0)
    {
        glGenBuffers(1,&colorBuffer);
    }
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glBufferData(GL_ARRAY_BUFFER, nindices*3*sizeof(GLfloat), colors, GL_DYNAMIC_DRAW);
    free(colors);
	//modifyVertices(use_vertices);
    //modifyIndices(indices);
    //modifyColors(colors);
    //pushVertices();
    //notify that data has been loaded
    dataloaded = YES;
    [self setNeedsDisplay:YES];
    
}

-(NSData*)getVertexData
{
    return vertices;
}

-(NSData*)getVertexDataForDims:(NSData*)dims
{
	//return vertices corresponding to the specified dimensions
	float *_vdata,*_vertices;
	unsigned int i,j,ndims,*_dims ;
	_dims = (unsigned int*)[dims bytes];
	ndims = [dims length]/sizeof(unsigned int);
	//check that none of the dimensions are too large
	for(i=0;i<ndims;i++)
	{
		if( (_dims[i] >= cols ) || (_dims[i] < 0) )
		{
			return NULL;
		}
	}
	_vertices = (float*)[vertices bytes];
	_vdata = malloc(rows*ndims*sizeof(float));
	for(i=0;i<rows;i++)
	{
		for(j=0;j<ndims;j++)
		{
			_vdata[i*ndims+j] = _vertices[i*cols+_dims[j]];
		}
	}
	NSData *vdata = [NSData dataWithBytes: _vdata length: rows*ndims*sizeof(float)];
	free(_vdata);
	return vdata;
}

-(void) selectDimensions:(NSDictionary*)dims
{
    float *_vertices;
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
        _vertices = (float*)[vertices bytes];
        //get the data from the GPU
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        GLfloat *vertex_pointer = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
        int i,j;
        for(i=0;i<rows;i++)
        {
            //indices[i] = i;
            for(j=0;j<ndraw_dims;j++)
            {
                //indices[i*ndraw_dims+j] = i*ndraw_dims +j;
                vertex_pointer[i*ndraw_dims+j] = _vertices[i*cols+draw_dims[j]];
            }
        }

		//compute min/max
		/*float max,min,l;
		//find max
		vDSP_maxv(vertex_pointer,1,&max,rows*3);
		//find min
		vDSP_minv(vertex_pointer,1,&min,rows*3);
		l = max-min;
		int j;
		for(j=0;j<rows*3;j++)
		{
			vertex_pointer[j] = 2*(vertex_pointer[j]-min)/l-1;
		}*/
		//
        glUnmapBuffer(GL_ARRAY_BUFFER);
        /*
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
        GLuint *index_pointer = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER,GL_WRITE_ONLY);
        modifyIndices(index_pointer);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);*/
        [self setNeedsDisplay: TRUE];
    }
}

-(void) showIndices: (NSIndexSet*)indices
{   
	unsigned int _nindices,i;
	//get the intersection of the requested indices with the currently shown indices
    NSIndexSet *cIndices = [currentCluster indices];
	NSIndexSet *sIndices = [cIndices indexesPassingTest: ^(NSUInteger idx, BOOL *stop){
								return [indices containsIndex: idx];
	}]; 
	_nindices = [sIndices count];
	NSUInteger *_index = malloc([sIndices count]*sizeof(NSUInteger));
	[sIndices getIndexes: _index maxCount: _nindices inIndexRange: nil];

	[[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    GLuint *tmp_indices = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
	if(tmp_indices != NULL)
	{
		//copy to tmp_indices
		//memcpy(tmp_indices, _index,_nindices*sizeof(unsigned int));
		for(i=0;i<_nindices;i++)
        {
            tmp_indices[i] = (GLuint)_index[i];
        }
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
		nindices = _nindices;
		[self setNeedsDisplay: YES];
	}
    //update the index
    [indexset removeAllIndexes];
    [indexset addIndexes:sIndices];
    nindices = [indexset count];
    

}

-(void) showCluster: (Cluster *)cluster
{
    float *_vertices = (float*)[vertices bytes];
    currentCluster = cluster;
    float *_color = (float*)[[cluster color] bytes];
    if([selectedClusters containsObject:cluster] == NO)
    {
        [selectedClusters addObject: cluster];
    }
	unsigned int new_size = [[cluster npoints] intValue];
    /*
    if( nindices + new_size > rows )
    {
        return;
    }
     */
	[[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    GLuint *tmp_indices = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_WRITE_ONLY);
	//
    GLuint error = glGetError();
	const GLubyte *errstr = gluErrorString(error);
	//
    if(tmp_indices!=NULL)
    {
                //new_size = [cluster.indices count];
        //tmp_indices = realloc(tmp_indices, new_size*sizeof(GLuint));
        int j = 0;
        [indexset addIndexes: [cluster indices]];
        nindices = [indexset count];
        NSUInteger *_indices = malloc(nindices*sizeof(NSUInteger));
        [indexset getIndexes:_indices maxCount:nindices inIndexRange:nil];
        for(j=0;j<nindices;j++)
        {
            tmp_indices[j] = (unsigned int)_indices[j];
        }
        free(_indices);
        glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
        /*for(i=0;i<rows;i++)
        {
            if(cids[i+1]==cid)
            {
                tmp_indices[j] = i;
                j+=1;
            }
        }*/
        unsigned int *points = (unsigned int*)[[cluster points] bytes];
		float *cluster_minmax = NSZoneCalloc([self zone], 6,sizeof(float));
        //originx = 0;
        //originy = 0;
        
        for(j=0;j<new_size;j++)
        {
            //tmp_indices[nindices+j] = points[j];
			//compute centroid; this is only valid int he original coordinate system
			//centroid[0] += _vertices[points[j]*cols + draw_dims[0]];
			//centroid[1] += _vertices[points[j]*cols + draw_dims[1]];
			//centroid[2] += _vertices[points[j]*cols + draw_dims[2]];
			//compute min/max
			cluster_minmax[0] = MIN(cluster_minmax[0],_vertices[points[j]*cols + draw_dims[0]]);
			cluster_minmax[1] = MAX(cluster_minmax[1],_vertices[points[j]*cols + draw_dims[0]]);
			
			cluster_minmax[2] = MIN(cluster_minmax[2],_vertices[points[j]*cols + draw_dims[1]]);
			cluster_minmax[3] = MAX(cluster_minmax[3],_vertices[points[j]*cols + draw_dims[1]]);
			
			cluster_minmax[4] = MIN(cluster_minmax[4],_vertices[points[j]*cols + draw_dims[2]]);
			cluster_minmax[5] = MAX(cluster_minmax[5],_vertices[points[j]*cols + draw_dims[2]]);
			

        }
        
        //colors
                /*
		scale = 1.0;
		for(j=0;j<3;j++)
		{
			scale = MAX(scale,1.0/(cluster_minmax[2*j+1]-cluster_minmax[2*j]));		
		}
		scale = 1.0/scale;
		*/				
		
        //this does not work for a 64 bit application, as NSUInteger is then 64 bit, while the tm_indices is 32 bit.
        //int count = [indexset getIndexes:(NSUInteger*)tmp_indices maxCount:nindices+new_size inIndexRange:nil];
        //glBufferData(GL_ELEMENT_ARRAY_BUFFER, new_size*sizeof(GLuint), tmp_indices, GL_DYNAMIC_DRAW);
		
		//nindices += new_size;

		//normalize
		//centroid[0]/=new_size;
		//centroid[1]/=new_size;
		//centroid[2]/=new_size;
      	//only do this of nidinces > 0  
		if(nindices > 0)
		{
			int i;
			float *clusterMean = (float*)[[cluster mean] bytes];
            if(clusterMean != NULL )
            {
                for(i=0;i<cols;i++)
                {
                    CM[i] = ((nindices-new_size)*CM[i] + new_size*clusterMean[i])/nindices;
                }
            }
		}

        //do colors
        [self setClusterColors:_color forIndices:(unsigned int*)[[cluster points] bytes] length:[[cluster npoints] unsignedIntValue]];
        //
		[self changeZoom];
        [self setNeedsDisplay:YES];
    }
}

-(void) hideCluster: (Cluster *)cluster
{
    GLuint *indices;
    //first check it the cluster is even shown
    if( [cluster isKindOfClass:[Cluster class]] == NO )
    {
        return;
    }
    if( [selectedClusters containsObject:cluster] == NO )
    {
        //if not, do nothing
        return;
    }
    [selectedClusters removeObject:cluster];
    if( [selectedClusters count] >= 1 )
    {
        currentCluster = [selectedClusters lastObject];
    }
	unsigned int _npoints = [[cluster npoints] intValue];
	//first check if hiding this cluster takes away all indices, if so, simply set nindices to 0
	if(nindices - _npoints ==0)
	{
		nindices = 0;
        [indexset removeAllIndexes];
		//update the centroid
		CM[0] = 0;
        CM[1] = 0;
		CM[2] = 0;
        [[self highlightedPoints] setLength:0];
		[self setNeedsDisplay:YES];
		return;
	}
	
    if(_npoints>0)
    {
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
        GLuint *tmp_indices = glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_READ_WRITE);
        if( tmp_indices != NULL)
        {
			//update the centroid
            int i,j,found;
			float *clusterMean = (float*)[[cluster mean] bytes];
            if(clusterMean != NULL )
            {
                for(i=0;i<cols;i++)
                {
                    CM[i] = (nindices*CM[i] - _npoints*clusterMean[i])/(nindices-_npoints);
                }
            }
            //unsigned int *_points = (unsigned int*)malloc((nindices-new_size)*sizeof(unsigned int));
            //new_size = [[cluster indices] count];
            i = 0;
           
            [indexset removeIndexes: [cluster indices]];
            
            j = 0;
            if( [[self highlightedPoints] length] >0 )
            {
                //check if the currentl highltighted points belong to this cluster
                unsigned int *_points = (unsigned int*)[[self highlightedPoints] bytes];
                _npoints = [[self highlightedPoints] length]/sizeof(unsigned int);
                //new array to hold the higlighted points we keep
                unsigned int* newpoints = malloc(_npoints*sizeof(unsigned int  ));
                for(i=0;i<_npoints;i++)
                {
                    if([ [cluster indices] containsIndex:(NSUInteger)_points[i]] == NO )
                    {
                        newpoints[j]=_points[i];
                        j++;
                    }
                }
            
                [[self highlightedPoints] setData:[NSData dataWithBytes:newpoints length:j*sizeof(unsigned int)]];
                free(newpoints);
            }
            NSRange range;
            range.location = 0;
            range.length =nindices;
            //count = [indexset getIndexes: tmp_indices maxCount: nindices-new_size inIndexRange: nil];
            //nindices-=new_size;
            //if(nindices<0)
            //    nindices=0;
            nindices = [indexset count];
            NSUInteger *_index = malloc(nindices*sizeof(NSUInteger));
            [indexset getIndexes: _index maxCount:nindices*sizeof(NSUInteger) inIndexRange:nil];
            for(i=0;i<nindices;i++)
            {
                //indices[i] = (unsigned int)_index[i];
                tmp_indices[i] = (GLuint) _index[i];
            }
            //push the new indices
            //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
            //glBufferData(GL_ELEMENT_ARRAY_BUFFER, nindices*sizeof(unsigned int), indices, GL_DYNAMIC_DRAW);
            //free(_points);
            //reset origin
            //originx = 0.0;
           // originy = 0.0;
            //originz = -2.0;
            glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
            
            [self setNeedsDisplay:YES];
        }

    }
}

-(void) hideAllClusters
{
    [selectedClusters removeAllObjects];
    nindices = 0;
	//reset center of mass to zero
	int i;
	for(i=0;i<cols;i++)
	{
		CM[i] = 0;
	}
	[indexset removeAllIndexes];
    [self setNeedsDisplay:YES];
}

-(void) showAllClusters
{
    nindices = rows;
	[[self openGLContext] makeCurrentContext];
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
	GLuint *index = malloc(rows*sizeof(unsigned int));
	//could make this more efficient, e.g. using range
	unsigned int i;
	for(i=0;i<rows;i++)
	{
		index[i] = i;
	}
	NSRange rng;
	rng.location = 0;
	rng.length = rows;
	[indexset addIndexesInRange:rng];
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, rows*sizeof(GLuint), index, GL_DYNAMIC_DRAW);
	free(index);
    [self setNeedsDisplay:YES];
}

-(void) highlightPoints:(NSDictionary*)params inCluster:(Cluster*)cluster
{
    //draw selected points in complementary color
    NSData *points = [params objectForKey: @"points"];
    unsigned int* _points = (unsigned int*)[points bytes];
    unsigned int _npoints = (unsigned int)([points length]/sizeof(unsigned int));
    int i;
    //store the points such that multiple selections will work
    NSMutableIndexSet *hcp = [NSMutableIndexSet indexSet];
    for(i=0;i<_npoints;i++)
    {
        [hcp addIndex:(NSUInteger)_points[i]];
    }
    //[self setHighlightedClusterPoints:points];
    [self setHighlightedClusterPoints:hcp];
    //NSData *color = [params objectForKey:@"color"];
	//need to make this work when cluster is nil
	NSData *color;
	NSUInteger* _clusterPoints;
    unsigned int _nclusterPoints = 0;
    unsigned int offset = 0;
	if( cluster != nil )
	{
		color = [cluster color];
        _nclusterPoints = [[cluster npoints] unsignedIntValue];
        if( nindices < _nclusterPoints)
        {
            _nclusterPoints = nindices;
            _clusterPoints = malloc(_nclusterPoints*sizeof(NSUInteger));
            [indexset getIndexes: _clusterPoints maxCount:_nclusterPoints inIndexRange:nil];

        }
        else
        {
            _clusterPoints = malloc(_nclusterPoints*sizeof(NSUInteger));
            [[cluster indices] getIndexes: _clusterPoints maxCount:_nclusterPoints inIndexRange:nil];
        }
		//_clusterPoints = (unsigned int*)[[cluster points] bytes];
		
        if(_nclusterPoints == 0)
            _clusterPoints = NULL;
        //we have to determine the offset of the wfidx by finding the index of the cluster in the array of currently selected clusters
        
        NSEnumerator *_clusterEnumerator = [selectedClusters objectEnumerator];
        Cluster *_clu = [_clusterEnumerator nextObject];
        while( (_clu) && ([_clu isEqualTo:cluster]==NO))
        {
            offset+=[[_clu npoints] unsignedIntValue];
            _clu = [_clusterEnumerator nextObject];
        }
        
	}
	else 
	{
		color = [NSData dataWithBytes:base_color length:3*sizeof(GLfloat)];
		//if no cluster is given, just use an index
		_clusterPoints = NULL;	
	}
        //get the indices to redraw
    [[self openGLContext] makeCurrentContext];
    GLuint *idx = malloc(_npoints*sizeof(GLuint));
	unsigned int qidx;
	if( _clusterPoints != NULL )
	{
        //TODO: Also check if we are drawing all points or just a subset; if the latter, the number of drawn indices, nindices, should be smaller than the number of points in the cluster
		for(i=0;i<_npoints;i++)
		{
			//idx[i] = tmp_idx[_clusterPoints[_points[i]]];
			//need to check that this does not cause a negative inded
			//
			qidx = _points[i] >= offset ? _points[i]-offset : _points[i];
			idx[i] = _clusterPoints[qidx];
			//idx[i] = _points[i];
		}
	}
	else
	{
		//if no cluster is given, just use the raw indiex
		for(i=0;i<_npoints;i++)
		{
			//idx[i] = tmp_idx[_clusterPoints[_points[i]]];
			idx[i] = _points[i];
		}	
	}
    //glUnmapBuffer(GL_ARRAY_BUFFER);
    
    //GLfloat *_color = (GLfloat*)[color bytes];
    
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    GLfloat *_colors = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    //reset the colors before doing the new colors
    if( (highlightedPoints != NULL ) && (appendHighlights == NO) )
    {
        unsigned int* _hpoints = (unsigned int*)[highlightedPoints bytes];
        unsigned int _nhpoints = (unsigned int)([highlightedPoints length]/sizeof(unsigned int));
        //GLfloat *_bcolor = (GLfloat*)[bcolor bytes];
        for(i=0;i<_nhpoints;i++)
        {
            _colors[_hpoints[i]*3] = 1-_colors[_hpoints[i]*3];
            _colors[_hpoints[i]*3+1] = 1-_colors[_hpoints[i]*3+1];
            _colors[_hpoints[i]*3+2] =1-_colors[_hpoints[i]*3+2];
        }
    }
    
    for(i=0;i<_npoints;i++)
    {
        _colors[idx[i]*3] = 1-_colors[idx[i]*3];
        _colors[idx[i]*3+1] = 1-_colors[idx[i]*3+1];
        _colors[idx[i]*3+2] = 1- _colors[idx[i]*3+2];
    }
	glUnmapBuffer(GL_ARRAY_BUFFER);
    if( highlightedPoints == NULL)
    {
        [self setHighlightedPoints: [NSMutableData dataWithBytes: idx length: _npoints*sizeof(GLuint)]];
    }
    else
    {
    
        [[self highlightedPoints] setData: [NSData dataWithBytes: idx length: _npoints*sizeof(GLuint)]];

    }
	free(idx);
    //free _clusterPoints if we have declared it
    if( _clusterPoints != NULL)
    {
        free(_clusterPoints);
    }
    //update the menu
    [[[self menu] itemWithTitle:@"Add points to cluster"] setEnabled:YES];
    [[[self menu] itemWithTitle:@"Remove points from cluster"] setEnabled:YES];
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
    [[self openGLContext] makeCurrentContext];
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
-(void) modifyVertices
{
    int i,j;
    float *_vertices,*_all_vertices;
    _all_vertices = (float*)[vertices bytes];
    //get the vertices from the GPU
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    for(i=0;i<rows;i++)
    {
        for(j = 0;j<ndraw_dims;j++)
        {
            _vertices[i*ndraw_dims+j] = _all_vertices[i*cols+draw_dims[i]];
        
        }
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [self setNeedsDisplay:YES];
            
}
 

/*static void modifyVertices(GLfloat *vertex_data)
{
    float *_vertices;
    _vertices = (float*)[vertices bytes];
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
    
    
}*/


/*static void modifyIndices(GLuint *index_data)
{
    int i;
    
    for(i=0;i<rows;i++)
    {
        index_data[i] = i;
    }
    
}*/

/*static void modifyColors(GLfloat *color_data)
{
    int i;
    for(i=0;i<rows;i++)
    {
        color_data[3*i] = 1.0f;//use_colors[3*cids[i+1]];
        color_data[3*i+1] = 0.85f;//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = 0.35f;//use_colors[3*cids[i+1]+2];
    }
}*/

/*static void pushVertices()
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
    
    
}*/

static void drawFrame()
{
	//finally connect the corners
	glColor4f(0.5f,0.85f,0.35f,0.5f);
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

-(void) drawAnObject
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
	//allow drawing of square
	
}

-(void)drawLabels
{
	if( (glabelX == nil ) || (glabelY == nil) || (glabelZ == nil ) )
	{
		NSMutableDictionary *normal9Attribs = [NSMutableDictionary dictionary];
		[normal9Attribs setObject: [NSFont fontWithName: @"Helvetica" size: 12.0f] forKey: NSFontAttributeName];
		
		NSAttributedString *labelX,*labelY,*labelZ;
		labelX = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"Axis 1"]  attributes:normal9Attribs] autorelease];
		labelY = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"Axis 2"]  attributes:normal9Attribs] autorelease];

		labelZ = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"Axis 3"]  attributes:normal9Attribs] autorelease];

		//GLString *glabel;
		glabelX = [[[GLString alloc] initWithAttributedString:labelX
											  withTextColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.56f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.0f alpha:1.0f] withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f]] retain];
		glabelY = [[[GLString alloc] initWithAttributedString:labelY 
												withTextColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.56f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.0f alpha:1.0f] withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f]] retain];
		glabelZ = [[[GLString alloc] initWithAttributedString:labelZ 
												withTextColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.56f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:1.0f green:0.0f blue:0.0f alpha:1.0f] withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f]] retain];

	}
	GLfloat width = [self bounds].size.width;
	GLfloat height = [self bounds].size.height;

	/*glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();*/
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glTranslatef(originx, originy, originz);
	glRotatef(rotatey,0, 1, 0);
	glRotatef(rotatez, 0, 0,1);
	//X-label
	glPushMatrix();
	glTranslatef(0.0, 1.0, 1.1);
	//glTranslatef(1.0, 0, 0);
	glScalef (2.0f / width, -2.0f /  height, 1.0f);
	//glTranslatef (-width / 2.0f, -height / 2.0f, 0.0f);	
	[glabelX drawAtPoint:NSMakePoint (10.0f, height - [glabelX frameSize].height - 10.0f)];
	glPopMatrix();
	
	//Y-label
	glPushMatrix();

	//glRotatef(90,0,1,0);
	glRotatef(90, 0, 0, 1);
	glTranslatef(1.5, 1.7, 1.1);

	glScalef (2.0f / width, -2.0f /  height, 1.0f);
	glTranslatef (-width / 2.0f, -height / 2.0f, 0.0f);	
	[glabelY drawAtPoint:NSMakePoint (10.0f, height - [glabelY frameSize].height - 10.0f)];
	glPopMatrix();
	
	//Z-label
	/*glPushMatrix();
	//glRotatef(90,1,0,0);
	glScalef (2.0f / width, -2.0f /  height, 1.0f);
	glTranslatef (-width / 2.0f, -height / 2.0f, 0.0f);
	//rotate
	glRotatef(90, 0, 0, 1);
	[glabelZ drawAtPoint:NSMakePoint (10.0f, height - [glabelZ frameSize].height - 10.0f)];
	glPopMatrix();*/
	
	GLenum err = glGetError();
	NSLog(@"glError: %s" ,(char *) gluErrorString (err));
	/*
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();*/

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
    glClearColor(0.,0.,0.,1.0);
    glClear(GL_COLOR_BUFFER_BIT);
	
    glClear(GL_DEPTH_BUFFER_BIT);
	//scale = 30.0f;
	//[self changeZoom];
    if( drawAxesLabels )
    {
        [self drawLabels];
    }
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	//glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 1, 4);
    //define an orthographic projection, spanning -10 to 10 in the z-direction
	glOrtho(-2*scale, 2*scale, -2*scale, 2*scale, -10, 10);
    //use look at to define our viewing transform. Eye is positioned 4 units in the NEGATIVE z-direction (towards the viewer), and the origin is 2 units into the screen (z-0 is in the viewing plane, i.e. the screen
    gluLookAt(0, 0, 4.0, originx, originy, originz, 0, 1, 0);
	glMatrixMode(GL_MODELVIEW);
    if ([self showFrame] )
    {
        drawFrame();
    }
	
	/*This code is for testing mouse clicks
	if(picked)
	{
		glPushMatrix();
		glBegin(GL_POINTS);
		glVertex3f(pickedPoint[0],pickedPoint[1],pickedPoint[2]);
		glColor3f(1.0,0.0,0.0);
	    glEnd();
		//glTranslatef(pickedPoint[0],pickedPoint[1],pickedPoint[2]);
		glPopMatrix();

	}
	*/
	if(dataloaded)
    {
		glLoadIdentity();
		//draw lines to indicate the centroid; this should be removed
//		glBegin(GL_LINES);
//		glVertex3f(CM[draw_dims[0]], -2, CM[draw_dims[2]]);
//		glColor3f(1.0, 0.0, 0.0);
//		glVertex3f(CM[draw_dims[0]], 2, CM[draw_dims[2]]);
//		glColor3f(1.0, 0.0, 0.0);
//		glEnd();

		glTranslatef(CM[draw_dims[0]], CM[draw_dims[1]], CM[draw_dims[2]]);

		glRotatef(rotatey,0, 1, 0);
		glRotatef(rotatez, 0, 0,1);
		glTranslatef(-CM[draw_dims[0]], -CM[draw_dims[1]], -CM[draw_dims[2]]);
		//glTranslatef(originx, originy, originz);
		//test; draw a line parallel to the y-axis through the origin
//		glBegin(GL_LINES);
//		glVertex3f(CM[draw_dims[0]], -2, CM[draw_dims[2]]);
//		glColor3f(1.0, 0.0, 0.0);
//		glVertex3f(CM[draw_dims[0]], 2, CM[draw_dims[2]]);
//		glColor3f(1.0, 0.0, 0.0);
//		glEnd();
		[self drawAnObject];
		if(drawRect)
		{
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glOrtho(-2*scale, 2*scale, -2*scale, 2*scale, -10, 10);
			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
			glBegin(GL_LINE_STRIP);
			glColor3f(1.0,0.0,0.0);
			glVertex3f(selectionRec.origin.x,selectionRec.origin.y, 1.0);
			glColor3f(1.0,0.0,0.0);
			glVertex3f(selectionRec.origin.x+selectionRec.size.width,selectionRec.origin.y, 1.0);
			glColor3f(1.0,0.0,0.0);
			glVertex3f(selectionRec.origin.x+selectionRec.size.width,selectionRec.origin.y+selectionRec.size.height, 1.0);
			glColor3f(1.0,0.0,0.0);
			glVertex3f(selectionRec.origin.x,selectionRec.origin.y+selectionRec.size.height, 1.0);
			glColor3f(1.0,0.0,0.0);
			glVertex3f(selectionRec.origin.x,selectionRec.origin.y, 1.0);
			glEnd();
		}

		//drawAnObject();

    }
    //glFlush();
    [[self openGLContext] flushBuffer];

}

-(NSImage*)image
{
    //for drawing the image
    NSBitmapImageRep *imageRep;
    NSImage *image;
    NSSize viewSize = [self bounds].size;
    int width = viewSize.width;
    int height = viewSize.height;
    
    //[self lockFocus];
    //[self lockFocusIfCanDraw];
    //[self drawRect:[self bounds]];
    //[self unlockFocus];
    [self display];
    imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL 
                                                        pixelsWide: width 
                                                        pixelsHigh: height 
													 bitsPerSample: 8 
                                                   samplesPerPixel: 4 
                                                          hasAlpha: YES 
                                                          isPlanar: NO 
                                                    colorSpaceName: NSDeviceRGBColorSpace 
                                                       bytesPerRow: width*4     
													  bitsPerPixel:32] autorelease];
    
    [[self openGLContext] makeCurrentContext];
    //bind the vertex buffer as an pixel buffer
    //glBindBuffer(GL_PIXEL_PACK_BUFFER, wfVertexBuffer);
    glReadPixels(0,0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
    image = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [image addRepresentation:imageRep];
    [image lockFocusFlipped:YES];
    [imageRep drawInRect:NSMakeRect(0,0,[image size].width, [image size].height)];
    [image unlockFocus];
    return image;
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
    

    glClearColor(0,0, 0, 1.0);
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
	glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 1, 6);
	gluLookAt(0, 0, 2.0, originx, originy, originz, 0, 1, 0);

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
	gluLookAt(0, 0, 2.0, 0, 0, 0, 0, 1, 0);

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
	glFrustum(-1*scale, 1*scale, -1*scale,1*scale, 1, 6);
    //always look at the origin
	gluLookAt(0, 0, 2.0, originx, originy, originz-2, 0, 1, 0);
	
	[self setNeedsDisplay:YES];
	
}
-(void) receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"highlight"])
    {
        if([[self window] isVisible] )
            [self highlightPoints:[notification userInfo] inCluster: [notification object]];
    }
    else if( [[notification name] isEqualToString:NSUserDefaultsDidChangeNotification])
    {
        [self setDrawLabels:[[[NSUserDefaults standardUserDefaults] objectForKey:@"showFeatureAxesLabels"] boolValue]];
        [self setShowFrame: [[[NSUserDefaults standardUserDefaults] objectForKey:@"showFeatureAxesFrame"] boolValue]];
        [self setNeedsDisplay:YES];
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
    else if( ([theEvent modifierFlags] & NSCommandKeyMask) && ([[theEvent characters] isEqualToString:@"f"]))
    {
        [self enterFullScreenMode:[NSScreen mainScreen] withOptions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], NSFullScreenModeWindowLevel, nil]];    
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
        else if( [theEvent keyCode] == 53 )
        {
            if( [self isInFullScreenMode] )
            {
                [self exitFullScreenModeWithOptions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], NSFullScreenModeWindowLevel, nil]];
            }
        }
        else
        {
            [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
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

-(void)mouseDown:(NSEvent*)theEvent
{
	//need to get the currentPoint in data coordinates
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    GLint view[4];
    GLdouble p[16];
    GLdouble m[16];
    [[self openGLContext] makeCurrentContext];
    glGetDoublev (GL_MODELVIEW_MATRIX, m);
    glGetDoublev (GL_PROJECTION_MATRIX,p);
    glGetIntegerv( GL_VIEWPORT, view );
    double objXNear,objXFar,objYNear,objYFar,objZNear,objZFar;
    float *_vertices = (float*)[vertices bytes];
    //get the position of the points in the original data space
    //note that since window coordinates are using lower left as (0,0), openGL uses upper left
    GLfloat depth[2];
    //get the z-component
    glReadPixels(currentPoint.x, /*height-*/currentPoint.y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, depth);
    //get a ray
    gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[1], m, p, view, &objXNear, &objYNear, &objZNear);
    gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[0], m, p, view, &objXFar, &objYFar, &objZFar);
	//if([theEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask))
	//{
		//create a rectangle starting at currentPoint and with zero size for now
	 //   selectionRec = NSMakeRect(objXNear,objYNear,0,0);
		//selectionRec = NSMakeRect(currentPoint.x,currentPoint.y,0,0);
//		drawRect = YES;
//	}

}

-(void)mouseUp:(NSEvent *)theEvent
{
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    GLint view[4];
    GLdouble p[16];
    GLdouble m[16];
    [[self openGLContext] makeCurrentContext];
    glGetDoublev (GL_MODELVIEW_MATRIX, m);
    glGetDoublev (GL_PROJECTION_MATRIX,p);
    glGetIntegerv( GL_VIEWPORT, view );
    double objXNear,objXFar,objYNear,objYFar,objZNear,objZFar;
    float *_vertices = (float*)[vertices bytes];
    //get the position of the points in the original data space
    //note that since window coordinates are using lower left as (0,0), openGL uses upper left
    GLfloat depth[2];
    //get the z-component
    glReadPixels(currentPoint.x, /*height-*/currentPoint.y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, depth);
    //get a ray
    gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[1], m, p, view, &objXNear, &objYNear, &objZNear);
    gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[0], m, p, view, &objXFar, &objYFar, &objZFar);

    if([theEvent modifierFlags] & ( NSCommandKeyMask | NSShiftKeyMask))
    {
        //only select points if Command key is pressed
        //if we are also pressing the shift button, append highlights
        //get current point in view coordinates
        //now we will have to figure out which waveform(s) contains this point
        //scale to data coorindates
        //scale to data coordinates
        //take into account rotation
        //compute appropriate 2-D projection; initial projection is the x-y plane
       
        
        GLdouble ray[3];
		ray[0] = -objXNear+objXFar;
		ray[1] = -objYNear+objYFar;
		ray[2] = -objZNear+objZFar;
		GLdouble _r = sqrt(ray[0]*ray[0] + ray[1]*ray[1] + ray[2]*ray[2]);
		//normalize
		ray[0]/=_r;
		ray[1]/=_r;
		ray[2]/=_r;
		picked = YES;
		pickedPoint[0] = objXNear;
		pickedPoint[1] = objYNear;
		pickedPoint[2] = objZNear;
		NSUInteger i,k,cidx;
        float vX,vY,vZ;
		double dmin = INFINITY;
		unsigned int *wfidx;
		NSMutableIndexSet *foundIndices = [NSMutableIndexSet indexSet];
		//if([theEvent modifierFlags] & NSShiftKeyMask)
		if(drawRect)
		{
			//grab all points contained (behind) within the rectangle
			k = [indexset firstIndex];
			i = 0;
			while(k != NSNotFound )
			{
				//get the vertices
				vX = _vertices[k*cols+draw_dims[0]];
				vY = _vertices[k*cols+draw_dims[1]];
				vZ = _vertices[k*cols+draw_dims[2]];
				//check if they are within the rectangle
				if( (vX >= selectionRec.origin.x) && (vX <= selectionRec.origin.x+selectionRec.size.width) ||
				 (vX <= selectionRec.origin.x) && (vX >= selectionRec.origin.x+selectionRec.size.width))
				{
					if( (vY >= selectionRec.origin.y) && (vY <= selectionRec.origin.y+selectionRec.size.height) ||
					 (vY <= selectionRec.origin.y) && (vY >= selectionRec.origin.y+selectionRec.size.height) )
					{
						[foundIndices addIndex: k];

					}
				}
				k = [indexset indexGreaterThanIndex:k];

			}
			//reset the rectangle
			drawRect = NO;
			selectionRec.size.width=0;
			selectionRec.size.height=0;
		}
		else
		{
    
			//once we have the ray, we can look for intersections
			//since we are only interested in points, we can simply check whether the point +/- its radius encompasses the line 
			//line given by x0 + ray[0](x-x0), y0 + ray[1](y-y0), z0 + ray[2](z-z0)
			//for each object, decompose the vector from the near point to the object into components parallel and orthogonal to the ray. Then check whether the length of the orthogonal component is smaller than the radius of the object. If it is, we have intersection
			//
			//cidx = wfidx;
			double dT = INFINITY;
			//go through each index currently drawn
			//[indexset enumerateIndexesUsingBlock:^(NSUInteger k, BOOL *stop)
			k = [indexset firstIndex];
			i = 0;
			while(k != NSNotFound )
			//for(i=0;i<nindices;i++)
			{
				double a = 0;
				vX = _vertices[k*cols+draw_dims[0]];
				vY = _vertices[k*cols+draw_dims[1]];
				vZ = _vertices[k*cols+draw_dims[2]];
				//component along ray
				//k = indices[i];
				//Eureka! also care about which dimensions we are drawing,i.e. the ordering could change
				a+=ray[0]*(vX - objXNear);
				a+=ray[1]*(vY - objYNear);
				a+=ray[2]*(vZ - objZNear);

				double v[3];
				double rv = 0;
				v[0] = (vX-objXNear)-a*ray[0];
				rv+=v[0]*v[0];
				v[1] = (vY-objYNear)-a*ray[1];
				rv+=v[1]*v[1];
				v[2] = (vZ-objZNear)-a*ray[2];
				rv+=v[2]*v[2];

				//this is the distance from the object to the ray
				rv = sqrt(rv);
				//check if it's the smallest so far, and that it's smaller than the threshold, dT
				if( (rv<dmin) )
				{
					dmin = rv;
					if( rv < dT)
					{
							//again, the index to pass to the highlight function needs to be in cluster coordinates, not global coordinates
							wfidx = i;	
							cidx = k;
							//[foundIndices addIndex: k];
					}
				}
				k = [indexset indexGreaterThanIndex:k];
				i+=1;

			}
			[foundIndices addIndex: cidx];
		}
        Cluster *useCluster = nil;
		unsigned int offset = 0;
		wfidx = malloc(([foundIndices count])*sizeof(unsigned int));
        if ([selectedClusters count] ==1 )
        {
            useCluster = [selectedClusters objectAtIndex:0];
        }
        else if ([selectedClusters count]>1) 
        {
            
            //TODO: if multiple clusters are selected, it is possible that we are also showing multiple clusters in the waveformview. In that case, the selected point should refer to the aggregate of the points in the two clusters, not one cluster on its own. Note also that order matters; assume we the order is preserved
            //now figure out which cluster the select point was in
            NSUInteger q = 0;
            useCluster = [selectedClusters objectAtIndex:q];
            while( [[useCluster indices] containsIndex:cidx] == NO)
            {
                offset+=[[useCluster npoints] unsignedIntValue];
                
                q+=1;
                useCluster = [selectedClusters objectAtIndex:q];
            }            
		}
		//the brute force way; go through the cluster points to find the index
		NSUInteger _npoints = [[useCluster npoints] unsignedIntValue];
		unsigned int *_points = (unsigned int*)[[useCluster points] bytes];
		unsigned int l = 0;
		//loop through until we find it
		//here we should got through each of the indices
		k = [foundIndices firstIndex];
		i = 0;
		while(k != NSNotFound )
		{
			while( (_points[l] != k ) && (l < _npoints ) )
				l++;
			wfidx[i] = l+offset;
			k = [foundIndices indexGreaterThanIndex: k];
			i+=1;
		}

        //make sure we actually found a point first
		if([foundIndices count]>0)
		{
            //TODO: this will not work; highlighted points is in global, not cluster coordinates
            //NSMutableData *wfidxData = [NSMutableData dataWithBytes: &wfidx length: sizeof(unsigned int)];
            NSMutableData *wfidxData = [NSMutableData dataWithCapacity:10*sizeof(unsigned int)];
            if( ([theEvent modifierFlags] & NSShiftKeyMask) && (highlightedClusterPoints != NULL) )
            {
                //TODO: only append if point is not already highlighted
                if( [[self highlightedClusterPoints] containsIndex:(NSUInteger)wfidx]==NO )
                {
                    [wfidxData appendBytes:wfidx length:([foundIndices count])*sizeof(unsigned int)];
                }
                else
                {
                    //the point has already been highlighted; a second click means we want to remove it
					for(i=0;i<[foundIndices count];i++)
						[[self highlightedClusterPoints] removeIndex:wfidx[i]];
                }
                NSUInteger _count = [[self highlightedClusterPoints] count];
                NSUInteger *hpc = malloc(_count*sizeof(NSUInteger));
                [[self highlightedClusterPoints] getIndexes:hpc maxCount:_count inIndexRange:nil];
                unsigned int f;
                for(i=0;i<_count;i++)
                {
                    f = (unsigned int)hpc[i];
                    [wfidxData appendBytes:&f length:sizeof(unsigned int)];

                }
            }
            else
            {
                [wfidxData appendBytes:wfidx length:([foundIndices count])*sizeof(unsigned int)];
            }
			[[self openGLContext] makeCurrentContext];
			glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
			float *color = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
		 	float *_colors = malloc(3*([foundIndices count])*sizeof(float));
			for(i=0;i<[foundIndices count];i++)
			{
				_colors[3*i] = color[3*wfidx[i]];
				_colors[3*i+1] = color[3*wfidx[i]+1];
				_colors[3*i+2] = color[3*wfidx[i]+2];
			}
			//we don't need wfidx any more
			free(wfidx);
			NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:wfidxData,[NSData dataWithBytes: _colors length:3*([foundIndices count])*sizeof(float)],nil] forKeys: [NSArray arrayWithObjects: @"points",@"color",nil]];
			glUnmapBuffer(GL_ARRAY_BUFFER);
			free(_colors);
            //TODO: What if we want to select points from mutiple clusters?
			[[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:useCluster userInfo: params];
			//[self highlightPoints:params];
		}
    }
    /*
    else if( [[theEvent characters] isEqualToString:@"c"] )
    {
        
    }
     */
	//reset rectangle
	drawRect = NO;
	[self setNeedsDisplay:YES];
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
        float f = [event magnification];
        //convert from addititive to multiplicative
        scale*=(1-f);
        [self changeZoom];
    }
}

-(void)mouseDragged:(NSEvent *)theEvent
{
	BOOL needDisplay = NO;
	//are we dragging while holding down Command? If so, we are performing a multiple select
	if([theEvent modifierFlags] & NSCommandKeyMask)
	{
		//need to get the currentPoint in data coordinates
		NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
		GLint view[4];
		GLdouble p[16];
		GLdouble m[16];
		[[self openGLContext] makeCurrentContext];
		glGetDoublev (GL_MODELVIEW_MATRIX, m);
		glGetDoublev (GL_PROJECTION_MATRIX,p);
		glGetIntegerv( GL_VIEWPORT, view );
		double objXNear,objXFar,objYNear,objYFar,objZNear,objZFar;
		float *_vertices = (float*)[vertices bytes];
		//get the position of the points in the original data space
		//note that since window coordinates are using lower left as (0,0), openGL uses upper left
		GLfloat depth[2];
		//get the z-component
		glReadPixels(currentPoint.x, /*height-*/currentPoint.y, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, depth);
		//get a ray
		gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[1], m, p, view, &objXNear, &objYNear, &objZNear);
		gluUnProject(currentPoint.x, /*height-*/currentPoint.y, /*1*/depth[0], m, p, view, &objXFar, &objYFar, &objZFar);
		//if((selectionRec.size.width==0) && (selectionRec.size.height==0) && (drawRect==NO))
		if(drawRect == NO)
		{
			selectionRec.origin.x = objXNear;
			selectionRec.origin.y = objYNear;
		}
		else
		{
			selectionRec.size.width = objXNear-selectionRec.origin.x;
			//selectionRec.size.width = currentPoint.x-selectionRec.origin.x;
			selectionRec.size.height = objYNear-selectionRec.origin.y;
		}
		drawRect = YES;
		needDisplay = YES;
		
	}
	else
	{
		//shift the origin by some amount
		if( [theEvent deltaX] < -1 )
		{
			originx+=0.1*scale;
			needDisplay = YES;
		}
		else if( [theEvent deltaX] > 1 )
		{
			originx-=0.1*scale;
			needDisplay = YES;

		}
		if( [theEvent deltaY] < -1 )
		{
			originy-=0.1*scale;
			needDisplay = YES;

		}
		else if( [theEvent deltaY] > 1 )
		{
			originy+=0.1*scale;
			needDisplay = YES;

		}
	}
	[self setNeedsDisplay:needDisplay];
			  
}

-(void)rightMouseDragged:(NSEvent *)theEvent
{
	BOOL needDisplay = NO;
	if( [theEvent deltaY] < -1 )
	{
		//originz-=0.1;
        [self zoomIn];
		needDisplay = YES;
	}
	else if( [theEvent deltaY] > 1 )
	{
		//originz+=0.1;
		[self zoomOut];
        needDisplay = YES;
		
	}
	[self setNeedsDisplay:needDisplay];
	
}

-(void) setDrawLabels:(BOOL)_drawLabels
{
    drawAxesLabels = _drawLabels;
}

-(void) deleteBackward:(id)sender
{
	//meant for deleting waveforms
	//alert the application that we want to remove a waveform
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Remove waveforms" forKey:@"option"];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"performClusterOption" object:self userInfo: userInfo];
}

-(void) performClusterOption:(id)sender
{
    NSString *option = [sender title];
    NSMenuItem *item = [sender parentItem];
    NSDictionary *params = NULL;
	if( item != nil )
	{
		if([[item title] isEqualToString:@"Add points to cluster"] )
		{
			params = [NSDictionary dictionaryWithObjectsAndKeys:[item title], @"option", option, @"clusters",nil];
		}
        else if([[item title] isEqualToString:@"Move points to cluster"] ) 
        {
            params = [NSDictionary dictionaryWithObjectsAndKeys:[item title], @"option", option, @"clusters",nil];
        }
	}
	else if([[sender title] isEqualToString:@"Remove points from cluster"] )
	{
        //params = [NSDictionary dictionaryWithObjectsAndKeys:@"Remove waveforms", @"option",nil];
        params = [NSDictionary dictionaryWithObjectsAndKeys:@"Remove points from cluster", @"option", nil];

	}

    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:option, @"option", nil];
    }
    if(params != NULL)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"performClusterOption" object:self userInfo:params];
    }
}

-(void)dealloc
{
    [vertices release];
    //free(use_vertices);
    //free(indices);
    free(minmax);
	free(CM);
    //free(colors);
    //free(cids);
    free(use_colors);
   // free(indexset);
    [indexset release];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [selectedClusters release];
    [super dealloc];
}

@end
