#include <gsl/gsl_specfunc.h>
#include <gsl/gsl_math.h>
#include <gsl/gsl_eigen.h>
#include <math.h>

unsigned int *histogram_sorted(float *data, int datal, float*bins, int binsl,unsigned int *counts);
int matrix_inverse(double *A,int N,double *det,int *sign);
double chi2_cdf(double x, int df);
void eigen(double *A, unsigned int n, double **S, double **V);
