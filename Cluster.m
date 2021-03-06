//
//  Cluster.m
//  FeatureViewer
//
//  Created by Grogee on 9/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Cluster.h"

#ifndef PI
#define PI 3.141592653589793
#endif

@implementation Cluster

@synthesize name;
@synthesize points;
@synthesize active;
@synthesize isTemplate;
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
@synthesize waveformsImage;
@synthesize featureDims,det;
@synthesize description,notes;
@synthesize isolationInfo;
@synthesize wfMean, wfCov,channels;

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

-(void) makeTemplate
{
    [self setIsTemplate:1];
}

-(void)undoTemplate
{
    [self setIsTemplate:0];
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
    if([ self name] != NULL )
    {
        NSString *_name = [self name];
        NSRange _range = [_name rangeOfString:@":"];
        [self setName:[_name stringByReplacingCharactersInRange:NSMakeRange(_range.location+1,[_name length]-_range.location-1) withString:[[self npoints] stringValue]]];
    }
    else
    {
        [self setName: [[[[self clusterId] stringValue] stringByAppendingString:@": "] stringByAppendingString:[[self npoints] stringValue]]];
    }
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

-(void)computeBelonginess:(NSData*)features
{
    //compute the degree to which each point in the cluster belongs to this cluster
    //this can only be computed if we have already loaded the model
    if(([self mean] == nil) || ([self covi] == nil) )
    {
        return;
    }
    float *_fpoints = (float*)[features bytes];
    float *v;
    unsigned int cols = featureDims;
    NSUInteger k = [[self indices] firstIndex];
    double *p = malloc(sizeof(double)*[[self npoints] unsignedIntValue]);
    unsigned int i = 0;
    float *q = malloc(sizeof(float)*cols);
    float *d = malloc(sizeof(float)*cols);

    float *_mean = (float*)[[self mean] bytes];
    float *_covi = (float*)[[self covi] bytes];
    float x;
    float f = sqrt(1.0/(pow(2*PI,cols))*[self det]);
    unsigned m,l;
    while(k != NSNotFound )
    {
        v = _fpoints+k*cols;
        //subtract the mean
        vDSP_vsub(_mean,1,v,1,d,1,cols);
        //divide by covariance matrix
        //cblas_sgemv(CblasRowMajor,CblasNoTrans,cols,cols,1,_covi,cols,d,1,0,q,1);
        for(m=0;m<cols;m++)
        {
            q[m] = 0;
            for(l=0;l<cols;l++)
            {
                q[m]+=_covi[m*cols+l]*d[l];
            }
        }
        //compute mahalanobis distance
        x = cblas_sdsdot(cols, 0, d, 1, q, 1);
        p[i] = -0.5*x + log(f);
        k = [[self indices] indexGreaterThanIndex:k];
        i+=1;
    }
    free(q);
    free(d);
    free(p);
}

-(NSData*)computeWaveformProbability:(NSData*)waveforms length:(NSUInteger)nwaves
{
    //computes the probability of the waveforms to be generated from this cluster, given the mean and covariance matrix
    
    NSUInteger wavesize = (NSUInteger)[waveforms length]/(nwaves*sizeof(float));

    float *_waves = (float*)[waveforms bytes];
    float *_mean = (float*)[[self wfMean] bytes];
    float *_cov = (float*)[[self wfCov] bytes];
    double *prob = malloc(nwaves*sizeof(double));
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(nwaves, queue, ^(size_t i) {
        float a,b,c,C;
        unsigned int j;
        b = 0;
        C = 1;
        for(j=0;j<wavesize;j++)
        {
            c = _cov[j];
            C*=c;
            a=(_waves[i*wavesize+j]-_mean[j]);
            b += (a*a)/(c*c);
        }
        prob[i] = 1.0/sqrt(pow(2*PI,wavesize)*C)*exp(-b);
    });
    NSData *probData = [NSData dataWithBytes:prob length:nwaves*sizeof(double)];
    return probData;
}

-(void)computeFeatureMean:(NSData*)data
{
	//uint64_t datasize = [data length];
	int cols = featureDims;
	float *_mean = calloc(cols,sizeof(float));
	float *_data = (float*)[data bytes];
    float *v;
	NSUInteger i,k,j;
    k = [[self indices] firstIndex];
	//compute mean for each dimension
    /*
	for(i=0;i<cols;i++)
	{
		vDSP_meanv(_data+i, cols, _mean+i, rows);
	}
     */
    j = 0;
    while(k != NSNotFound )
    {
        v = _data + k*cols;
        for(i=0;i<cols;i++)
        {
            _mean[i]+=v[i];
        }
        j+=1;
        k = [[self indices] indexGreaterThanIndex:k];
    }
    
    for(i=0;i<cols;i++)
    {
        _mean[i]/=([[self indices] count]);
    }
	mean = [[NSData dataWithBytes:_mean length:cols*sizeof(float)] retain];
	free(_mean);
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
	if( _mean == NULL )
	{
		[self computeFeatureMean:data];
		_mean = (float*)[[self mean] bytes];

	}
				
	
	unsigned int ndim = (unsigned int)([[self mean] length]/sizeof(float));
	unsigned int _npoints = (unsigned int)([data length]/(ndim*sizeof(float)));
    //create an index that contains all the points not in this cluster
    NSMutableIndexSet *idx = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0,_npoints)];
    [idx removeIndexes:[self indices]];
    unsigned int N = [idx count];

    NSUInteger *_idx = malloc(N*sizeof(NSUInteger));
    [idx getIndexes:_idx maxCount:_npoints inIndexRange:nil];
    
	float *d = malloc(ndim*sizeof(float));
  
	float *D = malloc(N*sizeof(float));
	float q;
	NSUInteger i,k,j;
	k = 0;
	j = 0;
	for(i=0;i<N;i++)
	{
        k = _idx[i];
        //compute the distance
        vDSP_vsub(_mean,1,_data+k*ndim,1,d,1,ndim);
        //sum of squares
        vDSP_svesq(d,1,&q,ndim);
        D[i] = sqrt(q);
	}
    free(_idx);
	//sort
	vDSP_vsort(D,N,1);
	//isolation distance is the distance to the n'th closest point not in this cluster,
	//where n is the number of points in this cluster
	[self setIsolationDistance: [NSNumber numberWithFloat:D[n-1]]];
	free(d);
	free(D);
}

