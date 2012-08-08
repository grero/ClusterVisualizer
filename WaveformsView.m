//
//  WaveformsView.m
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveformsView.h"

#ifndef MIN
#define MIN(a,b) ((a)>(b)?(b):(a))
#endif
#define PI 3.141516

@implementation WaveformsView

@synthesize highlightWaves;
@synthesize highlightedChannels;
@synthesize shouldDrawLabels;//,drawMean,drawStd;
@synthesize overlay;
@synthesize wfMean, wfStd;
@synthesize globalIndices,firstIndex;

-(void)awakeFromNib
{
    wfDataloaded = NO;
    shouldDrawLabels = NO;
    drawMean = YES;
    drawStd = YES;
    //register for defaults updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name: NSUserDefaultsDidChangeNotification object:nil];
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) 
                                                     name:@"highlight" object:nil];
        wfVertexBuffer = 0;
        wfIndexBuffer = 0;
        wfColorBuffer = 0;
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
        [[self openGLContext] update];
        //TODO: Something happens here; somehow the view doesn't get upated properly when the window is resized.
        //[[self openGLContext] flushBuffer];
		
    }
}



-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints andColor: (NSData*)color andOrder: (NSData*)order;
{
    float *_vertices;
    unsigned int prevOffset;
    unsigned int _timepts,_timestep;
    _timepts = timepoints;
    _timestep = 1;
    dispatch_queue_t queue;
    //setup the dispatch queue
    queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    numSpikesAtLeastMean = nwaves;
    //define blocks to handle down-sampled data
    
    void (^warp)(float *input,size_t n, float *output);
    if( nwaves*channels*timepoints > 10000000 )
    {
        _timestep = 4;
        _timepts = _timepts/_timestep;
        
        //average
        
        warp = ^(float *input, size_t n,float *output){
            int i;
            for(i=0;i<n;i++)
            {
                *output+=input[i];
            }
            *output/=n;
        };
        /*
        //peak
        warp = ^(float *input,size_t n, float *output){
            int i;
            float mx,mi;
            mx = -INFINITY;
            mi = INFINITY;
            for(i=0;i<n;i++)
            {
                mx = MAX(mx,output[i]);
                mi = MIN(mi,output[i]);
            }
            output[0] = mi;
            output[1] = mx;
        };*/

    }
    else
    {
        warp = ^(float *input, size_t n, float *output){
            int i;
            memcpy(output, input, n*sizeof(float));
            /*
            for(i=0;i<n;i++)
            {
                output[i] = input[i];
            }
             */
        };
    }
    //add an extra point at the beginning and end of each channel
    wavesize = channels*(_timepts+2);
    waveIndexSize = channels*(2*_timepts-2);
	//+3 to make room for mean waveform and +/- std
    //nWfIndices = nwaves+3;
    /*
    if (drawMean)
        wfIndices+=1;
    if (drawStd)
        wfIndices +=2;
    */
    prevOffset = 0;
    //nWfIndices *= wavesize;
    chs = channels;
    if([self overlay] )
    {
        prevOffset = nWfVertices;
        nWfVertices+=(nwaves+3)*wavesize;
        num_spikes += nwaves;
        orig_num_spikes += nwaves;

    }
    else
    {
        nWfVertices = (nwaves+3)*wavesize;
        //reset min/max only if we are not doing overlay
        wfMinmax = calloc(6,sizeof(float));
        chMinMax = NSZoneCalloc([self zone], 2*chs, sizeof(float));
        num_spikes = nwaves;
        orig_num_spikes = nwaves;
    }   
   
    timepts = _timepts;
	//create an index that will tell us which waveforms are active
    waveformIndices = [[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, num_spikes)] retain];
		//reset highlights
    
    if([self highlightWaves] != NULL)
    {
        [[self highlightWaves] setLength:0];
        [self setHighlightWaves:NULL];
    }
    /*
    if ((wfDataloaded) && (vertices != NULL ) )
    {
        //vertices = [NSData datawi
        _vertices = realloc(wfVertices, nWfVertices*3*sizeof(GLfloat));
    }
    else{
        wfVertices = malloc(nWfVertices*3*sizeof(GLfloat));
        
    }*/
    _vertices = malloc(3*(nWfVertices-prevOffset)*sizeof(GLfloat));
    highlightWave = -1;
    float *tmp = (float*)[vertex_data bytes];
    
    //int i,j,k;
   
    //3 dimensions X 2
    
    channelHop = 10;
	if( order == NULL )
	{
		
		//for(i=0;i<nwaves;i++)
		
		dispatch_apply(nwaves, queue, ^(size_t i){
			int j,k;
            unsigned int in_offset,out_offset = 0;
            //unsigned int moffset = 0;
            //unsigned int stdoffset = 0;
		//{
			for(j=0;j<channels;j++)
			{
                //add the first point
                in_offset = (i*channels+j)*timepoints;
                out_offset = (i*channels+j)*(_timepts+2);//+prevOffset;
                //x
                _vertices[3*out_offset] = j*(_timepts+channelHop) + channelHop;
                //y
                warp(tmp+in_offset,_timestep,_vertices+3*out_offset+1);
                //z; the trick is to make this point invisible, so set it to a low value
                _vertices[3*out_offset+2] = -50.0;
				for(k=0;k<_timepts;k++)
				{
					in_offset = ((i*channels+j)*timepoints + k*_timestep);
                    out_offset = ((i*channels+j)*(_timepts+2) + k+1);//+prevOffset;

					//moffset = ((nwaves*channels+j)*_timepts + k)+prevOffset;
					//stdoffset = (((nwaves+1)*channels+j)*_timepts + k)+prevOffset;

					//x
					_vertices[3*out_offset] = j*(_timepts+channelHop)+k+channelHop;
					//y
					_vertices[3*out_offset+1] = tmp[in_offset];
                    //warp(tmp+in_offset,_timestep,_vertices+3*out_offset+1);
					
                    //z
					_vertices[3*out_offset+2] = -1.0;//-(1.0+dz*i);//-(i+1);
                    //compute max/min per channel
					if ( tmp[in_offset] < chMinMax[2*j] )
					{
						chMinMax[2*j] = tmp[in_offset];
					}
					else if ( tmp[in_offset] > chMinMax[2*j+1] )
					{
						chMinMax[2*j+1] = tmp[in_offset];
					}
				}
                //add the last point
                in_offset = ((i*channels+j)*timepoints+(timepoints-1)*_timestep);
                out_offset = ((i*channels+j)*(_timepts+2) + _timepts+1);//+prevOffset;
                //x
                _vertices[3*out_offset] = j*(_timepts+channelHop)+_timepts-1+channelHop;
                //y
                warp(tmp+in_offset,_timestep,_vertices+3*out_offset+1);
                //z; the trick is to make this point invisible, so set it to a low value
                _vertices[3*out_offset+2] = -50.0;

				
			}
		});
	}
	else 
	{
		unsigned int* reorder_index  = (unsigned int*)[order bytes];
        dispatch_apply(nwaves, queue, ^(size_t i) {
            int j,k;
            unsigned int in_offset,out_offset = 0;
           // unsigned int moffset = 0;
            //unsigned int stdoffset = 0;
            //for(i=0;i<nwaves;i++)
            //{
			for(j=0;j<channels;j++)
			{
				for(k=0;k<_timepts;k++)
				{
                    in_offset = ((i*channels+reorder_index[j])*timepoints + k*_timestep);
					out_offset = ((i*channels+reorder_index[j])*_timepts + k);// + prevOffset;
					//don't reorder mean and std
					//moffset = ((nwaves*channels+j)*_timepts + k) + prevOffset;
					//stdoffset = (((nwaves+1)*channels+j)*_timepts + k) + prevOffset;

					//x
                    //TODO: For peak to work here, I need to replicate the x-value to both min/max
					_vertices[3*out_offset] = j*(_timepts+channelHop)+k+channelHop;
					//y
					_vertices[3*out_offset+1] = tmp[in_offset];
					//z
					_vertices[3*out_offset+2] = -1.0;//-(1.0+dz*i);//-(i+1);
					
					
                    //compute max/min per channel
					if ( tmp[in_offset] < chMinMax[2*j] )
					{
						chMinMax[2*j] = tmp[in_offset];
					}
					else if ( tmp[in_offset] > chMinMax[2*j+1] )
					{
						chMinMax[2*j+1] = tmp[in_offset];
					}
				}
				
			}
        });
	}	
    //compute mean and standard deviation separately;
    float *_mean = malloc(wavesize*sizeof(float));
    float *_std = malloc(wavesize*sizeof(float));
    int i,j;
    float *m,*msq;
    for(i=0;i<channels;i++)
    {
        for(j=0;j<_timepts+2;j++)
        {
            //compute mean
            m = _vertices + nwaves*3*wavesize + 3*(i*(_timepts+2)+j)+1/*+prevOffset*/;
            vDSP_meanv(_vertices+3*(i*(_timepts+2)+j)+1/*+prevOffset*/, 3*channels*(_timepts+2), m, nwaves);
            _mean[i*(_timepts+2)+j] = *m;
            //compute mean square
            msq = _vertices + (nwaves+2)*3*wavesize + 3*(i*(_timepts+2)+j)+1; /*+ prevOffset*/;
            vDSP_measqv(_vertices+3*(i*(_timepts+2)+j)+1,/*+prevOffset,*/ 3*wavesize, msq, nwaves);
            //substract the square of the mean
            *msq = *msq-(*m)*(*m);
            //take the square root and add back the mean
            *msq = sqrt(*msq);
            _std[i*_timepts+j] = *msq;
            _vertices[3*((nwaves+1)*wavesize+i*(_timepts+2)+j)+1/*+prevOffset*/] = *m- (*msq)*1.96;
            *msq = *m+(*msq)*1.96;
            
            //also set the x and z-components
            _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j) /*+ prevOffset*/] = _vertices[3*((nwaves-1)*wavesize+i*(_timepts+2)+j)/*+prevOffset*/];
            _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/] = _vertices[3*((nwaves-1)*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/];
            
            _vertices[3*((nwaves+2)*wavesize+i*(_timepts+2)+j)/*+prevOffset*/] = _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j)/*+prevOffset*/];
            _vertices[3*((nwaves+2)*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/] = _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/];
            
            _vertices[3*((nwaves+1)*wavesize+i*(_timepts+2)+j) /*+ prevOffset*/] = _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j)/*+prevOffset*/];
            _vertices[3*((nwaves+1)*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/] = _vertices[3*(nwaves*wavesize+i*(_timepts+2)+j)+2/*+prevOffset*/];
            
            

        }
    }
    if(wfMean == NULL)
    {
        wfMean = [[NSMutableData dataWithBytes:_mean length:wavesize*sizeof(float)] retain];
    }
    else
    {
        [wfMean replaceBytesInRange:NSMakeRange(0, wavesize*sizeof(float)) withBytes:_mean];
    }
    if(wfStd == NULL )
    {
        wfStd = [[NSMutableData dataWithBytes:_std length:wavesize*sizeof(float)] retain];
    }
    else
    {
        [wfStd replaceBytesInRange:NSMakeRange(0, wavesize*sizeof(float)) withBytes:_std];
    }
    free(_mean);
    free(_std);
    //determine max/min
    //should push colors and vertices here
    GLfloat *gcolor = (GLfloat*)[color bytes];
    GLfloat *_colors = malloc((3*(nWfVertices-prevOffset))*sizeof(GLfloat));
    for(i=0;i<nwaves*wavesize;i++)
    {
        _colors[3*i] = gcolor[0];
        _colors[3*i+1]= gcolor[1];
        _colors[3*i+2] = gcolor[2];
    }
    //do mean and std separately;the last 3 waveforms
    for(i=0;i<3*wavesize;i++)
    {
        _colors[3*(nwaves*wavesize+i)] = 1-gcolor[0];
        _colors[3*(nwaves*wavesize+i)+1] = 1-gcolor[1];
        _colors[3*(nwaves*wavesize+i)+2] = 1-gcolor[2];
    }
    [[self openGLContext] makeCurrentContext];
    if(wfVertexBuffer == 0)
    {
        glGenBuffers(1, &wfVertexBuffer);
    }
    if(wfColorBuffer == 0)
    {
        glGenBuffers(1, &wfColorBuffer);
    }
        
    
    //check if we are overlaying
	float *tmp_ymax,*tmp_ymin;
	float ymaxmin,yminmax,yminrange;
    if( [self overlay] )
    {
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        //need to get the previous data
        GLfloat *tmp2 = malloc(3*nWfVertices*sizeof(GLfloat));
        GLfloat *tmp = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
        //copy the existing vertices
        memcpy(tmp2, tmp, 3*prevOffset*sizeof(GLfloat));
        glUnmapBuffer(GL_ARRAY_BUFFER);
        //copy the new vertices
        memcpy(tmp2+3*prevOffset, _vertices, (3*(nWfVertices-prevOffset))*sizeof(GLfloat));
        glBufferData(GL_ARRAY_BUFFER, 3*nWfVertices*sizeof(GLfloat), tmp2, GL_DYNAMIC_DRAW);

		//determine min/max;num spikes is everything
		tmp_ymax = malloc(num_spikes*sizeof(float));
		tmp_ymin = malloc(num_spikes*sizeof(float));
		
		//dispatch_apply(num_spikes, queue, ^(size_t i) 
		//int i;
		for(i=0;i<num_spikes;i++)
		   {
			   //compute maximum and minimum y for each wave
			   vDSP_maxv(tmp2+i*3*wavesize+1, 3, tmp_ymax+i, wavesize);
			   vDSP_minv(tmp2+i*3*wavesize+1, 3, tmp_ymin+i, wavesize);
		   }//);
		//determine overall maximum
		vDSP_maxv(tmp_ymax, 1, wfMinmax+3, num_spikes);
		vDSP_minv(tmp_ymin, 1, wfMinmax+2, num_spikes);
		
		vDSP_maxv(tmp_ymin, 1, &yminmax, num_spikes);
		vDSP_minv(tmp_ymax, 1, &ymaxmin, num_spikes);
		
		
		
		free(tmp_ymax);
		free(tmp_ymin);

        
        //now do the same for the colors
        glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
        tmp = glMapBuffer(GL_ARRAY_BUFFER,GL_READ_ONLY);
        memcpy(tmp2, tmp, 3*prevOffset*sizeof(GLfloat));
        glUnmapBuffer(GL_ARRAY_BUFFER);
        memcpy(tmp2+3*prevOffset, _colors, (3*(nWfVertices-prevOffset))*sizeof(GLfloat));
        glBufferData(GL_ARRAY_BUFFER, 3*nWfVertices*sizeof(GLfloat), tmp2, GL_DYNAMIC_DRAW);
        //we dont' need tmp2 anymore
        free(tmp2);
        //indices are handled further down
    }
    else
    {
        //not overlay; just copy everything directly
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, nWfVertices*3*sizeof(GLfloat), _vertices, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
        glBufferData(GL_ARRAY_BUFFER, nWfVertices*3*sizeof(GLfloat), _colors, GL_DYNAMIC_DRAW);

		//determine min/max;num spikes is everything
		tmp_ymax = malloc(nwaves*sizeof(float));
		tmp_ymin = malloc(nwaves*sizeof(float));
		
		//dispatch_apply(num_spikes, queue, ^(size_t i) 
		//int i;
		for(i=0;i<nwaves;i++)
		   {
			   //compute maximum and minimum y for each wave
			   vDSP_maxv(_vertices+i*3*wavesize+1, 3, tmp_ymax+i, wavesize);
			   vDSP_minv(_vertices+i*3*wavesize+1, 3, tmp_ymin+i, wavesize);
		   }//);
		//determine overall maximum
		vDSP_maxv(tmp_ymax, 1, wfMinmax+3, nwaves);
		vDSP_minv(tmp_ymin, 1, wfMinmax+2, nwaves);
		
		vDSP_maxv(tmp_ymin, 1, &yminmax, nwaves);
		vDSP_minv(tmp_ymax, 1, &ymaxmin, nwaves);
		
		
		
		free(tmp_ymax);
		free(tmp_ymin);
    }
    free(_colors);
    free(_vertices);

	yminrange = (ymaxmin-yminmax);
	wfMinmax[0] = 0;
	wfMinmax[1] = channels*(_timepts+channelHop);
	xmin = 0;
	xmax = wfMinmax[1];
	wfMinmax[4] = -1.0;//0.1;
	wfMinmax[5] = 1.0;//100;//nwaves+2;
	ymin = wfMinmax[2];
	ymax = wfMinmax[3];


	[self setColor: color];
        
    if( drawStd == NO )
    {
        drawStd = YES;
        [self setDrawStd:NO];
    }
    else
    {
        drawStd = NO;
        [self setDrawStd:YES];
    }

    if( drawMean == NO )
    {
        //trick to force a change
        drawMean = YES;
        [self setDrawMean:NO];
    }
    else
    {
        drawMean = NO;
        [self setDrawMean:YES];
    }
     
    wfDataloaded = YES;
    [self setNeedsDisplay: YES];
    
}

