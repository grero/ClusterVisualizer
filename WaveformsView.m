//
//  WaveformsView.m
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveformsView.h"

#define MIN(a,b) ((a)>(b)?(b):(a))
#define PI 3.141516

@implementation WaveformsView

@synthesize highlightWaves;
@synthesize highlightedChannels;

-(void)awakeFromNib
{
    wfDataloaded = NO;
}

-(BOOL)acceptsFirstResponder
{
    return YES;
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
    return [self initWithFrame:frameRect pixelFormat: [WaveformsView defaultPixelFormat]];

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
        
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) 
        //                                             name:@"highlight" object:nil];
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
        //TODO: Something happens here; somehow the view doesn't get upated properly when the window is resized.
        //[[self openGLContext] flushBuffer];
		
    }
}



-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints andColor: (NSData*)color andOrder: (NSData*)order;
{
	//TODO: modify this should that multiple clusters can be drawn in the same view, with each cluster a different color
    wavesize = channels*timepoints;
    waveIndexSize = channels*(2*timepoints-2);
	//+1 to make room for mean waveform
    nWfIndices = (nwaves+1)*wavesize;
    nWfVertices = nWfIndices;
    num_spikes = nwaves;
    chs = channels;
    timepts = timepoints;
	//create an index that will tell us which waveforms are active
	NSRange r;
	r.location = 0;
	r.length = num_spikes;
	waveformIndices = [[NSMutableIndexSet indexSetWithIndexesInRange:r] retain];
	//reset highlights

    if([self highlightWaves] != NULL)
    {
        [[self highlightWaves] setLength:0];
        [self setHighlightWaves:NULL];
    }
    if ((wfDataloaded) && (wfVertices != NULL ) )
    {
        wfVertices = realloc(wfVertices, nWfVertices*3*sizeof(GLfloat));
    }
    else{
        wfVertices = malloc(nWfVertices*3*sizeof(GLfloat));
    }
    highlightWave = -1;
    float *tmp = (float*)[vertex_data bytes];
    
    int i,j,k;
    unsigned int offset = 0;
	unsigned int moffset = 0;
    //3 dimensions X 2
    wfMinmax = calloc(6,sizeof(float));
	chMinMax = NSZoneCalloc([self zone], 2*chs, sizeof(float));
    channelHop = 10;
    //copy wfVertices
    //float dz = (100.0-1.0)/num_spikes;
	//allow for rearranging channels here
	//TODO: use dispatch here
	if( order == NULL )
	{
		
		for(i=0;i<nwaves;i++)
		//dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
		//dispatch_apply(nwaves, queue, ^(size_t i){
			//int j,k;
		//	unsigned int offset;
		{
			for(j=0;j<channels;j++)
			{
				for(k=0;k<timepoints;k++)
				{
					offset = ((i*channels+j)*timepoints + k);
					moffset = ((nwaves*channels+j)*timepoints + k);

					//x
					//wfVertices[offset] = tmp[offset];
					wfVertices[3*offset] = j*(timepoints+channelHop)+k+channelHop;
					//y
					wfVertices[3*offset+1] = tmp[offset];
					//z
					wfVertices[3*offset+2] = -1.0;//-(1.0+dz*i);//-(i+1);
					//compute the mean, placing it after all the other waves
					//this line is strictly not necessary
					wfVertices[3*moffset] = wfVertices[3*offset];
					wfVertices[3*moffset+1] =(i*(wfVertices[3*moffset+1])+tmp[offset])/(i+1);
					wfVertices[3*moffset+2] = 1.0;
					//calculate wfMinmax
					if (tmp[offset] < wfMinmax[2] )
					{
						wfMinmax[2] = tmp[offset];
					}
					if (tmp[offset] > wfMinmax[3] )
					{
						wfMinmax[3] = tmp[offset];
					}
					//compute max/min per channel
					if ( tmp[offset] < chMinMax[2*j] )
					{
						chMinMax[2*j] = tmp[offset];
					}
					else if ( tmp[offset] > chMinMax[2*j+1] )
					{
						chMinMax[2*j+1] = tmp[offset];
					}
				}
				
			}
		}//);
	}
	else 
	{
		unsigned int* reorder_index  = (unsigned int*)[order bytes];
		
		for(i=0;i<nwaves;i++)
		{
			for(j=0;j<channels;j++)
			{
				for(k=0;k<timepoints;k++)
				{
					offset = ((i*channels+reorder_index[j])*timepoints + k);
					moffset = ((nwaves*channels+j)*timepoints + k);

					//x
					//wfVertices[offset] = tmp[offset];
					wfVertices[3*offset] = j*(timepoints+channelHop)+k+channelHop;
					//y
					wfVertices[3*offset+1] = tmp[offset];
					//z
					wfVertices[3*offset+2] = -1.0;//-(1.0+dz*i);//-(i+1);
					
					//mean
					//this line is strictly not necessary
					wfVertices[3*moffset] = wfVertices[3*offset];
					wfVertices[3*moffset+1] =(i*(wfVertices[3*moffset+1])+tmp[offset])/(i+1);
					wfVertices[3*moffset+2] = 1.0;
					
					//calculate wfMinmax
					if (tmp[offset] < wfMinmax[2] )
					{
						wfMinmax[2] = tmp[offset];
					}
					if (tmp[offset] > wfMinmax[3] )
					{
						wfMinmax[3] = tmp[offset];
					}
					//compute max/min per channel
					if ( tmp[offset] < chMinMax[2*j] )
					{
						chMinMax[2*j] = tmp[offset];
					}
					else if ( tmp[offset] > chMinMax[2*j+1] )
					{
						chMinMax[2*j+1] = tmp[offset];
					}
				}
				
			}
		}
		
	}
	
	wfMinmax[0] = 0;
    wfMinmax[1] = channels*(timepoints+channelHop);
	xmin = 0;
	xmax = wfMinmax[1];
    wfMinmax[4] = -1.0;//0.1;
    wfMinmax[5] = 1.0;//100;//nwaves+2;
	ymin = wfMinmax[2];
	ymax = wfMinmax[3];
    //create indices
    
    //here we have to be a bit clever; if we want to draw as lines, every vertex will be connected
    //However, since we are drawing waveforms across channels, we need to separate waveforms on each
    //channel. We do this by modifying the indices. We will use GL_LINE_STRIP, which will connect every other index
    //i.e. 1-2, 3-4,5-6,etc..
    //for this we need to know how many channels, as well as how many points per channel
    //each channel will have 2*pointsPerChannel-2 points
    unsigned int pointsPerChannel = 2*timepoints-2;
    //unsigned int offset = 0;
	//+1 to accommodate mean waveform
    nWfIndices = (nwaves+1)*channels*pointsPerChannel;
    if( (wfDataloaded) && (wfIndices != NULL ))
    {
        wfIndices = realloc(wfIndices, nWfIndices*sizeof(GLuint));

    }
    else {
        wfIndices = malloc(nWfIndices*sizeof(GLuint));

    }

    for(i=0;i<nwaves+1;i++)
    {
        for(j=0;j<channels;j++)
        {
            //do the first point seperately, since it's not repeated
            offset = (i*channels + j)*pointsPerChannel;
            wfIndices[offset] = (i*channels+j)*timepoints;
            for(k=1;k<timepoints-1;k++)
            {
                wfIndices[offset+2*k-1] = (i*channels+j)*timepoints+k;
                //replicate the previous index
                wfIndices[offset+2*k] = wfIndices[offset+2*k-1];
            }
            wfIndices[offset+2*timepoints-3] = (i*channels+j)*timepoints + timepoints-1;
        }
    }
    //
    //test - PASS
    /*
    float a;
    for(i=0;i<nWfIndices;i++)
    {
        a = wfVertices[3*indices[i]];
        a = wfVertices[3*indices[i]+1];
        a = wfVertices[3*indices[i]+2];
    }*/
    //
    wfColors = malloc(nWfVertices*3*sizeof(GLfloat));
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
    //GLfloat *gcolor = malloc(4*sizeof(GLfloat));
    GLfloat *gcolor = (GLfloat*)[color bytes];
    /*gcolor[0] = 1.0;
    gcolor[1] = 0.85;
    gcolor[2] = 0.35;
    gcolor[4] = 1.0;*/
    [self setColor: color];
    //[[self getColor] getRed:gcolor green:gcolor+1 blue:gcolor+2 alpha:gcolor+3];
    wfModifyColors(wfColors,gcolor);
    //free(gcolor);
    //push everything to the GPU
    wfPushVertices();
	
	//free(wfVertices);
	//free(wfColors);
	//free(wfIndices);
    //draw
    //[self highlightWaveform:0];
    //wavesize = (2*timepoints-2)*channels;
    [self setNeedsDisplay: YES];
    
}