-(void)computeIsolationInfo:(NSData*)data
{
    //computes the KL-divergence between this cluster and the nearest neighbour cluster; approximate the KL-divergence as the log ratio between nearest neighbour distance in this cluster and the nearest neighbour distance for all points
    if( (data == nil) || ([self indices] == nil ) )
    {
        [self setIsolationInfo:[NSNumber numberWithDouble:0]];
        return;
    }
    unsigned int _npoints_bg = [data length]/sizeof(float)/featureDims;
    float *_points = (float*)[data bytes];
    unsigned int i,j,cols;
    cols = featureDims;
    NSUInteger k;
    unsigned int _npoints = [[self indices] count];
    if(_npoints<=1)
    {
        [self setIsolationInfo:[NSNumber numberWithDouble:0]];
        return ;
    }
    k = [[self indices] firstIndex];
    //for each point in this cluster, find the nearest distance
    float *v1,*v2;
    float *dmin = calloc(_npoints,sizeof(float));
    float *dmin_bg = calloc(_npoints,sizeof(float));
    float *vd = malloc(_npoints*sizeof(float));
    //initialize
    for(i=0;i<_npoints;i++)
    {
        dmin[i] = HUGE_VALF;
        dmin_bg[i]= HUGE_VALF;
    }
    float d;
    j = 0;
    while(k != NSNotFound )
    {
        v1 = _points + k*cols;
        for(i=0;i<_npoints_bg;i++)
        {
            if(i!=k)
            {
                v2 = _points + i*cols;
                //compute distance
                //subtract v1 from v2
                vDSP_vsub(v1, 1, v2, 1, vd, 1, cols);
                //compute the square sum
                vDSP_dotpr(vd, 1, vd, 1, &d, cols);
                d = sqrt(d);
                if([[self indices] containsIndex:i])
                {
                    //dmin[j] = MIN(dmin[j], d );
                    if(d < dmin[j])
                        dmin[j] = d;
                }
                else
                {
                    //dmin_bg[j] = MIN(dmin_bg[j],d);
                    if(d < dmin_bg[j])
                        dmin_bg[j] = d;
                }
            }
               
        }
        k = [[self indices] indexGreaterThanIndex:k];
        j+=1;
    }
    d = 0;
    for(i=0;i<_npoints;i++)
    {
        d+=log2(dmin_bg[i]/dmin[i]);
    }
    d*=(double)cols/_npoints;
    d+=log2(_npoints_bg/(_npoints-1));
    free(dmin);
    free(dmin_bg);
    free(vd);
    [self setIsolationInfo: [NSNumber numberWithDouble: d]];
}

