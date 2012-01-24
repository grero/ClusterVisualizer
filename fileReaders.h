/*
 *  fileReaders.h
 *  FeatureViewer
 *
 *  Created by Roger Herikstad on 3/31/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */
#include <stdio.h>
#include <stdint.h>
#include <matio.h>

size_t getFileSize(const char *fname);
uint64_t *readOverlapFile(const char *fname, uint64_t* data,uint64_t len);

uint64_t *readMatOverlapFile(const char *fname, uint64_t *data, uint64_t len);