-(void)computeMeandAndStd
{
    int i,j,k;
    float *m,*msq;
    float q;
    unsigned int timepoints = timepts;
    unsigned int channels = chs;
    unsigned int nwaves = orig_num_spikes;
    unsigned int offset = 0;
    float *_mean = malloc(timepoints*channels*sizeof(float));
    float *_std = malloc(timepoints*channels*sizeof(float));

    NSUInteger *_indices = malloc(num_spikes*sizeof(NSUInteger));
    //get the indices
    [waveformIndices getIndexes:_indices maxCount:num_spikes inIndexRange:nil];
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    float *_wfVertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    for(i=0;i<channels;i++)
    {
        for(j=0;j<timepoints;j++)
        {
            //compute mean
            m = _wfVertices + nwaves*3*channels*timepoints + 3*(i*timepoints+j)+1;
            //vDSP_meanv(_wfVertices+3*(i*timepoints+j)+1, 3*channels*timepoints, m, nwaves);
            *m = 0;
            //compute mean square
            msq = _wfVertices + (nwaves+2)*3*channels*timepoints + 3*(i*timepoints+j)+1;
            *msq = 0;
            offset = 3*(i*timepoints+j)+1;
            for(k=0;k<num_spikes;k++)
            {
                q =_wfVertices[offset+3*channels*timepoints*_indices[k]];
                *m += q;
                *msq+=q*q;
            }
            *m/=num_spikes;
            *msq/=num_spikes;
            //vDSP_measqv(_wfVertices+3*(i*timepoints+j)+1, 3*channels*timepoints, msq, nwaves);
            //substract the square of the mean
            *msq = *msq-(*m)*(*m);
            //take the square root and add back the mean
            *msq = sqrt(*msq);
            _wfVertices[3*((nwaves+1)*channels*timepoints+i*timepoints+j)+1] = *m- (*msq)*1.96;
            *msq = *m+(*msq)*1.96;
            _mean[i*timepoints+j] = *m;
            _std[i*timepoints +j] = *msq;
            /*
            //also set the x and z-components
            _wfVertices[3*((nwaves+2)*wavesize+i*timepoints+j)] = _wfVertices[3*(nwaves*wavesize+i*timepoints+j)];
            _wfVertices[3*((nwaves+2)*wavesize+i*timepoints+j)+2] = _wfVertices[3*(nwaves*wavesize+i*timepoints+j)+2];
            _wfVertices[3*((nwaves+1)*wavesize+i*timepoints+j)] = _wfVertices[3*(nwaves*wavesize+i*timepoints+j)];
            _wfVertices[3*((nwaves+1)*wavesize+i*timepoints+j)+2] = _wfVertices[3*(nwaves*wavesize+i*timepoints+j)+2];
            */
        }
    }
    if(wfMean == NULL)
    {
        wfMean = [[NSMutableData dataWithBytes:_mean length:wavesize*sizeof(float)] retain];
    }
    else
    {
        [wfMean replaceBytesInRange:NSMakeRange(0, wavesize*sizeof(float)) withBytes:_mean];
    }
    if(wfStd == NULL )
    {
        wfStd = [[NSMutableData dataWithBytes:_std length:wavesize*sizeof(float)] retain];
    }
    else
    {
        [wfStd replaceBytesInRange:NSMakeRange(0, wavesize*sizeof(float)) withBytes:_std];
    }

    free(_mean);
    free(_std);
    glUnmapBuffer(GL_ARRAY_BUFFER);

}