static void wfPushVertices()
{
    //set up index buffer
    //int k = 0;
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(1.05*xmin-0.05*xmax, 1.05*xmax-0.05*xmin, 1.05*wfMinmax[2]-0.05*wfMinmax[3], 
			1.05*wfMinmax[3]-0.05*wfMinmax[2], 1.05*wfMinmax[4]-0.05*wfMinmax[5], 1.05*wfMinmax[5]-0.05*wfMinmax[4]);
    //glFrustum(1.1*wfMinmax[0], 1.1*wfMinmax[1], 1.1*wfMinmax[2], 1.1*wfMinmax[3], 1.1*wfMinmax[5], 1.1*wfMinmax[4]);

    glGenBuffers(1,&wfIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, wfIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nWfIndices*sizeof(GLuint),wfIndices, GL_DYNAMIC_DRAW);
    //generate 1 buffer of type wfVertexBuffer
    
    
    glGenBuffers(1,&wfColorBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    glBufferData(GL_ARRAY_BUFFER, nWfVertices*3*sizeof(GLfloat),wfColors,GL_DYNAMIC_DRAW);
    
    //bind wfVertexBuffer
    glGenBuffers(1,&wfVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ARRAY_BUFFER, nWfVertices*3*sizeof(GLfloat), wfVertices, GL_DYNAMIC_DRAW);
    //wfVertices now exist on the GPU so we can free it up
    //free(wfVertices);
    //wfVertices = NULL;
    //create the pixelBuffer as wee
    glGenBuffers(1, &wfPixelBuffer);
    wfDataloaded = YES;
    
    
    
}

static void wfModifyColors(GLfloat *color_data,GLfloat *gcolor)
{
    int i;
    for(i=0;i<nWfVertices;i++)
    {
        color_data[3*i] = gcolor[0];//use_colors[3*cids[i+1]];
        color_data[3*i+1] = gcolor[1];//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = gcolor[2];//use_colors[3*cids[i+1]+2];
    }
	//change mean color
	unsigned int offset = 0;
	for(i=0;i<wavesize;i++)
	{
		offset = 3*(nWfVertices-wavesize+i);
		color_data[offset] = 1.0-0.5*gcolor[0];
		color_data[offset+1] = 1.0-0.5*gcolor[1];
		color_data[offset+2] = 1.0-0.5*gcolor[2];
	}
}

-(void) highlightChannels:(NSArray*)channels
{
	[[self openGLContext] makeCurrentContext];
}

-(void) highlightWaveforms:(NSData*)wfidx
{
	//TODO: This does not work after waveforms are removed
	//check if highlightWaves have changed
	if([wfidx isEqual:highlightWaves] )
	{
		return;
	}
    [[self openGLContext] makeCurrentContext];
    unsigned int* _points = (unsigned int*)[wfidx bytes];
	
    unsigned int _npoints = [wfidx length]/sizeof(unsigned int);
    
    GLfloat zvalue;
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    GLfloat *_data = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    unsigned int idx,i;
    unsigned int* _hpoints;
    unsigned int _nhpoints;
	NSUInteger* _indexes = malloc(num_spikes*sizeof(NSUInteger));
	[waveformIndices getIndexes:_indexes maxCount:num_spikes inIndexRange:nil];
    if( highlightWaves != NULL )
    {
        _hpoints = (unsigned int*)[highlightWaves bytes];
        _nhpoints = [highlightWaves length]/sizeof(unsigned int);
        for(i=0;i<_nhpoints;i++)
        {
            //need to reset z-value of previously highlighted waveform
            //idx = _hpoints[i];
            idx = _indexes[_hpoints[i]];
			zvalue = -1.0;
            vDSP_vfill(&zvalue,_data+(idx*timepts*chs*3)+2,3,timepts*chs);
        }
		//alternative way of doing this, since we have an index set
		
    }
    zvalue = 1.1;
    //set the z-value
    for(i=0;i<_npoints;i++)
    {
        //idx = _points[i];
		idx = _indexes[_points[i]];
		//check that the point is valid
		if( idx < num_spikes )
		{
			vDSP_vfill(&zvalue,_data+(idx*timepts*chs*3)+2,3,timepts*chs);
		}
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    GLfloat *_colors = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    GLfloat *dcolor = (float*)[drawingColor bytes];
    if( highlightWaves != NULL )
    {
        //unsigned int* _hpoints = (unsigned int*)[NSData bytes];
        //unsigned int _nhpoints = [wfidx length]/sizeof(unsigned int);
        for(i=0;i<_nhpoints;i++)
        {
            //idx = _hpoints[i];
            idx = _indexes[_hpoints[i]];
			vDSP_vfill(dcolor,_colors+(idx*wavesize*3),3,wavesize);
            vDSP_vfill(dcolor+1,_colors+(idx*wavesize*3)+1,3,wavesize);
            vDSP_vfill(dcolor+2,_colors+(idx*wavesize*3)+2,3,wavesize);
        }
        
    }
    //find the complement
    GLfloat *hcolor = malloc(4*sizeof(GLfloat));
    hcolor[0] = 1.0-dcolor[0];
    hcolor[1] = 1.0-dcolor[1];
    hcolor[2] = 1.0-dcolor[2];
    for(i=0;i<_npoints;i++)
    {
        //idx = _points[i];
		idx = _indexes[_points[i]];
		if (idx < num_spikes )
		{
			vDSP_vfill(hcolor,_colors+(idx*wavesize*3),3,wavesize);
			vDSP_vfill(hcolor+1,_colors+(idx*wavesize*3)+1,3,wavesize);
			vDSP_vfill(hcolor+2,_colors+(idx*wavesize*3)+2,3,wavesize);
		}
    }
    if(highlightWaves != NULL)
    {
        [[self highlightWaves] setData: wfidx];
    }
    else 
    {
        [self setHighlightWaves:[NSMutableData dataWithData:wfidx]];
    }

    free(hcolor);
	free(_indexes);
    glUnmapBuffer(GL_ARRAY_BUFFER);
    [self setNeedsDisplay:YES];
    
}

-(void) highlightWaveform:(NSUInteger)wfidx
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
    //GLfloat zvalue = -(float)num_spikes-10.0;//+0.2*(float)num_spikes;
    GLfloat zvalue;
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    GLfloat *_data = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    if( highlightWave >= 0 )
    {
        //need to reset z-value of previously highlighted waveform
        zvalue = -1.0;
        vDSP_vfill(&zvalue,_data+(highlightWave*wavesize*3)+2,3,wavesize);
    }
    zvalue = 1.1;
    //set the z-value
    vDSP_vfill(&zvalue,_data+(wfidx*wavesize*3)+2,3,wavesize);
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    GLfloat *_colors = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    GLfloat *dcolor = (float*)[drawingColor bytes];
    if( highlightWave >= 0 )
    {
        
        vDSP_vfill(dcolor,_colors+(highlightWave*wavesize*3),3,wavesize);
        vDSP_vfill(dcolor+1,_colors+(highlightWave*wavesize*3)+1,3,wavesize);
        vDSP_vfill(dcolor+2,_colors+(highlightWave*wavesize*3)+2,3,wavesize);
        
    }
    //find the complement
    GLfloat *hcolor = malloc(4*sizeof(GLfloat));
    hcolor[0] = 1.0-dcolor[0];
    hcolor[1] = 1.0-dcolor[1];
    hcolor[2] = 1.0-dcolor[2];
    vDSP_vfill(hcolor,_colors+(wfidx*wavesize*3),3,wavesize);
    vDSP_vfill(hcolor+1,_colors+(wfidx*wavesize*3)+1,3,wavesize);
    vDSP_vfill(hcolor+2,_colors+(wfidx*wavesize*3)+2,3,wavesize);
    free(hcolor);
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    highlightWave = wfidx;
    [self setNeedsDisplay:YES];
}

static void wfDrawAnObject()
{
    //activate the dynamicbuffer
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    glEnableClientState(GL_VERTEX_ARRAY);
    //bind the vertexbuffer
    
     //activate vertex point; 3 points per vertex, each point of type GL_FLOAT, stride of 0 (i.e. tightly pakced), and use existing
    //vetex data, i.e. wfVertexBuffer activated above.
    glVertexPointer(3, GL_FLOAT, 0, (void*)0);
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    glEnableClientState(GL_COLOR_ARRAY);
    glColorPointer(3, GL_FLOAT, 0, (void*)0);
    //bind the indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, wfIndexBuffer);
    glIndexPointer(GL_UNSIGNED_INT, 0, (void*)0);
    glEnableClientState(GL_INDEX_ARRAY);
    //Draw nWfIndices elements of type GL_LINES, use the loaded wfIndexBuffer
    //the second argument to glDrawElements should be the number of objects to draw
    //i.e. number of lines below. Since nWfIndices is the total number of points, and each line 
    //uses two points, the total number of lines to draw is ndincies/2
    //this fails and I have no idea why. Indexing wfVertices using indices on its own does not cause any issues.
    //Thus,this has to be related to openGL.
    glDrawElements(GL_LINES, /*MIN(31*4*40000,nWfIndices)*/nWfIndices,GL_UNSIGNED_INT,(void*)0);
    //glDrawRangeElement
}

-(void)drawLabels
{
    //TODO: This does not work; the labels are stretched, and drawn in black, not whte as the color suggests.
    int nlabels = 10;
    int i;
    //NSAttributedString *label;
    NSMutableDictionary *normal9Attribs = [NSMutableDictionary dictionary];
    [normal9Attribs setObject: [NSFont fontWithName: @"Helvetica" size: 9.0f] forKey: NSFontAttributeName];
    //label = [[[NSMutableAttributedString alloc] initWithString:@"GL Capabilities:" attributes:bold12Attribs] autorelease];
    float width = [self bounds].size.width;
    float height =[self bounds].size.height;
    float xmargin = 0.005*width;
    float ymargin = 0.01*height;
    float dy = 0.8*height/nlabels;
    float y = [self bounds].origin.y;
    for(i=0;i<nlabels;i++)
    {
        y = ymargin + i*dy;
        NSAttributedString *label;
        label = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%.1f",&y]  attributes:normal9Attribs] autorelease];
        GLString *glabel;
        glabel = [[GLString alloc] initWithAttributedString:label withTextColor:[NSColor colorWithDeviceRed:0.5f green:0.5f blue:0.56f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:0.4f green:0.4f blue:0.0f alpha:0.0f] withBorderColor:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:0.0f alpha:0.0f]];
        [glabel drawAtPoint:NSMakePoint (xmargin, y)];
        
    }

}

