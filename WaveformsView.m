//
//  WaveformsView.m
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveformsView.h"

#define MIN(a,b) ((a)>(b)?(b):(a))

@implementation WaveformsView


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
        [[self openGLContext] update];
    }
}



-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints
{
    wavesize = channels*timepoints;
    nWfIndices = nwaves*wavesize;
    nWfVertices = nWfIndices;
    num_spikes = nwaves;
    if(wfDataloaded)
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
    //3 dimensions X 2
    wfMinmax = calloc(6,sizeof(float));
    int channelHop = 10;
    //copy wfVertices
    float dz = (100.0-1.0)/num_spikes;
    for(i=0;i<nwaves;i++)
    {
        for(j=0;j<channels;j++)
        {
            for(k=0;k<timepoints;k++)
            {
                offset = ((i*channels+j)*timepoints + k);
                //x
                //wfVertices[offset] = tmp[offset];
                wfVertices[3*offset] = j*(timepoints+channelHop)+k+channelHop;
                //y
                wfVertices[3*offset+1] = tmp[offset];
                //z
                wfVertices[3*offset+2] = -1.0;//-(1.0+dz*i);//-(i+1);
                
                //calculate wfMinmax
                if (tmp[offset] < wfMinmax[2] )
                {
                    wfMinmax[2] = tmp[offset];
                }
                if (tmp[offset] > wfMinmax[3] )
                {
                    wfMinmax[3] = tmp[offset];
                }
                
                
            }
            
        }
    }
    wfMinmax[0] = 0;
    wfMinmax[1] = channels*(timepoints+channelHop);
    wfMinmax[4] = -1.0;//0.1;
    wfMinmax[5] = 1.0;//100;//nwaves+2;
    //create indices
    
    //here we have to be a bit clever; if we want to draw as lines, every vertex will be connected
    //However, since we are drawing waveforms across channels, we need to separate waveforms on each
    //channel. We do this by modifying the indices. We will use GL_LINE_STRIP, which will connect every other index
    //i.e. 1-2, 3-4,5-6,etc..
    //for this we need to know how many channels, as well as how many points per channel
    //each channel will have 2*pointsPerChannel-2 points
    unsigned int pointsPerChannel = 2*timepoints-2;
    //unsigned int offset = 0;
    nWfIndices = nwaves*channels*pointsPerChannel;
    if(wfDataloaded)
    {
        wfIndices = realloc(wfIndices, nWfIndices*sizeof(GLuint));

    }
    else {
        wfIndices = malloc(nWfIndices*sizeof(GLuint));

    }

    for(i=0;i<nwaves;i++)
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
    wfModifyColors(wfColors);
    //push everything to the GPU
    wfPushVertices();
    //draw
    //[self highlightWaveform:0];
    
    [self setNeedsDisplay: YES];
    
}

static void wfPushVertices()
{
    //set up index buffer
    //int k = 0;
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(1.1*wfMinmax[0], 1.1*wfMinmax[1], 1.1*wfMinmax[2], 1.1*wfMinmax[3], 1.1*wfMinmax[4], 1.1*wfMinmax[5]);
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
    wfDataloaded = YES;
    
    
    
}

static void wfModifyColors(GLfloat *color_data)
{
    int i;
    for(i=0;i<nWfVertices;i++)
    {
        color_data[3*i] = 1.0f;//use_colors[3*cids[i+1]];
        color_data[3*i+1] = 0.85f;//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = 0.35f;//use_colors[3*cids[i+1]+2];
    }
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
        vDSP_vfill(&zvalue,_data+(highlightWave*32*4*3)+2,3,32*4);
    }
    zvalue = 1.1;
    //set the z-value
    vDSP_vfill(&zvalue,_data+(wfidx*32*4*3)+2,3,32*4);
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    GLfloat *_colors = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    
    if( highlightWave >= 0 )
    {
        
        GLfloat pcolor[3] = {1.0,0.85,0.35};
        vDSP_vfill(pcolor,_colors+(highlightWave*32*4*3),3,32*4);
        vDSP_vfill(pcolor+1,_colors+(highlightWave*32*4*3)+1,3,32*4);
        vDSP_vfill(pcolor+2,_colors+(highlightWave*32*4*3)+2,3,32*4);
        
    }
     GLfloat hcolor[3] = {1.0,0.0,0.0};
    vDSP_vfill(hcolor,_colors+(wfidx*32*4*3),3,32*4);
    vDSP_vfill(hcolor+1,_colors+(wfidx*32*4*3)+1,3,32*4);
    vDSP_vfill(hcolor+2,_colors+(wfidx*32*4*3)+2,3,32*4);
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    /*
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, wfIndexBuffer);
    GLuint *index = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    //float *_index = malloc((32*2-2)*4*sizeof(float));
    //float a = wfidx*((32*2-2)*4);
    //float b = 1.0;
    //vDSP_vramp(&a, &b, _index, 1, (32*2-2)*4);
    //vDSP_vfixu32(_index, 1, index+(32*2-2)*4*wfidx, 1, (32*2-2)*4);
    int i,L;
    L = (32*2-2)*4;
    unsigned int k;
    for(i=0;i<L;i++)
    {
        k = index[i];
        index[i] = index[L*wfidx+i];
        index[L*wfidx+i] = k;
    }
    //free(_index);
    glUnmapBuffer(GL_ARRAY_BUFFER);*/
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



- (void)drawRect:(NSRect)bounds 
{
    NSOpenGLContext *context = [self openGLContext];
    [context makeCurrentContext];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);

    glClearColor(0,0,0,0);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    //glClear(GL_DEPTH_BUFFER_BIT);
    if(wfDataloaded)
    {
        wfDrawAnObject();
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
    [self setNeedsDisplay:YES];    
    
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

//event handlers
-(void)mouseUp:(NSEvent *)theEvent
{
    //get current point in view coordinates
    NSPoint currentPoint = [self convertPoint: [theEvent locationInWindow] fromView:nil];
    //now we will have to figure out which waveform(s) contains this point
    //scale to data coorindates
    NSPoint dataPoint;
    NSRect viewBounds = [self bounds];
    //scale to data coordinates
    dataPoint.x = (currentPoint.x*1.1*(wfMinmax[1]-wfMinmax[0]))/viewBounds.size.width+1.1*wfMinmax[0];
    dataPoint.y = (currentPoint.y*1.1*(wfMinmax[3]-wfMinmax[2]))/viewBounds.size.height+1.1*wfMinmax[2];
    //here, we can simply figure out the smallest distance between the vector defined by
    //(dataPoint.x,dataPoint.y) and the waveforms vectors
    float *D = malloc(2*nWfVertices*sizeof(float));
    float *d = malloc(nWfVertices*sizeof(float));
    float *p = malloc(2*sizeof(float));
    vDSP_Length imin;
    float fmin;
    p[0] = -dataPoint.x;
    p[1] = -dataPoint.y;
    //substract the point
    vDSP_vsadd(wfVertices,3,p,D,2,nWfVertices);
    vDSP_vsadd(wfVertices+1,3,p+1,D+1,2,nWfVertices);
    //sum of squares
    vDSP_vdist(D,2,D+1,2,d,1,nWfVertices);
    //find the index of the minimu distance
    vDSP_minvi(d,1,&fmin,&imin,nWfVertices);
    //imin now holds the index of the vertex closest to the point
    //find the number of wfVertices per waveform
    free(p);
    free(d);
    free(D);
    unsigned int wfidx = imin/(32*4);
    [self highlightWaveform:wfidx];
    
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
    [super dealloc];
}

@end
