/*
 *  computeFeatures.h
 *  FeatureViewer
 *
 *  Created by Roger Herikstad on 4/29/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */
#import <Accelerate/Accelerate.h>
#import <dispatch/dispatch.h>
#import <string.h>


void computeSpikeWidth(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out,float *output);
void computeSpikeArea(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out, float *output);

void computeSpikeFFT(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out, float* ouput);

void computeSpikePCA(float *input,unsigned int stride_in, unsigned int N1, unsigned int N2, unsigned int stride_out, float* output);