- (void)drawRect:(NSRect)bounds 
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
	
	//glLoadIdentity();
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);

    glClearColor(0,0,0,0);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	//glLoadIdentity();
    //glClear(GL_DEPTH_BUFFER_BIT);
    if(wfDataloaded)
    {
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		/*glOrtho(1.05*xmin-0.05*xmax, 1.05*xmin-0.05*xmax, 1.05*wfMinmax[2]-0.05*wfMinmax[3], 
				1.05*wfMinmax[3]-0.05*wfMinmax[2], wfMinmax[4], wfMinmax[5]);*/
        glOrtho(xmin, xmax, 1.1*ymin, 1.1*ymax, 1.1*wfMinmax[4], 1.1*wfMinmax[5]);
		wfDrawAnObject();
		//glPushMatrix();
		//glScalef(1.0/(xmax-xmin),1.0/(ymax-ymin),1.0);
		//[self drawLabels];
		//glPopMatrix();
		
                //drawFrame();
    }
    glFlush();
    [context flushBuffer];}

- (void) reshape
{
 //reshape the view
    NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //[self display];
	//[self setNeedsDisplay:YES];    
    
}


- (void) prepareOpenGL
{
    //prepare openGL context
    //wfDataloaded = NO;
    NSOpenGLContext *context = [self openGLContext];
    NSRect bounds = [self bounds];
    [context makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    glLineWidth(1.33);
    glClearColor(0,0, 0, 0);
    glClearDepth(1.0);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
  
    //glShadeModel(GL_SMOOTH);
    //glPointSize(4.0);
    glEnable(GL_BLEND);
    //glEnable(GL_POINT_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_DST_ALPHA);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    [context flushBuffer];
           
}

-(void)setColor:(NSData*)color
{
    drawingColor = [[NSData dataWithData:color] retain];
    //float *_color = malloc(3*sizeof(float));
    float *_color = (float*)[color bytes];
    //[color getBytes:_color];
    //compute HSV
    CGFloat hue,sat,val,alpha,mi,mx;
    NSColor *tmp_color = [NSColor colorWithDeviceRed:_color[0] green:_color[1] blue:_color[2] alpha:1.0];
    [tmp_color getHue:&hue saturation:&sat brightness:&val alpha:&alpha];
    /*
    vDSP_maxv(_color, 1,&val, 3);
    _color[0]/=val;
    _color[1]/=val;
    _color[2]/=val;
    vDSP_maxv(_color, 1,&mx, 3);
    vDSP_minv(_color, 1,&mi, 3);
    sat = mx-mi;
    //scale again
    _color[0] = (_color[0]-mi)/sat;
    _color[1] = (_color[1]-mi)/sat;
    _color[2] = (_color[2]-mi)/sat;
    unsigned int mxi;
    vDSP_maxvi(_color, 1, &mx, &mxi, 3);
    if(mxi==0)
    {
        hue = 0.0 + 60.0*(_color[1]-_color[2]);
    }
    else if (mxi==1)
    {
        hue = 120.0 + 60.0*(_color[2]-_color[0]);
    }
    else {
        hue = 240.0 + 60.0*(_color[0]-color[1]);
    }
     */
    //[color getHue:&hue saturation:&sat brightness:&bri alpha:&alpha];
    //get complementary color by mirroring
    hue = hue+0.5;
    if( hue > 1.0)
    {
        hue = hue-1.0;
    }
    tmp_color = [NSColor colorWithCalibratedHue:hue saturation:sat brightness:val alpha:alpha];
    [tmp_color getRed:&hue green:&sat blue:&val alpha:&alpha];
    float *tmp = malloc(4*sizeof(float));
    tmp[0] = (float)hue;
    tmp[1] = (float)sat;
    tmp[2] = (float)val;
    tmp[3] = (float)alpha;
    highlightColor = [[NSData dataWithBytes:tmp length: 4*sizeof(float)] retain];
    free(tmp);
    
}

-(void)showOnlyHighlighted
{
	if( [self highlightWaves] != NULL )
	{
		unsigned int *_hpoints = (unsigned int*)[[self highlightWaves] bytes];
		unsigned int _nhpoints = ([[self highlightWaves] length])/sizeof(unsigned int);
		//create an index with all the other waveforms
		NSIndexSet *hide = [waveformIndices indexesPassingTest:^(NSUInteger idx, BOOL *stop) 
		{
			BOOL found = YES;
			int j = 0;
			while( (found == YES ) && (j < _nhpoints) )
			{
				if(idx==_hpoints[j] )
				{
					found = NO;
				}
			}
			return found;
		}];
	
		unsigned int* _points = malloc(([hide count])*sizeof(unsigned int));
		[hide getIndexes: _points maxCount: [hide count] inIndexRange: nil];
		[self hideWaveforms:[NSData dataWithBytes:_points length:[hide count]]];
		free(_points);
	}
}

-(void) hideWaveforms:(NSData*)wfidx
{
    [[self openGLContext] makeCurrentContext];
    unsigned int* _points = (unsigned int*)[wfidx bytes];
    unsigned int _npoints = [wfidx length]/sizeof(unsigned int);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,wfIndexBuffer);
    GLuint *tmp_idx = (GLuint*)glMapBuffer(GL_ELEMENT_ARRAY_BUFFER, GL_READ_ONLY);
	//array to hold the new indices
	GLuint* new_idx = malloc((num_spikes-_npoints+1)*waveIndexSize*sizeof(GLuint));

    int i,j,found,k,l;
    j = 0;
    found = 0;
    k = 0;
    //unsigned int wvsize =
	//remove from active waveforms
	for(i=0;i<_npoints;i++)
	{
		[waveformIndices removeIndex:_points[i]];
	}
	//the code below is a bit pointless; we know that wfidx are all from the currently drawn waves
	
    for(i=0;i<num_spikes;i++)
    {
        found = 0;
        j=0;
        while((found==0) && (j<_npoints))
        {
            if(i==_points[j])
			{
                found = 1;
			}
            //found=(i==_points[j]);
            j+=1;
        }
        if(found == 0)
        {
            //need to remove the waveform;rearrange both indices and vertixes
			//we are removing points from the cluster, i.e. this will not work
			//is there a concern here that we are over-writing points
			//we are shifting indices around, which means that the index i is no longer valid after the first shift
            for(l=0;l<waveIndexSize;l++)
            {
                new_idx[k*waveIndexSize+l] = tmp_idx[i*waveIndexSize+l];
            }
			//also, be careful about the mean waveform here
			/*
            for(l=0;l<wavesize;l++)
            {
                wfVertices[3*(k*wavesize+l)] = wfVertices[3*(i*wavesize+l)];
                wfVertices[3*(k*wavesize+l)+1] = wfVertices[3*(i*wavesize+l)+1];
                wfVertices[3*(k*wavesize+l)+2] = wfVertices[3*(i*wavesize+l)+2];
            }
			 */
            k+=1;
        }
    }
	//alternative code
	//remove wfidx from tmp_idx
	//to remove points, shift all points down by one
	
	
	//
	//we have now gotten rid of the extra waveforms; need to shift the mean waveform into place
	k = num_spikes-_npoints;
	/*
	for(l=0;l<wavesize;l++)
	{
		wfVertices[3*(k*wavesize+l)] = wfVertices[3*(num_spikes*wavesize+l)];
		wfVertices[3*(k*wavesize+l)+1] = wfVertices[3*(num_spikes*wavesize+l)+1];
		wfVertices[3*(k*wavesize+l)+2] = wfVertices[3*(num_spikes*wavesize+l)+2];
	}*/
	//reset mean waveform index
	for(l=0;l<waveIndexSize;l++)
	{
		new_idx[k*waveIndexSize+l] = tmp_idx[num_spikes*waveIndexSize+l];
	}
    glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
    num_spikes-=_npoints;
    if(num_spikes<0)
        num_spikes=0;
    
    /*
	nWfVertices-=_npoints*wavesize;
    if(nWfVertices<0)
        nWfVertices=0;
    */
    nWfIndices-=_npoints*waveIndexSize;
    
    if(nWfIndices<0)
        nWfIndices = 0;
    //push the indices again
    //glGenBuffers(1,&wfVertexBuffer);
    //glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nWfIndices*sizeof(GLuint), new_idx, GL_DYNAMIC_DRAW);
    
    [self setNeedsDisplay: YES];
    
}

