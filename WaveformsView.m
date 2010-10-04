//
//  WaveformsView.m
//  FeatureViewer
//
//  Created by Grogee on 10/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveformsView.h"


@implementation WaveformsView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}
-(void)awakeFromNib
{
    dataloaded = NO;
}

-(void) createVertices: (NSData*)vertex_data withNumberOfWaves: (NSUInteger)nwaves channels: (NSUInteger)channels andTimePoints: (NSUInteger)timepoints
{
    wavesize = channels*timepoints;
    nindices = nwaves*wavesize;
    nvertices = nindices;
    vertices = malloc(nvertices*3*sizeof(GLfloat));
    short int *tmp = (short int*)[vertex_data bytes];
    
    int i,j,k;
    unsigned int offset = 0;
    //3 dimensions X 2
    minmax = calloc(6,sizeof(float));
    int channelHop = 10;
    //copy vertices
    for(i=0;i<nwaves;i++)
    {
        for(j=0;j<channels;j++)
        {
            for(k=0;k<timepoints;k++)
            {
                offset = ((i*channels+j)*timepoints + k);
                //x
                //vertices[offset] = tmp[offset];
                vertices[3*offset] = j*(timepoints+channelHop)+k;
                //y
                vertices[3*offset+1] = tmp[offset];
                //z
                vertices[3*offset+2] = i;
                
                //calculate minmax
                if (tmp[offset] < minmax[2] )
                {
                    minmax[2] = tmp[offset];
                }
                if (tmp[offset] > minmax[3] )
                {
                    minmax[3] = tmp[offset];
                }
                
                
            }
            
        }
    }
    minmax[0] = 0;
    minmax[1] = channels*(timepoints+channelHop);
    minmax[4] = 0;
    minmax[5] = -nwaves+1;
    //create indices
    
    //here we have to be a bit clever; if we want to draw as lines, every vertex will be connected
    //However, since we are drawing waveforms across channels, we need to separate waveforms on each
    //channel. We do this by modifying the indices. We will use GL_LINE_STRIP, which will connect every other index
    //i.e. 1-2, 3-4,5-6,etc..
    //for this we need to know how many channels, as well as how many points per channel
    //TODO: Dont' hard code these; modify the signature of the function to accept them as parameters. The below is just for testing
    //each channel will have 2*pointsPerChannel-2 points
    unsigned int pointsPerChannel = 2*timepoints-2;
    //unsigned int offset = 0;
    nindices = nwaves*channels*pointsPerChannel;
    indices = malloc(nindices*sizeof(GLuint));
    for(i=0;i<nwaves;i++)
    {
        for(j=0;j<channels;j++)
        {
            //do the first point seperately, since it's not repeated
            offset = (i*channels + j)*pointsPerChannel;
            indices[offset] = (i*channels+j)*timepoints;
            for(k=1;k<timepoints-1;k++)
            {
                indices[offset+2*k-1] = (i*channels+j)*timepoints+k;
                //replicate the previous index
                indices[offset+2*k] = indices[offset+2*k-1];
            }
            indices[offset+2*timepoints-3] = (i*channels+j)*timepoints + timepoints-1;
        }
    }
    colors = malloc(nvertices*3*sizeof(GLfloat));
    modifyColors(colors);
    //push everything to the GPU
    pushVertices();
    //draw
    [self setNeedsDisplay: YES];
}

static void pushVertices()
{
    //set up index buffer
    //int k = 0;
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(1.1*minmax[0], 1.1*minmax[1], 1.1*minmax[2], 1.1*minmax[3], 1.1*minmax[4], 1.1*minmax[5]);
    
    glGenBuffers(1,&indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, nindices*sizeof(GLuint),indices, GL_DYNAMIC_DRAW);
    //generate 1 buffer of type vertexBuffer
    
    
    glGenBuffers(1,&colorBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glBufferData(GL_ARRAY_BUFFER, nvertices*3*sizeof(GLfloat),colors,GL_DYNAMIC_DRAW);
    
    //bind vertexBuffer
    glGenBuffers(1,&vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    //push data to the current buffer
    glBufferData(GL_ARRAY_BUFFER, nvertices*3*sizeof(GLfloat), vertices, GL_DYNAMIC_DRAW);
    
    
    dataloaded = YES;
    
    
}

static void modifyColors(GLfloat *color_data)
{
    int i;
    for(i=0;i<nvertices;i++)
    {
        color_data[3*i] = 1.0f;//use_colors[3*cids[i+1]];
        color_data[3*i+1] = 0.85f;//use_colors[3*cids[i+1]+1];
        color_data[3*i+2] = 0.35f;//use_colors[3*cids[i+1]+2];
    }
}

static void drawAnObject()
{
    //activate the dynamicbuffer
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glEnableClientState(GL_VERTEX_ARRAY);
    //bind the vertexbuffer
    
     //activate vertex point; 3 points per vertex, each point of type GL_FLOAT, stride of 0 (i.e. tightly pakced), and use existing
    //vetex data, i.e. vertexBuffer activated above.
    glVertexPointer(3, GL_FLOAT, 0, (void*)0);
    glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
    glEnableClientState(GL_COLOR_ARRAY);
    glColorPointer(3, GL_FLOAT, 0, (void*)0);
    //bind the indices
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    
    //Draw nindices elements of type GL_LINES, use the loaded indexBuffer
    //the second argument to glDrawElements should be the number of objects to draw
    //i.e. number of lines below. Since nindices is the total number of points, and each line 
    //uses two points, the total number of lines to draw is ndincies/2
    glDrawElements(GL_LINES, 10/*nindices/2*/, GL_UNSIGNED_INT,(void*)0);
    //glDrawRangeElement
}



- (void)drawRect:(NSRect)dirtyRect 
{
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
    if(dataloaded)
    {
        drawAnObject();
        //drawFrame();
    }
    glFlush();
}

- (void) reshape
{
    //reshape the view
    NSRect bounds = [self bounds];
    glViewport(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
    //glMatrixMode(GL_PROJECTION);
    //glLoadIdentity();
    //glOrtho(1.1*minmax[2*draw_dims[0]], 1.1*minmax[2*draw_dims[0]+1], 1.1*minmax[2*draw_dims[1]], 1.1*minmax[2*draw_dims[1]+1], 1.1*minmax[2*draw_dims[2]], 1.1*minmax[2*draw_dims[2]+1]);
    [self setNeedsDisplay:YES];    
}


- (void) prepareOpenGL
{
    //prepare openGL context
    //dataloaded = NO;
    glClearColor(0,0, 0, 0);
    glClearDepth(1.0);
    glDepthFunc(GL_LESS);
    glEnable(GL_DEPTH_TEST);
    glShadeModel(GL_SMOOTH);
    //glPointSize(4.0);
    glEnable(GL_BLEND);
    //glEnable(GL_POINT_SMOOTH);
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_DST_ALPHA);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    
    
    
    
}


-(void)dealloc
{
    free(vertices);
    free(indices);
    free(minmax);
    free(colors);
    [super dealloc];
}

@end
