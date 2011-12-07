#include "utils.h"

unsigned int *histogram_sorted(float *data, int datal, float*bins, int binsl,unsigned int *counts)
{
	int i,j;
	i  = 0;
	for(j=0;j<datal;j++)
	{
		while( (i < binsl) && (data[j]>=bins[i]))
		{
			i+=1;
		}
		counts[i]+=1;
	}
	return counts;
}


//compute matrix inverse of square matrix A via LU factorization
int matrix_inverse(float *A,int N, float *det)
{
	//pivots
	int *IPIV = malloc((N+1)*sizeof(int));
	int LWORK = N*N;
	float *WORK = malloc(LWORK*sizeof(float));

	int INFO;
	sgetrf_(&N,&N,A,&N,IPIV,&INFO);
    if ( det != NULL)
    {
        //compute determinant
        int i;
        *det = 0;
        for(i=0;i<N;i++)
        {
            *det+= A[i*N+i];
        }
    }

	sgetri_(&N,A,&N,IPIV,WORK,&LWORK,&INFO);
    free(IPIV);
	free(WORK);

	return INFO;
	
}

double chi2_cdf(double x, int df)
{
    //compute the Chi2 CDF
    //CDF(x,k) = \frac{1}{\Gamma k/2} \gamma {k/2,x/2}
    double b = gsl_sf_gamma_inc((float)df/2,x/2);
    double c = gsl_sf_gamma((float)df/2);
    double d = (c-b)/c;
    return d;
}