-(NSData*)getColor
{
    return drawingColor;
}

-(NSData*)getHighlightColor
{
    return highlightColor;
}

-(void) receiveNotification:(NSNotification*)notification
{
    if([[notification name] isEqualToString:@"highlight"])
    {
        [self highlightWaveforms:[[notification userInfo] objectForKey:@"points"]];
    }
}
    
//event handlers
/*-(void)mouseDown:(NSEvent*)theEvent
//{
//	NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    //now we will have to figure out which waveform(s) contains this point
    //scale to data coorindates
    NSPoint dataPoint;
    NSRect viewBounds = [self bounds];
    //scale to data coordinates
    dataPoint.x = (currentPoint.x*1.1*(wfMinmax[1]-wfMinmax[0]))/viewBounds.size.width+1.1*wfMinmax[0];
    dataPoint.y = (currentPoint.y*1.1*(wfMinmax[3]-wfMinmax[2]))/viewBounds.size.height+1.1*wfMinmax[2];
	
	//get the channel corresponding to the point
	NSNumber *channel = [NSNumber numberWithUnsignedInt:dataPoint.x/(channelHop+timepts)];
	[highlightedChannels addObject: channel];
}*/
/*
-(void)keyUp:(NSEvent *)theEvent
{
	//check if control key was released (hopefully...)
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	if ([ theEvent modifierFlags] & NSControlKeyMask )
	{
		unsigned int minChannel = [[highlightedChannels objectAtIndex:0] unsignedIntValue];
		unsigned int maxChannel = [[highlightedChannels lastObject] unsignedIntValue];
		xmin = (GLfloat)(minChannel*(timepts+channelHop));
		xmax = (GLfloat)(maxChannel*(timepts+channelHop));
	}
	else if ([formatter numberFromString: [theEvent characters]] != nil )	
	{
		NSString *wf = [theEvent characters];
		//send off a notification indicating that we should show the waveform picker panel
		NSDictionary *params  = [NSDictionary dictionaryWithObjectsAndKeys:wf,@"selected",nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:params];
	}
	[formatter release];

}
 */
