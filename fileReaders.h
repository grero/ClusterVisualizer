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
size_t getFileSize(char *fname);
uint64_t *readOverlapFile(char *fname, uint64_t* data,uint64_t len);