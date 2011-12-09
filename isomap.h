//
//  isomap.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 8/12/11.
//  Copyright 2011 NUS. All rights reserved.
//

#ifndef FeatureViewer_isomap_h
#define FeatureViewer_isomap_h
#endif

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

void computeIsoMap(double *data, uint64_t n, uint64_t m,int K, double *D);