/*static void wfPushVertices()
{
    //set up index buffer
    //int k = 0;
    //delete all buffers first
    glDeleteBuffers(1, &wfVertexBuffer);
    glDeleteBuffers(1, &wfColorBuffer);
    glDeleteBuffers(1, &wfVertexBuffer);
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
    GLenum glerror = glGetError();
    if(glerror != GL_NO_ERROR)
    {
        NSLog(@"GL error code %d", glerror);
    }
    //wfVertices now exist on the GPU so we can free it up
    //free(wfVertices);
    //wfVertices = NULL;
    //create the pixelBuffer as wee
    glGenBuffers(1, &wfPixelBuffer);
    wfDataloaded = YES;
    
    
    
}*/

/*static void wfModifyColors(GLfloat *color_data,GLfloat *gcolor, unsigned int n)
{
    int i;
    for(i=0;i<n;i++)
    {
        color_data[3*i] = gcolor[0];//use_colors[3*cids[i+1]];
        color_data[3*i+1] = gcolor[1];//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = gcolor[2];//use_colors[3*cids[i+1]+2];
    }
	//change mean color
	unsigned int offset = 0;
	for(i=0;i<wavesize;i++)
	{
		offset = 3*(n-3*wavesize+i);
		color_data[offset] = 1.0-0.5*gcolor[0];
		color_data[offset+1] = 1.0-0.5*gcolor[1];
		color_data[offset+2] = 1.0-0.5*gcolor[2];
		
		offset = 3*(n-2*wavesize+i);
		color_data[offset] = 1.0-0.5*gcolor[0];
		color_data[offset+1] = 1.0-0.5*gcolor[1];
		color_data[offset+2] = 1.0-0.5*gcolor[2];
			
		offset = 3*(n-wavesize+i);
		color_data[offset] = 1.0-0.5*gcolor[0];
		color_data[offset+1] = 1.0-0.5*gcolor[1];
		color_data[offset+2] = 1.0-0.5*gcolor[2];
		
	}
}*/

