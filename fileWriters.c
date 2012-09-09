//
//  fileWriters.c
//  FeatureViewer
//
//  Created by Roger Herikstad on 15/11/11.
//  Copyright 2011 NUS. All rights reserved.
//

#include "fileWriters.h"
#include "math.h"

void createRaster(double *framepts, unsigned int nframes, double *sptrain, unsigned int nspikes, unsigned int nreps, double **raster, unsigned int *ncols)
{
    unsigned int *idx = malloc(nspikes*sizeof(unsigned int));
    unsigned int *repCount = calloc(nreps,sizeof(unsigned int));
    unsigned int framesPerRep = (unsigned int)floor(nframes/nreps);
    unsigned int i,j;
    j = 0;
    for(i=0;i<nspikes;i++)
    {
        while((sptrain[i]>framepts[j*framesPerRep]) && (j < nreps))
        {
            j+=1;
        }
        idx[i] = j-1;
        repCount[j-1]+=1;
    }
    int mxRepCount = 0;
    for(i=0;i<nreps;i++)
    {
        if(repCount[i]>mxRepCount)
            mxRepCount = repCount[i];
    }
    *raster = malloc(nreps*mxRepCount*sizeof(double));
    //initialize raster using NAN
    for(i=0;i<nreps*mxRepCount;i++)
    {
        (*raster)[i] = NAN;
    }
    for(i=0;i<nspikes;i++)
    {
        (*raster)[idx[i]*mxRepCount+(i%mxRepCount)] = sptrain[i]-framepts[idx[i]*framesPerRep];
    }
    *ncols = mxRepCount;
}

void writeAdjSpikesObject(const char* fname, double *framepts, unsigned int nframes, double *sptrain, unsigned int nspikes, unsigned int nreps)
{
    hid_t file,as_group,data_group, dsFramepts, dsSptrain, dsRaster,dataspace,datatype;
    hsize_t *dims = malloc(2*sizeof(hsize_t));
    herr_t status;
    
    file = H5Fcreate(fname, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    as_group = H5Gcreate(file,"/as",H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT);
    data_group = H5Gcreate(file,"/as/data",H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT);    
    dims[0] = 1;
    dims[1] = nframes;
    dataspace = H5Screate_simple(2,dims,NULL);
    datatype = H5Tcopy(H5T_NATIVE_DOUBLE);
    status = H5Tset_order(datatype, H5T_ORDER_LE);
    dsFramepts = H5Dcreate(data_group,"adjFramePoints",datatype,dataspace,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT);
    status = H5Dwrite(dsFramepts,H5T_NATIVE_DOUBLE,H5S_ALL,H5S_ALL,H5P_DEFAULT,framepts);
    H5Sclose(dataspace);
    H5Dclose(dsFramepts);
    
    dims[1] = nspikes;
    dataspace = H5Screate_simple(2,dims,NULL);
    dsSptrain = H5Dcreate(data_group,"adjSpiketrain",datatype,dataspace,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT);
    status = H5Dwrite(dsSptrain,H5T_NATIVE_DOUBLE,H5S_ALL,H5S_ALL,H5P_DEFAULT,sptrain);
    H5Sclose(dataspace);
    H5Dclose(dsSptrain);
    double *raster;
    unsigned int ncols;
    createRaster(framepts,nframes,sptrain,nspikes,nreps,&raster,&ncols);
    
    dims[0] = nreps;
    dims[1] = ncols;
    dataspace = H5Screate_simple(2,dims,NULL);
    dsRaster = H5Dcreate(data_group,"raster",datatype,dataspace,H5P_DEFAULT,H5P_DEFAULT,H5P_DEFAULT);
    status = H5Dwrite(dsRaster,H5T_NATIVE_DOUBLE,H5S_ALL,H5S_ALL,H5P_DEFAULT,raster);
    H5Sclose(dataspace);
    H5Tclose(datatype);
    H5Dclose(dsRaster);
    free(dims);
    free(raster);
    status = H5Gclose(data_group);
    status = H5Gclose(as_group);
    status = H5Fclose(file);
}

int writeCutFile(const char* fname, int *cids, uint64_t n)
{
    FILE *fid;
    fid = fopen(fname,"w");
	if( fid == NULL )
		return -1;
    uint64_t i;
    for(i=0;i<n;i++)
    {
        fprintf(fid,"%d\n",cids[i]);
    }
    fclose(fid);
	return 0;
}

int writeClusters(const char *fname, ClusteInfo *clusters, unsigned int nclusters)
{
    hid_t file;
    herr_t status;
    unsigned int i;
    for(i=0;i<nclusters;i++)
    {
        
    }
}