-(NSDictionary*)computeXCorr:(Cluster*)cluster timepoints:(NSData*)timepts
{
    if( timepts == NULL)
    {
        return NULL;
    }
    unsigned int _npoints1 = [[self npoints] unsignedIntValue];
    unsigned int* _points1 = (unsigned int*)[[self points] bytes];
    unsigned int _npoints2 = [[cluster npoints] unsignedIntValue];
    unsigned int* _points2 = (unsigned int*)[[cluster points] bytes];
    unsigned long long int *_timepts = (unsigned long long int*)[timepts bytes];
    unsigned int i,j,k;
    //this can potentially be huge; maybe compute a histogram directly.
    //histogram computation; -50,50
    int blen = 101;
    double binsize = 1.0;
    double *bins = NSZoneMalloc([self zone], blen*sizeof(double));
    unsigned int *counts = NSZoneMalloc([self zone], blen*sizeof(unsigned int));
    //create bins with 1 ms resolution
    for(i=0;i<blen;i++)
    {
        bins[i] = -50+i*binsize;
    }
    
    long long int xcorr = 0;
    for(i=0;i<_npoints1;i++)
    {
        for(j=0;j<_npoints2;j++)
        {
            k = 0;
            xcorr = _timepts[_points1[i]] - _timepts[_points2[j]];
            if( (xcorr < bins[0] ) || (xcorr > bins[blen-1] ))
            {
                continue;
            }
            while( (bins[k+1] < xcorr ) && (k<blen-1) )
            {
                k++;
            }
            if (k < blen-1) 
            {
                bins[k]+=1;
            }
        }
    }
    NSDictionary *dict = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:[NSData dataWithBytes:counts length:blen*sizeof(unsigned int)],
                                                               [NSData dataWithBytes:bins length:blen*sizeof(double)],nil]
                                                     forKeys: [NSArray arrayWithObjects:@"counts",@"bins",nil]];
    NSZoneFree([self zone], counts);
    NSZoneFree([self zone], bins);
    return dict;
    
}

-(void)computeFeatureRanges:(NSData*)data
{
	//data should contain the features over which to compute the ranges
}

-(void)removePoints:(NSData*)rpoints
{
    unsigned int* _rpoints = (unsigned int*)[rpoints bytes];
    unsigned int _nrpoints = [rpoints length]/sizeof(unsigned int);
    
    //unsigned int*_mask = (unsigned int*)[[self mask] bytes];
    //unsigned int lmask = [[self mask] length]/sizeof(uint8);
    
    int i;
    for(i=0;i<_nrpoints;i++)
    {
        //_mask[_rpoints[i]] = 0;
        [[self indices] removeIndex:_rpoints[i]];
    }
    unsigned int _npoints = [[self indices] count];
    NSUInteger* _points = malloc(_npoints*sizeof(NSUInteger));
    [[self indices] getIndexes:_points maxCount:_npoints*sizeof(NSUInteger) inIndexRange:nil];
    
	unsigned int* _ppoints = malloc(_npoints*sizeof(unsigned int));
    for(i=0;i<_npoints;i++)
    {
        _ppoints[i] = (unsigned int)_points[i];
    }
    free(_points);
    [[self points] setData: [NSData dataWithBytes:_ppoints length:_npoints*sizeof(unsigned int)]];
	//[[self points] setData: [NSData dataWithBytes:(unsigned int*)_points length:_npoints*sizeof(unsigned int)]];
	//free(_points);
    free(_ppoints);
    [self setNpoints:[NSNumber numberWithUnsignedInt:_npoints]];

    [self createName];
}

