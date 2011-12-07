#include <gsl/gsl_specfunc.h>
#include <math.h>
unsigned int *histogram_sorted(float *data, int datal, float*bins, int binsl,unsigned int *counts);
int matrix_inverse(float *A,int N,float *det);
double chi2_cdf(double x, int df);
