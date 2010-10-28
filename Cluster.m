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
@synthesize isolationDistance;
@synthesize isiIdx;
@synthesize mask;

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

-(void)createName
{
    [self setName: [[[[self clusterId] stringValue] stringByAppendingString:@": "] stringByAppendingString:[[self npoints] stringValue]]];
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
        unsigned int i;
        unsigned int* spoints = (unsigned int*)[[self points] bytes];
        double *isis = malloc(_npoints*sizeof(double));
        unsigned long *idx = malloc(_npoints*sizeof(unsigned long));                                 
        
        for(i=0;i<_npoints-1;i++)
        {
            idx[i] = i;
            dt = times[spoints[i+1]]-times[spoints[i]];
            isis[i] = (double)dt/100.0;
            if(dt < 1000.0)
            {
                nshort+=1;
            }
        }
        //index sort; small to large
        vDSP_vsortiD(isis, idx, NULL, _npoints-1, 1);
        [self setIsiIdx:[NSData dataWithBytes:idx length:_npoints*sizeof(unsigned long)]];
        //ISIs = [[NSData dataWithBytes: isis length: _npoints*sizeof(unsigned long int)] retain];
        free(isis);
        free(idx);
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
    if(_points==NULL)
    {
        lRatio = 0;
        return;
    }
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
    //float *D = malloc((_npoints-[[self npoints] unsignedIntValue])*sizeof(float));
    float *d = malloc(ndim*sizeof(float));
    float *q = malloc(ndim*sizeof(float));
    float lratio = 0;
    float x;
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
            //D[k] = cblas_sdsdot(ndim, 1, d, 1, q, 1);  
            x = cblas_sdsdot(ndim, 0, d, 1, q, 1);
            if ( x>=0)
            {
                lratio+=1-chi2_cdf(x, ndim);
            }
            k+=1;
        }
       
    }
    free(d);
    free(q);
    //[self setLRatio:[NSData dataWithBytes:D length:sizeof(D)]];
    [self setLRatio:[NSNumber numberWithFloat:lratio]];
    //free(D);
    
}

-(void)computeIsolationDistance:(NSData*)data
{
    unsigned int n = [npoints unsignedIntValue];
    unsigned int *_points = (unsigned int*)[[self points] bytes];
    if((_points==NULL) | (n==0) )
    {
        [self setIsolationDistance: [NSNumber numberWithFloat: 0]];
        return;
    }
    float *_data = (float*)[data bytes];
    float *_mean = (float*)[[self mean] bytes];
    unsigned int ndim = (unsigned int)([[self mean] length]/sizeof(float));
    unsigned int _npoints = (unsigned int)([data length]/(ndim*sizeof(float)));
    float *d = malloc(ndim*sizeof(float));
        unsigned int N = _npoints-n;
  
    float *D = malloc(N*sizeof(float));
    float q;
    int i,k,found,j;
    k = 0;
    j = 0;
    for(i=0;i<_npoints;i++)
    {
        found = 0;
        //this works because the indices are sorted
        if(i==_points[j])
        {
            found=1;
            j+=1;
        }
       
        if(found==0)
        {
            //compute the distance
            vDSP_vsub(_mean,1,_data+i*ndim,1,d,1,ndim);
            //sum of squares
            vDSP_svesq(d,1,&q,ndim);
            D[k] = sqrt(q);
            k+=1;
        }
    }
    //sort
    vDSP_vsort(D,N,1);
    //isolation distance is the distance to the n'th closest point not in this cluster,
    //where n is the number of points in this cluster
    [self setIsolationDistance: [NSNumber numberWithFloat:D[n-1]]];
    free(d);
    free(D);
            
}

-(void)removePoints:(NSData*)rpoints
{
    unsigned int* _rpoints = (unsigned int*)[rpoints bytes];
    unsigned int _nrpoints = [rpoints length]/sizeof(unsigned int);
    
    //unsigned int*_mask = (unsigned int*)[[self mask] bytes];
    //unsigned int lmask = [[self mask] length]/sizeof(uint8);
    unsigned int _npoints = [[self indices] count]-_nrpoints;
    int i;
    for(i=0;i<_nrpoints;i++)
    {
        //_mask[_rpoints[i]] = 0;
        [[self indices] removeIndex:_rpoints[i]];
    }
    
    NSUInteger* _points = malloc(_npoints*sizeof(NSUInteger));
    [[self indices] getIndexes:_points maxCount:_npoints*sizeof(NSUInteger) inIndexRange:nil];
    unsigned int* _ppoints = malloc(_npoints*sizeof(unsigned int));
    for(i=0;i<_npoints;i++)
    {
        _ppoints[i] = (unsigned int)_points[i];
    }
    free(_points);
    [[self points] setData: [NSData dataWithBytes:_ppoints length:_npoints*sizeof(unsigned int)]];
    free(_ppoints);
    [self setNpoints:[NSNumber numberWithUnsignedInt:_npoints]];

    [self createName];
}

-(void)addPoints:(NSData*)rpoints
{
    unsigned int* _rpoints = (unsigned int*)[rpoints bytes];
    unsigned int _nrpoints = [rpoints length]/sizeof(unsigned int);
    unsigned int _npoints = [[self indices] count]+_nrpoints;

    int i;
    for(i=0;i<_nrpoints;i++)
    {
        [[self indices] addIndex:_rpoints[i]];
    }
    NSUInteger* _points = malloc(_npoints*sizeof(NSUInteger));
    [[self indices] getIndexes:_points maxCount:_npoints*sizeof(NSUInteger) inIndexRange:nil];
    unsigned int* _ppoints = malloc(_npoints*sizeof(unsigned int));
    for(i=0;i<_npoints;i++)
    {
        _ppoints[i] = (unsigned int)_points[i];
    }
    free(_points);
    [[self points] setData: [NSData dataWithBytes:_ppoints length:_npoints*sizeof(unsigned int)]];
    free(_ppoints);
    [self setNpoints:[NSNumber numberWithUnsignedInt:_npoints]];

    [self createName];
    
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
