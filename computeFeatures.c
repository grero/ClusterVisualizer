/*
 *  computeFeatures.c
 *  FeatureViewer
 *
 *  Created by Roger Herikstad on 4/29/11.
 *  Copyright 2011 NUS. All rights reserved.
 *
 */

#include "computeFeatures.h"



void computeSpikeArea(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out, float *output)
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	dispatch_apply(N, queue, ^(size_t wf){
		int i = 0;
		double d;
		double f = 0;
		for(i=0;i<stride_in;i++)
		{
			d = input[wf*stride_in+i];
			f+=d*d;
		}
		output[wf*stride_out] = (float)sqrt(f);
	});
}

void computeSpikeWidth(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out,float *output)
{
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL);
	
	//create the interpolate vector B
	int NN = stride_in;///3;
	int M = 4*NN;
	float *B = malloc(M*sizeof(float));
	int l=0;
	for(l=0;l<M;l++)
	{
		B[l] = l*0.25;
	}
	
	dispatch_apply(N, queue, ^(size_t wf){
		int i = 0;
		int s,e;
		float m  =0.0;
		float d;
		//find the minimum
		//should use interpolation here
		float *C = malloc(M*sizeof(float));
		float *A = malloc(NN*sizeof(float));
		for(i=0;i<NN;i++)
		{
			A[i] = input[wf*stride_in+i];
		}
		vDSP_vlint(A,B,1,C,1,M,NN);
		free(A);
		for(i=7*4;i<14*4;i++)
		{
			//d = input[wf*stride+3*i+1];
			d = C[i];
			if( d< m )
			{
				m = d;
				e = i;
			}
		}
		//determine the width of the peak
		s = 0;
		//while( (s < stride ) && (input[wf*stride+3*s+1] > 0.5*m ) )
		while( (s < M-1 ) && (C[s] > 0.5*m ) )
		{
			s++;
		}
		//while( (s < stride) && (input[wf*stride+3*e+1] < 0.5*m) )
		while( (e < M-1) && (C[e] < 0.5*m) )
		{
			e++;
		}
		//assume for now 30kHz sample rate
		//TODO: make this general
		m = (B[e]-B[s])/30.0;
		output[wf*stride_out] = m;
		free(C);
	});
	free(B);
	//scale
}

void computeSpikeFFT(float *input, unsigned int stride_in, unsigned int N, unsigned int stride_out, float* output)
{
    //create an FFT setup
    int exponent = (int)ceil(log2((double)stride_in));
    int maxlen = (1<<exponent);
    //padded vector
    float *rvector = calloc(maxlen,sizeof(float));
    float *ivector = calloc(maxlen,sizeof(float));
    float *zero = calloc(maxlen,sizeof(float));
    FFTSetup _fftsetup = vDSP_create_fftsetup(exponent, kFFTRadix2 );
    int i,j;
    for(i=0;i<N;i++)
    {
        memcpy(rvector,input+i*stride_in,stride_in*sizeof(float));
        memcpy(ivector,zero,maxlen*sizeof(float));
        DSPSplitComplex v;
        v.imagp = ivector;
        v.realp = rvector;
        vDSP_fft_zrip(_fftsetup,&v,1,exponent,kFFTDirection_Forward);
        vDSP_zvabs(&v,1,output + i*stride_out, 1,stride_in);
    }
    
    free(rvector);
    free(ivector);
    vDSP_destroy_fftsetup(_fftsetup);
}

void computeSpikePCA(float *input,unsigned int stride_in, unsigned int N1, unsigned int N2, unsigned int stride_out, float* output)
{
    int M = N2;
    unsigned int i,j,k;

    double *indata = malloc(N1*N2*sizeof(double));
    for(i=0;i<N1;i++)
    {
        for(j=0;j<N2;j++)
        {
            indata[i*N2+j] = (double)input[i*N2*stride_in +j*stride_in];
        }
    }
    //first compute the covariance matrix
    double *mean = malloc(M*sizeof(double));
    double *cov = calloc(M*M,sizeof(double));
    //first compute mean
    for(i=0;i<M;i++)
    {
        vDSP_meanvD(indata+i, M, mean+i, N1);
    }
    for(i=0;i<N1;i++)
    {
        for(j=0;j<M;j++)
        {
            for(k=j;k<M;k++)
            {
                cov[j*M+k] += indata[i*M+j]*indata[i*M+k];
                //symmetric
                cov[k*M+j] = cov[j*M+k];
            }
        }
        
    }
    //divide each element by M
    for(j=0;j<M;j++)
    {
        for(k=j;k<M;k++)
        {
            cov[j*M+k] /=M;
            cov[j*M+k]-=mean[j]*mean[j];
            cov[k*M+j] = cov[j*M+k];
        }
    }
    double *s = malloc(M*sizeof(double));
    double *u = malloc(M*M*sizeof(double));
    double *v = malloc(M*M*sizeof(double));
    int lwork = 5*M;
    int info = 0;
    double *work = malloc(lwork*sizeof(double));
    dgesvd_("A", "A", &M, &M, cov, &M, s, u, &M, v, &M, work, &lwork, &info);
    //compute the projections of each waveforms onto the eigenvectors
    //define a structure to hold the output
    double *outdata = malloc(N1*N2*sizeof(double));
    for(i=0;i<N1;i++)
    {
        //cblas_dgemv(CblasRowMajor,CblasNoTrans,M,M,1.0,u,M,indata+i*M,1 ,1.0,outdata+i*N2,1);
        for(j=0;j<N2;j++)
        {
            outdata[i*N2+j] = 0;
            for(k=0;k<N2;k++)
            {
                outdata[i*N2+j]+=u[j*N2+k]*indata[i*N2+k];
            }
        }
    }
    //now copy to the output structure
    for(i=0;i<N1;i++)
    {
        for(j=0;j<N2;j++)
        {
            output[i*N2*stride_in + j*stride_in] = (float)outdata[i*N2+j];
        }
    }
    free(outdata);
    free(s);
    free(u);
    free(v);
    free(work);
    free(mean);
    free(cov);
    free(indata);
        
}