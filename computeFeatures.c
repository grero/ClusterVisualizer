/*
 *  computeFeatures.c
 *  FeatureViewer
 *
 *  Created by Roger Herikstad on 4/29/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */

#include "computeFeatures.h"



float *computeSpikeArea(float *input, unsigned int stride, unsigned int N, float *output)
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
	
	dispatch_apply(N, queue, ^(size_t wf){
		int i = 0;
		double d;
		double f = 0;
		for(i=0;i<stride;i++)
		{
			d = input[wf*stride+3*i+1];
			f+=d*d;
		}
		output[wf] = (float)sqrt(f);
	});
	return output;
}

float *computeSpikeWidth(float *input, unsigned int stride, unsigned int N, float *output)
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
	
	//create the interpolate vector B
	int NN = stride/3;
	int M = 4*NN;
	float *B = malloc(M*sizeof(float));
	int l=0;
	for(l=0;l<M;l++)
	{
		B[l] = l*0.25;
	}
	void (^aBlock)(size_t) = ^(size_t wf){
		int i = 0;
		int s,e;
		float m  =0.0;
		float d;
		//find the minimum
		//should use interpolation here
		float *C = malloc(M*sizeof(float));
		float *A = malloc(NN*sizeof(float));
		for(i=0;i<NN;i++)
		{
			A[i] = input[wf*stride+3*i+1];
		}
		vDSP_vlint(A,B,1,C,1,M,NN);
		free(A);
		for(i=7*4;i<14*4;i++)
		{
			//d = input[wf*stride+3*i+1];
			d = C[i];
			if( d< m )
			{
				m = d;
				e = i;
			}
		}
		//determine the width of the peak
		s = 0;
		//while( (s < stride ) && (input[wf*stride+3*s+1] > 0.5*m ) )
		while( (s < M ) && (C[s] > 0.5*m ) )
		{
			s++;
		}
		//while( (s < stride) && (input[wf*stride+3*e+1] < 0.5*m) )
		while( (s < M) && (C[e] < 0.5*m) )
		{
			e++;
		}
		//assume for now 30kHz sample rate
		//TODO: make this general
		output[wf] = (B[e]-B[s])/30.0;
		free(C);
	};
	dispatch_apply(N, queue, aBlock);
	free(B);
	//scale
	return output;
}