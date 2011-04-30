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


float *computeSpikeWidth(float *input, unsigned int stride, unsigned int N, float *output);
float *computeSpikeArea(float *input, unsigned int stride, unsigned int N, float *output);

