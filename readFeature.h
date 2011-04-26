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

typedef struct {
    int ndim;
    int rows;
    int cols;
} header;

header *readFeatureHeader(char *fname, header *H);
float *readFeatureFile(char *fname,float *data);
float *readFeatureData(char *fname,float *data);
char *readFeatureNames(char *fname, char *data);
float *getMinMax(float *minmax,float *data, int nrows,int ncols);
int *readClusterIds(char *fname,  int *cids);