-(void) highlightChannels:(NSArray*)channels
{
	[[self openGLContext] makeCurrentContext];
}

-(void) highlightWaveforms:(NSData*)wfidx
{
    //first wheck if window is visible
    if([[self window] isVisible ]== NO )
    {
        //do nothing
        return;
    }
	//wfidx must be in cluster coordinates and not refer to wfVertices
	//if nothing changed, return
	if([wfidx isEqual:highlightWaves] )
	{
		return;
	}
    unsigned int* _points = (unsigned int*)[wfidx bytes];
	
    unsigned int _npoints = [wfidx length]/sizeof(unsigned int);
    if( [waveformIndices count] < _npoints)
    {
        return;
    }
    GLfloat zvalue,zp;
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    GLfloat *_data = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY);
    unsigned int idx,i,j,found;
    unsigned int* _hpoints;
    unsigned int _nhpoints;
	NSUInteger largestIndex = firstIndex + [waveformIndices lastIndex];
    NSUInteger* _indexes = malloc(num_spikes*sizeof(NSUInteger));
	[waveformIndices getIndexes:_indexes maxCount:num_spikes inIndexRange:nil];
    if( highlightWaves != NULL )
    {
        _hpoints = (unsigned int*)[highlightWaves bytes];
        _nhpoints = [highlightWaves length]/sizeof(unsigned int);
		found = 0;
        for(i=0;i<_nhpoints;i++)
        {
            //need to reset z-value of previously highlighted waveform
            //idx = _hpoints[i];
            //TODO: we should be able to do without this check
            if( (_hpoints[i] < largestIndex) && (_hpoints[i] >= firstIndex))
            {
                //idx = _indexes[_hpoints[i]];
				idx = _hpoints[i]-firstIndex;
                zvalue = -1.0;
                //zvalue = wfVertices[idx*timepts*chs*3+2];
                //vDSP_vfill(&zvalue,_data+(idx*timepts*chs*3)+2,3,timepts*chs);
                for(j = 0;j<wavesize;j++)
                {
                    zp = _data[3*(idx*wavesize+j)+2];
                    zp = zp > -50 ? zvalue : zp;
                    _data[3*(idx*wavesize+j)+2] = zp;
                }
        
            }
        }
		//alternative way of doing this, since we have an index set
		
    }
    zvalue = 1.1;
    //set the z-value
    for(i=0;i<_npoints;i++)
    {
        idx = _points[i]- firstIndex;
		//idx = _indexes[_points[i]];
		//check that the point is valid
		if( idx < orig_num_spikes )
		{
			//vDSP_vfill(&zvalue,_data+(idx*timepts*chs*3)+2,3,timepts*chs);
            for(j = 0;j<wavesize;j++)
            {
                zp = _data[3*(idx*wavesize+j)+2];
                zp = zp > -50 ? zvalue : zp;
                _data[3*(idx*wavesize+j)+2] = zp;
            }
		}
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glBindBuffer(GL_ARRAY_BUFFER, wfColorBuffer);
    GLfloat *_colors = (GLfloat*)glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
    GLfloat dcolor;
    
    if( highlightWaves != NULL )
    {
        //unsigned int* _hpoints = (unsigned int*)[NSData bytes];
        //unsigned int _nhpoints = [wfidx length]/sizeof(unsigned int);
        for(i=0;i<_nhpoints;i++)
        {
            idx = _hpoints[i]-firstIndex;
            if(idx >= orig_num_spikes)
                continue;
           // idx = _indexes[_hpoints[i]];
            dcolor = 1-_colors[idx*wavesize*3];
            vDSP_vfill(&dcolor,_colors+(idx*wavesize*3),3,wavesize);
            dcolor = 1-_colors[idx*wavesize*3+1];
            vDSP_vfill(&dcolor,_colors+(idx*wavesize*3)+1,3,wavesize);
            dcolor = 1-_colors[idx*wavesize*3+2];
            vDSP_vfill(&dcolor,_colors+(idx*wavesize*3)+2,3,wavesize);
        }
        
    }
    //find the complement
    /*
    GLfloat *hcolor = malloc(4*sizeof(GLfloat));
    hcolor[0] = 1.0-dcolor[0];
    hcolor[1] = 1.0-dcolor[1];
    hcolor[2] = 1.0-dcolor[2];
     */
    for(i=0;i<_npoints;i++)
    {
        idx = _points[i]-firstIndex;
        if(idx>= orig_num_spikes)
            continue;
		//idx = _indexes[_points[i]];
		
        dcolor = 1-_colors[idx*wavesize*3];
        vDSP_vfill(&dcolor,_colors+(idx*wavesize*3),3,wavesize);
        dcolor = 1-_colors[idx*wavesize*3+1];
        vDSP_vfill(&dcolor,_colors+(idx*wavesize*3)+1,3,wavesize);
        dcolor = 1-_colors[idx*wavesize*3+2];
        vDSP_vfill(&dcolor,_colors+(idx*wavesize*3)+2,3,wavesize);
		
    }
    if(highlightWaves != NULL)
    {
        [[self highlightWaves] setData: wfidx];
    }
    else 
    {
        [self setHighlightWaves:[NSMutableData dataWithData:wfidx]];
    }

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

-(void) drawAnObject
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
   
    glDrawArrays(GL_LINES, 0, nWfVertices);
    glDrawArrays(GL_LINES, 1, nWfVertices-1);
    //glDrawRangeElement
}

