/*
 *  readFeature.c
 *  FeatureViewer
 *
 *  Created by Grogee on 9/24/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "readFeature.h"


header *readFeatureHeader(const char *fname, header *H)
{
    hsize_t dims[2];
    hsize_t nsets;
    hid_t file_id;
    herr_t status;
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
	if( file_id < 0 )
	{
		H = readMatlabFeatureHeader(fname, H);
		return H;
	}
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

header *readMatlabFeatureHeader(const char *fname, header *H)
{
	matvar_t *matvar;
	mat_t *mat;
	
	//open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
	if (mat==NULL) {
		H->ndim=0;
		H->rows=-1;
		H->cols=1;
		return H;
	}
	matvar = Mat_VarReadInfo(mat,"FeatureData");
	H->ndim = matvar->rank;
	size_t *dims = matvar->dims;
	//swap these since we want to read in row major order
	H->rows = dims[1];
	H->cols = dims[0];
	Mat_Close(mat);
	return H;
}

float *readFeatureFile(const char *fname,float *data)
{
    hid_t file_id;
    herr_t status;
    //hsize_t nsets;
    //hsize_t dims[2] = {0,0};
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

float *readFeatureData(const char *fname,float *data)
{
    hid_t file_id;
    herr_t status;
    //hsize_t nsets;
    //hsize_t dims[2] = {0,0};
    file_id = H5Fopen (fname, H5F_ACC_RDONLY, H5P_DEFAULT);
	if (file_id < 0 )
	{
		data = readMatlabFeatureData(fname, data);
		return data;
	}
    status = H5LTread_dataset_float(file_id,"/FeatureData",data);
    if (status == -1)
        data = NULL;
    return data;
    
}

float *readMatlabFeatureData(const char *fname,float *data)
{
	matvar_t *matvar;
	mat_t *mat;
	
	//open file
	mat = Mat_Open(fname,MAT_ACC_RDONLY);
	matvar = Mat_VarReadInfo(mat,"FeatureData");
	//int err = Mat_VarReadDataAll(mat,matvar);
	//int nel = (matvar->nbytes)/(matvar->data_size);
	double *_data = matvar->data;
    if(_data == NULL)
    {
        data = NULL;
        return data;
    }
	int i,j;
	int rows,cols;
	rows = matvar->dims[0];
	cols = matvar->dims[1];
	//copy and transpose
	for(i=0;i<rows;i++)
	{
		for(j=0;j<cols;j++)
		{
			//data[i*cols+j] = (float)_data[j*rows+i];
			data[i*cols+j] = (float)_data[i*cols+j];

		}
	}
	Mat_VarFree(matvar);
	Mat_Close(mat);
	return data;
}

void readMClustClusters(const char *fname, unsigned int *cids)
{
    matvar_t *matvar,**cells;
	mat_t *mat;
    int bytesread;
    
    mat = Mat_Open(fname,MAT_ACC_RDONLY);
    matvar = Mat_VarReadInfo(mat,"MClust_Clusters");
    //do something else
    
    Mat_VarFree(matvar);
	Mat_Close(mat);
}

char *readFeatureNames(const char *fname, char *data)
{
    hid_t file_id;
    herr_t status;
    //hsize_t nsets;
    //hsize_t dims[2] = {0,0};
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

 int *readClusterIds(const char *fname,  int *cids)
{
    FILE *fid;
    int buffer;
    char line[80];
    int i = 0;
    fid = fopen(fname,"rt");
    
    while ( fgets(line, 80, fid) != NULL)
    {
		if( line[0] != '%' )
		{
			sscanf(line, "%d",&buffer);
			cids[i] = buffer;
			i+=1;
		}
    }
    fclose(fid);
    
    return cids;
}
