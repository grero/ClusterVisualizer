#include <gsl/gsl_specfunc.h>
#include <gsl/gsl_math.h>
#include <gsl/gsl_eigen.h>
#include <math.h>
#ifndef dispatch_queue_t
	#include <dispatch/dispatch.h>
#endif
#ifndef MIN
	#define MIN(a,b) a < b ? a : b
#endif
void computeIsolationDistance(float *data, float *means, unsigned int nrows, unsigned int ncols, unsigned int* cids, unsigned int nclusters, unsigned int *npoints, unsigned int* dims,double *minIsoDist);
unsigned int *histogram_sorted(float *data, int datal, float*bins, int binsl,unsigned int *counts);
int matrix_inverse(double *A,int N,double *det,int *sign);
double chi2_cdf(double x, int df);
void eigen(double *A, unsigned int n, double **S, double **V);
void random_sample(unsigned int N,unsigned int k, unsigned int *sample);