-(void)drawLabels
{
    //TODO: This does not work; the labels are stretched, and drawn in black, not whte as the color suggests.
    int nlabels = 2;
    int i;
    //NSAttributedString *label;
    NSMutableDictionary *normal9Attribs = [NSMutableDictionary dictionary];
    [normal9Attribs setObject: [NSFont fontWithName: @"Helvetica" size: 8.0f] forKey: NSFontAttributeName];
    //label = [[[NSMutableAttributedString alloc] initWithString:@"GL Capabilities:" attributes:bold12Attribs] autorelease];
    float width = [self bounds].size.width;
    float height =[self bounds].size.height;
    //the margins are decided by how the data are scaled; the full extent of the window is 1.2*height (widith)
	//float xmargin = 0;
    //float ymargin = (height-height/1.2)/2.0;//0.001*height;
    float dy = height/1.2/(nlabels-1);
	dy = height/(1.1*(ymax-ymin));
	//data increment
	//float dy_ = (ymax-ymin)/(nlabels-1);
    //float y = [self bounds].origin.y;
	[[self openGLContext] makeCurrentContext];
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glScalef (2.0f / width, -2.0f /  height, 1.0f);
	float *label_positions = (float*)malloc(3*sizeof(float));
	//top
	//label_positions[2] = 0.5*height-ymargin;
	label_positions[2] = 0.5*height-dy*0.1*(ymax-ymin)/2;
	label_positions[1] = -0.5*height+dy*(0.1*(ymax-ymin)/2.0+ymax);
	//bottom
	//label_positions[0] = 0.5*height-ymargin-height/1.2;
	label_positions[0] = -0.5*height+dy*0.1*(ymax-ymin)/2;
	
	float *label_titles = (float*)malloc(3*sizeof(float));
	label_titles[0] = ymax;
	label_titles[1] = 0;
	label_titles[2] = ymin;
    for(i=0;i<nlabels+1;i++)
    {
        NSAttributedString *label;
        //label = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%.1f",ymin+i*dy_]  attributes:normal9Attribs] autorelease];
		label = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%.1f",label_titles[i]]  attributes:normal9Attribs] autorelease];

        GLString *glabel;
        glabel = [[[GLString alloc] initWithAttributedString:label withTextColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f] withBoxColor:[NSColor colorWithDeviceRed:0.4f green:0.4f blue:0.0f alpha:1.0f] withBorderColor:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:0.0f alpha:1.0f]] autorelease];
		//y = i*(dy-[glabel frameSize].height);
		//[glabel drawAtPoint:NSMakePoint (-0.5*width+xmargin,0.5*height-ymargin-[glabel frameSize].height - y)];
		[glabel drawAtPoint:NSMakePoint (-0.5*width,label_positions[i] - 0.5*[glabel frameSize].height)];

        //drawAtPoint:NSMakePoint (10.0f, height - [glabelY frameSize].height - 10.0f)];
    }
	free(label_titles);
	free(label_positions);
	glPopMatrix();

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
        if ([self shouldDrawLabels]) {
            [self drawLabels];
        }
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		
		/*glOrtho(1.05*xmin-0.05*xmax, 1.05*xmin-0.05*xmax, 1.05*wfMinmax[2]-0.05*wfMinmax[3], 
				1.05*wfMinmax[3]-0.05*wfMinmax[2], wfMinmax[4], wfMinmax[5]);*/
        glOrtho(xmin, xmax, 1.1*ymin, 1.1*ymax, 1.1*wfMinmax[4], 1.1*wfMinmax[5]);
		[self drawAnObject];
		//glPushMatrix();
		//glScalef(1.0/(xmax-xmin),1.0/(ymax-ymin),1.0);
		
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
    CGFloat hue,sat,val,alpha;
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
	
		NSUInteger* _points = malloc(([hide count])*sizeof(NSUInteger));
		[hide getIndexes: _points maxCount: [hide count] inIndexRange: nil];
		[self hideWaveforms:[NSData dataWithBytes:_points length:[hide count]]];
		free(_points);
	}
}