-(void)mouseUp:(NSEvent *)theEvent
{
	//TODO: modify this to incorproate the new index
    //get current point in view coordinates
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    //now we will have to figure out which waveform(s) contains this point
    //scale to data coorindates
    NSPoint dataPoint;
    NSRect viewBounds = [self bounds];
    //scale to data coordinates
    dataPoint.x = (currentPoint.x*(xmax-xmin))/viewBounds.size.width+xmin;
    dataPoint.y = (currentPoint.y*(1.1*ymax-1.1*ymin))/viewBounds.size.height+1.1*ymin;
    //here, we can simply figure out the smallest distance between the vector defined by
    //(dataPoint.x,dataPoint.y) and the waveforms vectors
    
    
    float *p = malloc(2*sizeof(float));
    int wfLength = wavesize;
    vDSP_Length imin;
    float fmin;
    p[0] = -dataPoint.x;
    p[1] = -dataPoint.y;
    //if we have pressed the option key, only the currently highlighted waveforms are
    //eligible for selection
    unsigned int wfidx;
    if( ([theEvent modifierFlags] & NSAlternateKeyMask) && ([self highlightWaves] != NULL) )
    {
        float *d = malloc(wfLength*sizeof(float));
        float *D = malloc(2*wfLength*sizeof(float));
        unsigned int *sIdx = (unsigned int*)[[self highlightWaves] bytes];
        unsigned int n = [[self highlightWaves] length]/sizeof(unsigned int);
        //use a for loop for now
        unsigned int i,s;
        float d_o;
        d_o = INFINITY;
        for(i=0;i<n;i++)
        {
            vDSP_vsadd(wfVertices+3*sIdx[i]*wfLength,3,p,D,2,wfLength);
            vDSP_vsadd(wfVertices+3*sIdx[i]*wfLength+1,3,p+1,D+1,2,wfLength);
            //sum of squares
            vDSP_vdist(D,2,D+1,2,d,1,wfLength);
            //find the index of the minimu distance
            vDSP_minvi(d,1,&fmin,&imin,wfLength);
            if(fmin<d_o)
            {
                d_o = fmin;
                s = i;
            }
        }
        free(d);
        free(D);
        wfidx = sIdx[s];
    }
	else if ([ theEvent modifierFlags] & NSControlKeyMask )
	{
		//control was pressed; highlight channels
		if( highlightedChannels == NULL )
		{
			highlightedChannels = [[NSMutableArray arrayWithCapacity:10] retain];
		}
		[highlightedChannels addObject:[NSNumber numberWithFloat:(dataPoint.x-xmin)/(channelHop+timepts)]];
		/*unsigned int minChannel = [[highlightedChannels objectAtIndex:0] unsignedIntValue];
		unsigned int maxChannel = [[highlightedChannels objectAtIndex:0] unsignedIntValue];
		xmin = (GLfloat)(minChannel*(timepts+channelHop));
		xmax = (GLfloat)(maxChannel*(timepts+channelHop));*/
		return;

	}
    else 
    {
        //get only the relevant vertices
		//need to restrict ourselves to those vertices which are actually drawn
		NSUInteger *_indexes = malloc(num_spikes*sizeof(NSUInteger));
		//copy the indexes
		[waveformIndices getIndexes:_indexes maxCount:num_spikes inIndexRange:nil];
        float *d = malloc(nWfVertices*sizeof(float));
        float *D = malloc(2*nWfVertices*sizeof(float));
        //substract the point
        vDSP_vsadd(wfVertices,3,p,D,2,nWfVertices);
        vDSP_vsadd(wfVertices+1,3,p+1,D+1,2,nWfVertices);
        //sum of squares
        vDSP_vdist(D,2,D+1,2,d,1,nWfVertices);
        //find the index of the minimu distance
        //vDSP_minvi(d,1,&fmin,&imin,nWfVertices);
        int i;
		fmin = INFINITY;
		for(i=0;i<num_spikes;i++)
		{
			if (d[_indexes[i]] < fmin) {
				fmin = d[_indexes[i]];
				imin = i;
			}
		}
		//imin now holds the index of the vertex closest to the point
        //find the number of wfVertices per waveform
        
        free(d);
        free(D);
        wfidx = imin/(wfLength);
    }
    free(p);
    //if command key is pressed, we want to add this wavform to the currently drawn waveforms
    NSMutableData *hdata;
    if([theEvent modifierFlags] & NSCommandKeyMask)
    {
        hdata = [NSMutableData dataWithData:[self highlightWaves]];
    }
    else
    {
        hdata = [NSMutableData dataWithCapacity:sizeof(unsigned int)];
    }
    [hdata appendBytes:&wfidx length:sizeof(unsigned int)];
    /*NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects: 
                                                                                                                      @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:params];*/
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects: 
                                                                                                                      @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object: self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
																								   [NSNumber numberWithUnsignedInt:idx[0]],
																								   @"selected",nil]];
	
    //[self highlightWaveform:wfidx];
    
}

