/*
 *  fileReaders.c
 *  FeatureViewer
 *
 *  Created by Roger Herikstad on 3/31/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */

#include "fileReaders.h"

size_t getFileSize(const char *fname)
{
	//just a simple convenience function go get the size of a file
	FILE *fid;
	size_t nbytes;
	fid = fopen(fname,"r");
	fseek(fid,0,SEEK_END);
	nbytes = ftell(fid);
	fclose(fid);
	return nbytes;
}

uint64_t *readOverlapFile(const char *fname, uint64_t* data,uint64_t len)
{
	//the overlap files is assumed to be purely binary, and contain the column and row indices, of the non-zero entries in the overlap matrix
	//the data is assumed to be sorted wrt cluster indices
	FILE* fid;
	size_t n;
	fid = fopen(fname, "r");	
	fseek(fid,0,SEEK_SET);
	n = fread(data, sizeof(uint64_t), len , fid);
	fclose(fid);
	return data;
	
}

uint64_t *readMatOverlapFile(const char *fname, uint64_t *data, uint64_t len)
{
    
}

