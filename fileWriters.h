//
//  fileWriters.h
//  FeatureViewer
//
//  Created by Roger Herikstad on 15/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#ifndef FeatureViewer_fileWriters_h
#define FeatureViewer_fileWriters_h
#endif
#include <hdf5.h>
#include <hdf5_hl.h>
#include <stdlib.h>

void writeAdjSpikesObject(const char* fname, double *framepts, unsigned int nframes, double *sptrain, unsigned int nspikes, unsigned int nreps);

int writeCutFile(const char* fname, int *cids, uint64_t n);