/*-(void)removePoints:(NSIndexSet*)points
{
    //moves the points in indexset from the currently drawn points to the 0-zero cluster
    
}*/

-(void) createAxis
{
    //creates an axis 
    NSRect bounds = [self bounds];
    //create a bitmap to hold the axis object
    NSBitmapImageRep *axis = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:bounds.size.width 
                                                                     pixelsHigh:bounds.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO 
                                                                 colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    
    //create context
    NSGraphicsContext *cg_context = [NSGraphicsContext graphicsContextWithBitmapImageRep:axis];
    NSDictionary *attribs = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: [NSColor whiteColor],nil]
                                                        forKeys: [NSArray arrayWithObjects: NSForegroundColorAttributeName,nil]];  
                              
    [NSGraphicsContext setCurrentContext:cg_context];
    //Need to implement a loop over the axis labels here
    NSString *str = @"hello";
    NSPoint point;
    //make sure we are drawing into the bitmap context 
    
    [str drawAtPoint:point withAttributes:attribs];
    //
    //now create a texture
    //set current context to the openGL context
    GLuint texName;
    texName = 0;
    [[self openGLContext] makeCurrentContext];
    glPixelStorei(GL_UNPACK_ROW_LENGTH, [axis pixelsWide]);
    glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
    if (texName == 0) // 6
        glGenTextures (1, &texName);
    glBindTexture (GL_TEXTURE_RECTANGLE_ARB, texName);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
                    GL_TEXTURE_MIN_FILTER, GL_LINEAR); 
     int samplesPerPixel = [axis samplesPerPixel]; 
    if(![axis isPlanar] &&
       (samplesPerPixel == 3 || samplesPerPixel == 4)) { // 10
        glTexImage2D(GL_TEXTURE_RECTANGLE_ARB,
                     0,
                     samplesPerPixel == 4 ? GL_RGBA8 : GL_RGB8,
                     [axis pixelsWide],
                     [axis pixelsHigh],
                     0,
                     samplesPerPixel == 4 ? GL_RGBA : GL_RGB,
                     GL_UNSIGNED_BYTE,
                     [axis bitmapData]);
    } else {
    }
    [axis release];
    
}