-(void) hideOutlierWaveforms:(id)sender
{
    //highlight the waveforms outside the 95% confidence interval
    GLfloat *_vertices,d;
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
	//hides all waveforms outside mean+/-1.96 std
	NSUInteger *_index = malloc(num_spikes*sizeof(NSUInteger));
	[waveformIndices getIndexes:_index maxCount:num_spikes inIndexRange:nil];

	unsigned int i,j;
	NSMutableData *idx = [NSMutableData dataWithCapacity:num_spikes];
	for(i=0;i<num_spikes;i++)
	{
		for(j=0;j<wavesize;j++)
		{
            //compute the distance from the mean, divided by the standard devation; essientially the Z-score
            d = (_vertices[3*(_index[i]*wavesize+j)+1] - _vertices[3*((orig_num_spikes+1)*wavesize+j)+1])/(_vertices[3*((orig_num_spikes+2)*wavesize+j)+1]-_vertices[3*((orig_num_spikes+1)*wavesize+j)+1]);
            //correct for the fact that the plot shows the 95% confidence interval
            d = d*1.96;
            //if the z-score exceeds 3, it's considered different
			if( ( d < -3) || (d > 3) )
			{
				[idx appendBytes:&_index[i] length:sizeof(unsigned int)];
				//found one, so skip to next waveform
				break;
			}
		}
	}
    glUnmapBuffer(GL_ARRAY_BUFFER);
	free(_index);
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:idx,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects:                                                                                                                       @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object: self userInfo: params];
	//[self highlightWaveforms: idx];
	//[self hideWaveforms:idx];
	
}