-(void)addPoints:(NSData*)rpoints
{
    unsigned int* _rpoints = (unsigned int*)[rpoints bytes];
    unsigned int _nrpoints = [rpoints length]/sizeof(unsigned int);
    

    int i;
    if([self indices] == nil)
    {
        [self setIndices:[NSMutableIndexSet indexSet]];
    }
    for(i=0;i<_nrpoints;i++)
    {
        [[self indices] addIndex:_rpoints[i]];
    }
    unsigned int _npoints = [[self indices] count];
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

-(void)addIndices:(NSIndexSet*)_indices
{
    if([self indices] == nil)
    {
        [self setIndices:[NSMutableIndexSet indexSet]];
    }
    [[self indices] addIndexes:_indices];
    unsigned int _npoints = [[self indices] count];
    [self setNpoints:[NSNumber numberWithUnsignedInt:_npoints]];
    NSUInteger *rpoints = malloc(_npoints*sizeof(NSUInteger));
    [[self indices] getIndexes:rpoints maxCount:_npoints inIndexRange:nil];
    NSMutableData *_points = [NSMutableData data];
    int i;
    unsigned int p;
    for(i=0;i<_npoints;i++)
    {
        p = (unsigned int)rpoints[i];
        [_points appendBytes:&p length:sizeof(unsigned int)];
    }
    free(rpoints);
    if([self points] == nil)
    {
        [self setPoints:_points];
    }
    else
    {
        [[self points] setData:_points];
    }
    [self createName];
}

-(void)encodeWithCoder:(NSCoder*)coder
{
    //responsible for encoding this object's variables
    [coder encodeObject:name forKey: @"ClusterName"];
    [coder encodeObject:points forKey: @"ClusterPoints"];
    [coder encodeObject:npoints forKey: @"ClusterNPoints"];
    [coder encodeObject:indices forKey: @"ClusterIndices"];
    [coder encodeObject:waveformsImage forKey: @"ClusterWaveformsImage"];
    [coder encodeObject:clusterId forKey:@"ClusterId"];
    [coder encodeObject:[NSNumber numberWithInt: isTemplate] forKey:@"CulsterIsTemplate"];
    [coder encodeObject: color forKey: @"ClusterColor"];
    [coder encodeObject: ISIs forKey: @"ClusterISIs"];
    [coder encodeObject: isiIdx forKey:@"ClusterIsiIdx"];
    [coder encodeObject: parents forKey:@"ClusterParents"];
    [coder encodeObject:notes forKey:@"notes"];
}

-(id)initWithCoder:(NSCoder*)coder
{
    self = [super init];
    name = [[coder decodeObjectForKey:@"ClusterName"] retain];
    points = [[coder decodeObjectForKey:@"ClusterPoints"] retain];
    npoints = [[coder decodeObjectForKey:@"ClusterNPoints"] retain];
    indices = [[coder decodeObjectForKey:@"ClusterIndices"] retain];
    waveformsImage = [[coder decodeObjectForKey:@"ClusterWaveformsImage"] retain];
    clusterId = [[coder decodeObjectForKey:@"ClusterId"] retain];
    isTemplate = [[coder decodeObjectForKey:@"ClusterIsTemplate"] intValue];
    color = [[coder decodeObjectForKey:@"ClusterColor"] retain];
    //set the textcolor
    float *buffer = (float*)[color bytes];
    textColor = [[NSColor colorWithCalibratedRed:buffer[0] green:buffer[1] blue:buffer[2] alpha:1.0] retain];
    
    ISIs = [[coder decodeObjectForKey:@"ClusterISIs"] retain];
    isiIdx = [[coder decodeObjectForKey:@"ClusterIsiIdx"] retain];
    parents = [[coder decodeObjectForKey:@"ClusterParents"] retain];
    notes = [[coder decodeObjectForKey:@"notes"] retain];
    return self;
            
             
}

-(void)updateDescription
{
	NSArray *components = [NSArray arrayWithObjects:[npoints stringValue],[shortISIs stringValue],[lRatio stringValue],[isolationDistance stringValue],nil];
	NSArray *keys = [NSArray arrayWithObjects:@"#points", @"shortISI",@"L-ratio",@"IsoDist",nil];
	NSDictionary *descr = [NSDictionary dictionaryWithObjects: components forKeys: keys];
	[self setDescription:[descr description]];
}


-(NSData*)getRelevantData:(NSData*)data withElementSize:(unsigned int)elsize
{
    NSMutableData *_data = [NSMutableData dataWithCapacity:([[self npoints] unsignedIntValue])*elsize];
    NSUInteger idx = [[self indices] firstIndex];
    while( idx != NSNotFound )
    {
        NSRange _r;
        _r.location = idx*elsize;
        _r.length = elsize;
        [_data appendData: [data subdataWithRange:_r]];
        idx = [[self indices] indexGreaterThanIndex:idx];
    }
    return _data;

}

-(void)getSpiketrain: (double**)sptrain fromTimestamps: (NSData*)timestamps
{
    unsigned int nspikes = [npoints unsignedIntValue];
    *sptrain = malloc(nspikes*sizeof(double));
    unsigned long long int *_timestamps = (unsigned long long int*)[timestamps bytes];
    unsigned int *_points = (unsigned int*)[points bytes];
    unsigned int i;
    for(i=0;i<nspikes;i++)
    {
        (*sptrain)[i] = (double)(_timestamps[_points[i]]/1000.0);
    }
}

-(void)computeWaveformStats:(NSData*)wfData withChannels:(NSUInteger)channels andTimepoints:(NSUInteger)timepoints
{
    //compute the mean and the covariance matrix of the waveforms currently assigned to this cluster
    float *_data = (float*)[wfData bytes];
    NSUInteger wavesize = timepoints*channels;

    float *_mean = malloc(wavesize*sizeof(float));
    float *_std = malloc(wavesize*sizeof(float));
    NSUInteger nwaves = [wfData length]/(channels*timepoints*sizeof(float));
    //compute the mean for each time point and for each channel
    int i,j;
    float *m,*msq;
    for(i=0;i<channels;i++)
    {
        for(j=0;j<timepoints;j++)
        {
            //compute mean
            m = _mean + (i*timepoints+j);
            vDSP_meanv(_data+(i*timepoints+j), channels*timepoints, m, nwaves);
            //compute mean square
            msq = _std + (i*timepoints+j);
            vDSP_measqv(_data+(i*timepoints+j), channels*timepoints, msq, nwaves);
            //substract the square of the mean
            *msq = *msq-(*m)*(*m);
            //take the square root and add back the mean
            *msq = sqrt(*msq);
                        
        }
    }
    [self setWfMean:[NSData dataWithBytes:_mean length:wavesize*sizeof(float)]];
    [self setWfCov:[NSData dataWithBytes:_std length:wavesize*sizeof(float)]];
    free(_mean);
    free(_std);
    
}

-(NSData*)readWaveformsFromFile:(NSString*)filename
{
    NSUInteger nwaves,i;
    NSUInteger *idx;
    short *data;
    const char *fname;
	unsigned int *_channels,_nchs;
    nptHeader spikeHeader;
    NSUInteger wavesize;
    NSData *waveformsData = nil;
   	_channels = (unsigned int*)[[self channels] bytes];
	_nchs = [[self channels] length]/sizeof(unsigned int);
    fname = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    getSpikeInfo(fname, &spikeHeader);
    wavesize = (spikeHeader.timepts)*(_nchs);
    nwaves = [[self indices] count];
    if(nwaves>0)
    {
        
        idx = malloc(nwaves*sizeof(NSUInteger));
        [[self indices] getIndexes:idx maxCount:nwaves inIndexRange:nil];
        //convert to unsigned int
        unsigned int *_idx = malloc(nwaves*sizeof(unsigned int));
        for(i=0;i<nwaves;i++)
        {
            _idx[i] = (unsigned int)idx[i];
        }
        free(idx);
        //get the waveforms
        data = malloc(nwaves*wavesize*sizeof(short int));
		if(_nchs == spikeHeader.channels)
		{
			getWaves(fname, &spikeHeader, _idx, nwaves, data);
		}
		else
		{
			getWavesForChannels(fname,&spikeHeader,_idx,nwaves,_channels,_nchs,data);
		}
        //convert to float
        float *fwaveforms = malloc(nwaves*wavesize*sizeof(float));
        vDSP_vflt16(data, 1, fwaveforms, 1, nwaves*wavesize);
        free(data);
        waveformsData = [NSData dataWithBytes:fwaveforms length:nwaves*wavesize*sizeof(float)];
    }
    return waveformsData;
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