-(void)saveToEPS
{
    NSRect bounds = [self bounds];
    //allocate an image and intialize with the size of the view
    NSImage *image = [[NSImage alloc] initWithSize: bounds.size];
    //add an EPS representation
    NSEPSImageRep *imageRep = [[NSEPSImageRep alloc] init];
    [image addRepresentation: imageRep];
    
    [image lockFocus];
    
    //drawing

    int i,j,k,offset;
    int timepoints = timepts;
    int channels = chs;
    NSPointArray points = malloc(timepoints*sizeof(NSPoint));
    for(i=0;i<num_spikes;i++)
    {
        for(j=0;j<channels;j++)
        {
        //draw 
            NSBezierPath *path = [NSBezierPath bezierPath];
            
            for(k=0;k<timepoints;k++)
            {
                offset = 3*(i*wavesize+j*channels+k);
                points[k] = NSMakePoint(wfVertices[offset],wfVertices[offset+1]);
            }
            [path appendBezierPathWithPoints:points count:timepoints];
            [path stroke];
        }
    }
    free(points);
    
    [image unlockFocus];
     //get the data
    NSData *imageData = [imageRep EPSRepresentation];
    [imageData writeToFile:@"test.eps" atomically:YES];
    
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

//Indicate what kind of drag-operation we are going to support
-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)localDestination
{
	return NSDragOperationMove;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    } else {
		//TODO: this should be made more general, i.e. I don't want to have to rely on arcane key combinations
		if( [[theEvent characters] isEqualToString: @"z"] )
		{
			//[self highlightChannels: highlightedChannels]
			float minChannel = [[highlightedChannels objectAtIndex:0] floatValue];
			float maxChannel = [[highlightedChannels lastObject] floatValue];
			if (minChannel<maxChannel)
			{
				xmin = (GLfloat)(((int)minChannel)*(timepts+channelHop));
				xmax = (GLfloat)(((int)(maxChannel+1))*(timepts+channelHop));
				//compute the maximum
				vDSP_minv(chMinMax+2*(int)minChannel, 2, &ymin, (int)(maxChannel-minChannel));
				vDSP_maxv(chMinMax+2*(int)minChannel+1, 2, &ymax, (int)(maxChannel-minChannel));

				[self setNeedsDisplay:YES];
			}
			//TODO: I should make sure the channels are contiguous
			NSMutableArray *_channels = [NSMutableArray arrayWithCapacity:maxChannel-minChannel];
			int c;
			for(c=(int)minChannel;c<=(int)maxChannel;c++)
			{
				[_channels addObject:[NSNumber numberWithInt:c]];
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setFeatures" object:self userInfo: 
			 [NSDictionary dictionaryWithObjectsAndKeys: _channels, @"channels",nil]];
			[highlightedChannels removeAllObjects];
		}
		else if ( [[theEvent characters] isEqualToString:@"b"] )
		{
			//indicate we want to restore zoom
			xmin = wfMinmax[0];
			xmax = wfMinmax[1];
			ymin = wfMinmax[2];
			ymax = wfMinmax[3];
			//restore feature dimensions
			int i;
			NSMutableArray *channels = [NSMutableArray arrayWithCapacity:chs];
			for(i=0;i<chs;i++)
			{
				[channels addObject:[NSNumber numberWithInt:i]];
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:@"setFeatures" object:self userInfo: 
			 [NSDictionary dictionaryWithObjectsAndKeys:channels, @"channels",nil]];
			[self setNeedsDisplay:YES];
		}
		//TODO: this should be changed; just a test for now
		else if ( [[theEvent characters] isEqualToString:@"k"] )
		{
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSData dataWithBytesNoCopy:wfVertices length:3*num_spikes*wavesize*sizeof(GLfloat)],
									  @"data",[NSNumber numberWithUnsignedInt:chs],@"channels",
									  [NSNumber numberWithUnsignedInt:timepts],@"timepoints",nil];
			//post notification
			[[NSNotificationCenter defaultCenter] postNotificationName:@"computeSpikeWidth" object: self userInfo:userInfo];
		}
		else if ([ theEvent modifierFlags] & NSControlKeyMask )
		{
			unsigned int minChannel = [[highlightedChannels objectAtIndex:0] unsignedIntValue];
			unsigned int maxChannel = [[highlightedChannels lastObject] unsignedIntValue];
			xmin = (GLfloat)(minChannel*(timepts+channelHop));
			xmax = (GLfloat)(maxChannel*(timepts+channelHop));
		}
		else if ([formatter numberFromString: [theEvent characters]] != nil )	
		{
			NSString *wf = [theEvent characters];
			//send off a notification indicating that we should show the waveform picker panel
			NSDictionary *params  = [NSDictionary dictionaryWithObjectsAndKeys:wf,@"selected",nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:params];
		}
		
		else {
			[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
		}

        //[self keyDown:theEvent];
    }
	[formatter release];
}

