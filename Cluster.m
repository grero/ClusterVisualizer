//
//  Cluster.m
//  FeatureViewer
//
//  Created by Grogee on 9/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Cluster.h"


@implementation Cluster

@synthesize name;
@synthesize points;
@synthesize active;
@synthesize npoints;
@synthesize color;
@synthesize indices;
@synthesize valid;
@synthesize parents;
@synthesize clusterId;
@synthesize textColor;
@synthesize shortISIs;
@synthesize mean;
@synthesize cov;
@synthesize covi;
@synthesize lRatio;

-(void)setActive:(NSInteger)value
{
    active = value;
    //when cluster is set to active, notify the FeatureView to update the colouring.
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"ClusterStateChanged" object:self];
}

-(NSInteger)active
{
    return active;
}

-(void)makeInactive
{
    [self setActive:0];
}

-(void)makeActive
{
    [self setActive:1];
}

-(void)makeInvalid
{
    [self setValid: 0];
}
-(void)makeValid
{
    [self setValid:1];
}

-(NSIndexSet*)indices
{
    return indices;
}

-(void)setColor:(NSData*)new_color
{
    color = [[NSData dataWithData:new_color] retain];
    float *buffer = (float*)[color bytes];
    textColor = [[NSColor colorWithCalibratedRed:buffer[0] green:buffer[1] blue:buffer[2] alpha:1.0] retain];
}

-(NSData*)color
{
    return color;
}

-(void)computeISIs:(NSData*)timestamps
{
    //get the times relevant for this cluster
    unsigned int _npoints = [[self npoints] unsignedIntValue];
     unsigned long long int* times = (unsigned long long int*)[timestamps bytes];
    //make sure there at more than 2 points, and that we have timestamps
    if( (_npoints > 1) && (times != NULL) )
    {
        unsigned long long int dt = 0;
        unsigned int nshort = 0;
        int i;
        unsigned int* spoints = (unsigned int*)[[self points] bytes];
        
        for(i=0;i<_npoints-1;i++)
        {
            dt = times[spoints[i+1]]-times[spoints[i]];
            if(dt < 1000)
            {
                nshort+=1;
            }
        }
        [self setShortISIs: [NSNumber numberWithFloat: 1.0*nshort/_npoints]];
    }
    else {
        [self setShortISIs: [NSNumber numberWithFloat:0.0]];
    }

    
    
}

-(void)computeLRatio:(NSData*)data
{
    //need to compute the mahalanobis distance for all points not in the cluster
    unsigned int *_points = (unsigned int*)[[self points] bytes];
    float *_mean = (float*)[[self mean] bytes];
    float *_covi = (float*)[[self covi] bytes];
    unsigned int ndim = (unsigned int)([[self mean] length]/sizeof(float));
    unsigned int _npoints = (unsigned int)([data length]/(ndim*sizeof(float)));
    float *_data = (float*)[data bytes];
    //naive implementation
    int i,found,j,k;
    found = 0;
    j = 0;
    k = 0;
    //vector to hold the differences
    float *D = malloc((_npoints-[[self npoints] unsignedIntValue])*sizeof(float));
    float *d = malloc(ndim*sizeof(float));
    float *q = malloc(ndim*sizeof(float));
    //first figure out the indices to loop over
    /*unsigned int *index = malloc((_npoints-[[self npoints] unsignedIntValue])*sizeof(unsigned int));
    for(i=0;i<[[self npoints] unsignedIntValue];i++)
    {
        while( (found == 0) && (j<_npoints) )
        {
            index[k] = j;
            j+=1;
        }
    }*/
    for(i=0;i<_npoints;i++)
    {
        //j = 0;
        found = 0;
        //this works because the indices are sorted
        if(i==_points[j])
        {
            found=1;
            j+=1;
        }
        /*while( (found == 0) && (j < [[self npoints]  unsignedIntValue]))
        {
            found = (i==_points[j]);
            j+=1;
        }*/
        if(found==0)
        {
            //subtract cluster mean
            vDSP_vsub(_mean,1,_data+i*ndim,1,d,1,ndim);
            //dot product with inverse covariance matrix
            cblas_sgemv(CblasRowMajor,CblasNoTrans,ndim,ndim,1,_covi,ndim,d,1,0,q,1);
            D[k] = cblas_sdsdot(ndim, 1, d, 1, q, 1);            
            k+=1;
        }
       
    }
    free(d);
    free(q);
    [self setLRatio:[NSData dataWithBytes:D length:sizeof(D)]];
    free(D);
    
}


-(void) dealloc
{
    [name release];
    [points release];
    [npoints release];
   // [active release];
    [indices release];
    [clusterId release];
    [parents release];
    [color release];
    [textColor release];
    [super dealloc];
}
@end