-(void) hideWaveforms:(NSData*)wfidx
{
    //hide the waveforms specified in wfidx by setting their z-values to -50
	//wfidx will be in the new coordinates
    float z,*_vertices;
    unsigned int* _points = (unsigned int*)[wfidx bytes];
    unsigned int _npoints = [wfidx length]/sizeof(unsigned int);
	NSUInteger largestIndex,npointsToRemove;
    int i,j,found,k,l;
    z = -50;
    j = 0;
    found = 0;
    k = 0;	
	//get the indices
	NSUInteger *_index = malloc(num_spikes*sizeof(NSUInteger));
	[waveformIndices getIndexes:_index maxCount:num_spikes inIndexRange:nil];
	//get the largest index
	largestIndex = [waveformIndices lastIndex];
	[[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
	npointsToRemove = 0;
    for(i=0;i<num_spikes;i++)
    {
        found = 0;
        j=0;
        while((found==0) && (j<_npoints))
        {
			//use the index, not the index to the index
            //remeber to offset
            
            if(_index[i] + firstIndex==_points[j])
			{
                found = 1;
			}
            //found=(i==_points[j]);
            j+=1;
        }
        if (found == 1) 
        {
			npointsToRemove+=1;
			//remove the index
			[waveformIndices removeIndex:_index[i]];
            /*don't do this; just set the z-value to -50*/
            
            /*for(l=0;l<waveIndexSize;l++)
            {
                new_idx[k*waveIndexSize+l] = tmp_idx[i*waveIndexSize+l];
            }*/
			//again we need to use the index
            vDSP_vfill(&z,_vertices+_index[i]*3*wavesize+2, 3, wavesize);
        }
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
	//
	//only remove points that were actually found
    
    if((NSInteger)num_spikes-(NSInteger)npointsToRemove<0)
    {
        num_spikes=0;
    }
    else
    {
        num_spikes-=npointsToRemove;   
    }

    if( (NSInteger)nWfIndices-(NSInteger)npointsToRemove*waveIndexSize < 0)
    {
        nWfIndices = 0;
    }
    else
    {
        nWfIndices-=npointsToRemove*waveIndexSize;
    }
	free(_index);
    //update mean if change is larger than 10%
    if(num_spikes < 0.9*numSpikesAtLeastMean )
    {
        [self computeMeandAndStd];
        numSpikesAtLeastMean = num_spikes;
    }
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
    else if( [[notification name] isEqualToString:NSUserDefaultsDidChangeNotification] )
    {
        [self setDrawMean:[[NSUserDefaults standardUserDefaults] boolForKey:@"showWaveformsMean"]];
        [self setDrawStd:[[NSUserDefaults standardUserDefaults] boolForKey:@"showWaveformsStd"]];
        [self setShouldDrawLabels:[[NSUserDefaults standardUserDefaults] boolForKey:@"showWaveformAxesLabels"]];
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
    GLfloat *_vertices;
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
        unsigned int _sidx;
        //use a for loop for now
        unsigned int i,s;
        float d_o;
        d_o = INFINITY;
        s = 0;
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
        for(i=0;i<n;i++)
        {
            _sidx = sIdx[i]-firstIndex;
            vDSP_vsadd(_vertices+3*_sidx*wfLength,3,p,D,2,wfLength);
            vDSP_vsadd(_vertices+3*_sidx*wfLength+1,3,p+1,D+1,2,wfLength);
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
        glUnmapBuffer(GL_ARRAY_BUFFER);
        free(d);
        free(D);
        wfidx = sIdx[s];
    }
	else if ([ theEvent modifierFlags] & NSCommandKeyMask )
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
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
        vDSP_vsadd(_vertices,3,p,D,2,nWfVertices);
        vDSP_vsadd(_vertices+1,3,p+1,D+1,2,nWfVertices);
        glUnmapBuffer(GL_ARRAY_BUFFER);
        //sum of squares
        vDSP_vdist(D,2,D+1,2,d,1,nWfVertices);
        //find the index of the minimu distance
        //vDSP_minvi(d,1,&fmin,&imin,nWfVertices);
        int i,j;
		float q;
		fmin = INFINITY;
        imin = 0;
		//only search among the shown waveforms
		for(i=0;i<num_spikes;i++)
		{
			for(j=0;j<wavesize;j++)
			{
				q = d[_indexes[i]*wavesize+j];
				if (q < fmin) {
					fmin = q;
					//imin = _indexes[i];
					imin = i;
				}
			}
		}
		free(_indexes);
		//imin now holds the index of the vertex closest to the point
        //find the number of wfVertices per waveform
        
        free(d);
        free(D);
        //we need to offset appropriately, since imin referes to the current drawn waveforms, not the full index set
		wfidx = imin + firstIndex;//(wfLength);
    }
    free(p);
    //if command key is pressed, we want to add this wavform to the currently drawn waveforms
    NSMutableData *hdata;
    if([theEvent modifierFlags] & NSShiftKeyMask)
    {
        hdata = [NSMutableData dataWithData:[self highlightWaves]];
    }
    else
    {
        hdata = [NSMutableData dataWithCapacity:sizeof(unsigned int)];
    }
    [hdata appendBytes:&wfidx length:sizeof(unsigned int)];
    /*NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects:                                                                                                                      @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:params];*/
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects:                                                                                                                     @"points",@"color",nil]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object: self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithUnsignedInt:idx[0]],
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
    GLfloat *_vertices;
    NSRect bounds = [self bounds];
    //allocate an image and intialize with the size of the view
    NSImage *image = [[[NSImage alloc] initWithSize: bounds.size] autorelease];
    //add an EPS representation
    NSEPSImageRep *imageRep = [[[NSEPSImageRep alloc] init] autorelease];
    [image addRepresentation: imageRep];
    
    [image lockFocus];
    
    //drawing

    int i,j,k,offset;
    int timepoints = timepts;
    int channels = chs;
    NSPointArray points = malloc(timepoints*sizeof(NSPoint));
    [[self openGLContext] makeCurrentContext];
    glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
    _vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);
    for(i=0;i<num_spikes;i++)
    {
        for(j=0;j<channels;j++)
        {
        //draw 
            NSBezierPath *path = [NSBezierPath bezierPath];
            
            for(k=0;k<timepoints;k++)
            {
                offset = 3*(i*wavesize+j*channels+k);
                points[k] = NSMakePoint(_vertices[offset],_vertices[offset+1]);
            }
            [path appendBezierPathWithPoints:points count:timepoints];
            [path stroke];
        }
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
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
    [self display];
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] flushBuffer];
    //bind the vertex buffer as an pixel buffer
    //glBindBuffer(GL_PIXEL_PACK_BUFFER, wfVertexBuffer);
    glReadPixels(0,0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
    //glFinish();
    image = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [image addRepresentation:imageRep];
    [image lockFocusFlipped:YES];
    [imageRep drawInRect:NSMakeRect(0,0,[image size].width, [image size].height)];
    [image unlockFocus];
    return image;
    [self setNeedsDisplay:YES];
}

