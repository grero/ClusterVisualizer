/*
 *  readFeature.c
 *  FeatureViewer
 *
 *  Created by Grogee on 9/24/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "readFeature.h"


header *readFeatureHeader(char *fname, header *H)
{
    hsize_t dims[2];
    hsize_t nsets;
    hid_t file_id;
    herr_t status;
    char dset_name[100];
    size_t name_size;
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
    status = H5LTget_dataset_info(file_id,"/FeatureData",dims,NULL,NULL);
    status = H5Gget_num_objs(file_id,&nsets);
    H->rows = dims[0];
    H->cols = dims[1];
    H->ndim = 2;
    /*
    int i;
    H->rows = 0;
    H->cols = 0;
    for(i=0;i<nsets;i++)
    {
        status = H5Gget_objname_by_idx(file_id, (hsize_t)i, dset_name, name_size);
        status = H5LTget_dataset_info(file_id,dset_name,dims,NULL,NULL);
        H->rows = dims[0];
        H->cols += dims[1];

    }
    H->ndim = 2;*/
        
    return H;
}

float *readFeatureFile(char *fname,float *data)
{
    hid_t file_id;
    herr_t status;
    hsize_t nsets;
    hsize_t dims[2] = {0,0};
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
    status = H5LTread_dataset_float(file_id,"/data",data);
    /*
    int i;
    for(i=0;i<nsets;i++)
    {
        status = H5Gget_objname_by_idx(file_id, (hsize_t)i, dset_name, name_size);
        status = H5LTread_dataset_float(file_id,dset_name,data+dims[0]*dims[1]);
        status = H5LTget_dataset_info(file_id,dset_name,dims,NULL,NULL);
    }
    status = H5Fclose (file_id);*/
    
    return data;
}

float *readFeatureData(char *fname,float *data)
{
    hid_t file_id;
    herr_t status;
    hsize_t nsets;
    hsize_t dims[2] = {0,0};
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
    status = H5LTread_dataset_float(file_id,"/FeatureData",data);
    
    return data;
    
}

char *readFeatureNames(char *fname, char *data)
{
    hid_t file_id;
    herr_t status;
    hsize_t nsets;
    hsize_t dims[2] = {0,0};
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
    status = H5LTread_dataset_float(file_id,"/FeatureNames",data);
    return data;
}

float *getMinMax(float *minmax, float *data, int nrows,int ncols)
{
    float temp;
    //compute the maximum and minimum for each column
    int i,j;
    for(i=0;i<ncols;i++)
    {
        for(j=0;j<nrows;j++)
        {
            temp = data[j*ncols +i];
            if( temp < minmax[2*i] )
            {
                minmax[2*i] = temp;
            }
            if (temp > minmax[2*i+1] )
            {
                minmax[2*i+1] = temp;
            }
                
        }
    }
    return minmax;
}

unsigned int *readClusterIds(char *fname, unsigned int *cids)
{
    FILE *fid;
    unsigned int buffer;
    char line[80];
    int i = 0;
    fid = fopen(fname,"rt");
    
    while ( fgets(line, 80, fid) != NULL)
    {
        sscanf(line, "%d",&buffer);
        cids[i] = buffer;
        i+=1;
    }
    fclose(fid);
    
    return cids;
}