-(void) deleteBackward:(id)sender
{
	//meant for deleting waveforms
	//alert the application that we want to remove a waveform
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Remove waveforms" forKey:@"option"];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"performClusterOption" object:self userInfo: userInfo];
}
//TODO: this is a bit experimental
-(void)scrollWheel:(NSEvent *)theEvent
{
	//set a threshold for when we accept a scroll
	if([theEvent deltaX] > 1 )
	{
		[self moveRight:self];
	}
	else if ( [theEvent deltaX] < -1 )
	{
		[self moveLeft:self];
	}
}

-(IBAction)moveRight:(id)sender
{
	//shift highlighted waveform downwards
	NSMutableData *hdata;

	if( [self highlightWaves] != NULL )
	{
		hdata = [NSMutableData dataWithData:[self highlightWaves]];		
		//get the indices and increment by one
		unsigned int *idx = (unsigned int*)([hdata bytes]);
		unsigned int len = [hdata length]/sizeof(unsigned int);
		int i;
		for(i=0;i<len;i++)
		{
			if( idx[i] > 0 )
			{
				idx[i]--;
			}
		}
	}
	else
	{
		//no highlighted waves, so set highlight to the first wave
		unsigned int idx = 0;
		hdata = [NSMutableData dataWithBytes:&idx length:sizeof(unsigned int)];

	}
	//create and send the notification
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects: 
                                                                                                                      @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object: self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
																								   [NSNumber numberWithUnsignedInt:idx[0]],
																								   @"selected",nil]];
}

-(IBAction)moveLeft:(id)sender
{
	//shift highlighted waveform downwards
	NSMutableData *hdata;
	
	if( [self highlightWaves] != NULL )
	{
		hdata = [NSMutableData dataWithData:[self highlightWaves]];		
		//get the indices and increment by one
		unsigned int *idx = (unsigned int*)([hdata bytes]);
		unsigned int len = [hdata length]/sizeof(unsigned int);
		int i;
		for(i=0;i<len;i++)
		{
			if( idx[i] < num_spikes -1 )
			{
				idx[i]++;
			}
		}
	}
	else
	{
		//no highlighted waves, so set highlight to the first wave
		unsigned int idx = 0;
		hdata = [NSMutableData dataWithBytes:&idx length:sizeof(unsigned int)];
		
	}
	//create and send the notification
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects: 
                                                                                                                      @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
																								   [NSNumber numberWithUnsignedInt:idx[0]],
																								   @"selected",nil]];
}	

-(void)dealloc
{
    free(wfVertices);
    free(wfIndices);
    free(wfMinmax);
    free(wfColors);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [drawingColor release];
    [highlightColor release];
	[waveformIndices release];
    [super dealloc];
}

@end
