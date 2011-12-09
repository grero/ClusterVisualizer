//
//  iosmap.c
//  FeatureViewer
//
//  Created by Roger Herikstad on 8/12/11.
//  Copyright 2011 NUS. All rights reserved.
//



#include "isomap.h"

#ifndef MIN
#define MIN(a,b) ((a)>(b)?(b):(a))
#endif

void computeIsoMap(double *data, uint64_t n, uint64_t m,int K, double *D)
{
    unsigned int i,j,k,l,r;
    double d,q;
    double *p0 = malloc(K*sizeof(double));
    for(i=0;i<K;i++)
    {
        p0[i] = INFINITY;
    }
    for(i=0;i<n;i++)
    {
        double *p = malloc(K*sizeof(double));
        //set to all zero
        memcpy(p,p0,K*sizeof(double));
        unsigned int *idx = malloc(K*sizeof(unsigned int));
        
        for(j=0;j<n;j++)
        {
            if(i==j)
                continue;
            //intialize to infinity
            D[i*n+j] = INFINITY;
            q = 0;
            for(k=0;k<m;k++)
            {
                d = data[i*m+k]-data[j*m+k];
                q+=d*d;
            }
            //q = sqrt(q);
            l = 0;
            while( (q>p[l]) && (l < K))
            {
                l++;
            }
            if(l < K-1)
            {   
                for(r=K-1;r>l;r--)
                {
                    p[r] = p[r-1];
                    idx[r] = idx[r-1];
                }
                p[l] = q;
                idx[l] = j;
            }
            
        }
        //we now have the nearest neighbours
        for(j=0;j<K;j++)
        {
            D[i*n+idx[j]] = p[j];
            //D[idx[j]*n+i] = p[j];
        }
        free(p);
        free(idx);
    }
    free(p0);
    
    for(i=0;i<n;i++)
    {
        for(j=0;j<n;j++)
        {
            for(k=0;k<n;k++)
            {
                D[i*n+j] = MIN(D[i*n+j], D[i*n+k]+D[k*n+j]);
            }
        }
    }
   // double *G = 
    
}
