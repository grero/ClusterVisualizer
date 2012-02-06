/*
 *  readFeature.h
 *  FeatureViewer
 *
 *  Created by Grogee on 9/24/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
#include <hdf5.h>
#include <hdf5_hl.h>
#include <matio.h>

typedef struct {
    int ndim;
    int rows;
    int cols;
} header;

header *readFeatureHeader(const char *fname, header *H);
header *readMatlabFeatureHeader(const char *fname, header *H);
float *readFeatureFile(const char *fname,float *data);
float *readFeatureData(const char *fname,float *data);
float *readMatlabFeatureData(const char *fname, float*data);
char *readFeatureNames(const char *fname, char *data);
float *getMinMax(float *minmax,float *data, int nrows,int ncols);
int *readClusterIds(const char *fname,  int *cids);
void readMClustClusters(const char *fname, unsigned int *cids);