//Indicate what kind of drag-operation we are going to support
-(NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)localDestination
{
	return NSDragOperationMove;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
    if ([theEvent modifierFlags] & NSNumericPadKeyMask) {
        [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
    } else {
		//TODO: this should be made more general, i.e. I don't want to have to rely on arcane key combinations
		if( ([[theEvent characters] isEqualToString: @"z"] ) && (highlightedChannels != NULL ))
		{
            if([highlightedChannels count] == 0)
            {
                return;
            }
			//[self highlightChannels: highlightedChannels]
			float minChannel = [[highlightedChannels objectAtIndex:0] floatValue];
			float maxChannel = [[highlightedChannels lastObject] floatValue];
			if (minChannel<=maxChannel)
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
            /*
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSData dataWithBytesNoCopy:wfVertices length:3*num_spikes*wavesize*sizeof(GLfloat)],
									  @"data",[NSNumber numberWithUnsignedInt:chs],@"channels",
									  [NSNumber numberWithUnsignedInt:timepts],@"timepoints",nil];
			//post notification
			[[NSNotificationCenter defaultCenter] postNotificationName:@"computeSpikeWidth" object: self userInfo:userInfo];
             */
		}/*
        
		else if ( [[theEvent characters] isEqualToString: @"a"] )
		{
			[self hideOutlierWaveforms];
		}*/
        else if( [[theEvent characters] isEqualToString:@"s"] )
        {
            
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

-(IBAction)moveLeft:(id)sender
{
	//shift highlighted waveform downwards
	NSMutableData *hdata;
	if( [self highlightWaves] != NULL )
	{
		//NSUInteger *_index = malloc(num_spikes*(sizeof(NSUInteger)));
		//[waveformIndices getIndexes:_index maxCount:num_spikes inIndexRange:nil];
		hdata = [NSMutableData dataWithData:[self highlightWaves]];		
		//get the indices and increment by one
		unsigned int *idx = (unsigned int*)([hdata bytes]);
		unsigned int len = [hdata length]/sizeof(unsigned int);
		//NSUInteger k;
		int i;
		for(i=0;i<len;i++)
		{
			if( idx[i] > firstIndex )
			{
				idx[i]--;
				//move one index back
			//k = [waveformIndices indexLessThanIndex:idx[i]];
			//if( k != NSNotFound )
			//	idx[i] = (unsigned int)k;
			}
		}
	}
	else
	{
		//no highlighted waves, so set highlight to the first wave
		unsigned int idx = 0;//(unsigned int)[waveformIndices firstIndex];
		hdata = [NSMutableData dataWithBytes:&idx length:sizeof(unsigned int)];

	}
	//create and send the notification
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects:                                                                                                                       @"points",@"color",nil]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object: self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys:																							   [NSNumber numberWithUnsignedInt:idx[0]],
													@"selected",nil]];
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
		//NSUInteger  k;
		for(i=0;i<len;i++)
		{
			if( idx[i] - firstIndex < num_spikes -1 )
			{
				idx[i]++;
				//advance one index
			//k = [waveformIndices indexGreaterThanIndex:idx[i]];
			//if(k != NSNotFound )
			//	idx[i] = (unsigned int)k;
			}
		}
	}
	else
	{
		//no highlighted waves, so set highlight to the first wave
		unsigned int idx = firstIndex;//(unsigned int)[waveformIndices firstIndex];
		hdata = [NSMutableData dataWithBytes:&idx length:sizeof(unsigned int)];
		
	}
	//create and send the notification
	NSDictionary *params = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:hdata,
                                                                [NSData dataWithData: [self getColor]],nil] forKeys: [NSArray arrayWithObjects:                                                                                                                       @"points",@"color",nil]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"highlight" object:self userInfo: params];
	unsigned int *idx = (unsigned int*)[hdata bytes];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"showInput" object:self userInfo: [NSDictionary dictionaryWithObjectsAndKeys:																							   [NSNumber numberWithUnsignedInt:idx[0]],
													@"selected",nil]];
}	

-(void)setDrawMean:(BOOL)_drawMean
{
    if(wfDataloaded)
    {
        GLfloat *tmp,z,newz;
        unsigned int i;
        newz = 1.0;
        if (_drawMean == drawMean) 
        {
            //no change; just return
            return;
        }
        if(( _drawMean == NO) && (drawMean == YES) )
        {
            //turn off
            newz = -5.0;
        }
        else if (( _drawMean == YES) && (drawMean == NO))
        {
            //turn on;
            newz = 1.0;
        }
        //effect the change
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        tmp = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
        for(i=0;i<wavesize;i++)
        {
            //z-value
            z = tmp[3*(num_spikes*wavesize+i)+2];
            //only change if it's not an invisible vertex
            z = z > -50 ? newz : z;
            tmp[3*(num_spikes*wavesize+i)+2] = z;
        }
        glUnmapBuffer(GL_ARRAY_BUFFER);

        drawMean = _drawMean;
        [self setNeedsDisplay:YES]; 
    }
    else
    {
        //even if we don't have any data, updated the variable
        drawMean = _drawMean;
    }
}

-(void)setDrawStd:(BOOL)_drawStd
{
    if( wfDataloaded )
    {   
        //check that we are actually changing the state
        if( _drawStd == drawStd)
        {
            return;
        }
        float *tmp,z,newz;
        unsigned int i;
        newz = 1.0; //initialise to something
        if( (_drawStd == YES ) && (drawStd == NO ) )
        {
            //turn on
            newz = 1.0;
        }
        else if ( (_drawStd == NO) && (drawStd == YES ))
        {
            //turn off
            newz = -5.0;
            //nWfIndices-=2*waveIndexSize;
        }
        [[self openGLContext] makeCurrentContext];
        glBindBuffer(GL_ARRAY_BUFFER, wfVertexBuffer);
        tmp = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);
        for(i=0;i<2*wavesize;i++)
        {
            //z-value
            z = tmp[3*((num_spikes+1)*wavesize+i)+2];
            //only change if it's not an invisible vertex
            z = z > -50 ? newz : z;
            tmp[3*((num_spikes+1)*wavesize+i)+2] = z;
        }
        glUnmapBuffer(GL_ARRAY_BUFFER);
        drawStd = _drawStd;
        [self setNeedsDisplay:YES];
    }
    else
    {
        drawStd = _drawStd;
    }
}

-(BOOL)drawStd
{
    return drawStd;
}

-(BOOL)drawMean
{
    return drawMean;
}

- (void)viewDidHide
{
    //if the view is hidden, we don't want to receive any highlight modifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"highlight" object:nil];
    //we can also free up vertex data
    if([self overlay] == NO )
    {
        nWfIndices=0;
        nWfVertices=0;
        //free(wfVertices);
        glDeleteBuffers(1, &wfVertexBuffer);
        free(wfIndices);
        glDeleteBuffers(1, &wfIndexBuffer);
        //free(wfColors);
        glDeleteBuffers(1, &wfColorBuffer);
        
    }
}

-(void)viewWillMoveToWindow:(NSWindow*)newWindow
{
    //if the view becomes visible, re-register for highlight modifcations
    if([[self window] isVisible] == YES)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(receiveNotification:)name:@"highlight" object:nil];
    }

}

-(void)correlateWaveforms:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"performClusterOption" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Find correlated waverforms", @"option",nil]];
}

-(void)dealloc
{
    //free(wfVertices);
    //free(wfIndices);
    free(wfMinmax);
    //free(wfColors);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewGlobalFrameDidChangeNotification
                                                  object:self];
    [self clearGLContext];
    [_pixelFormat release];
    [drawingColor release];
    [highlightColor release];
	[waveformIndices release];
    NSZoneFree([self zone],chMinMax);
    [super dealloc];
}

@end
