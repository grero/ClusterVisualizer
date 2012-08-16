#include "utils.h"

void computeIsolationDistance(float *data, float *means, unsigned int nrows, unsigned int ncols, unsigned int* cids, unsigned int nclusters, unsigned int *npoints, unsigned int* dims,float *minIsoDist)
{

	unsigned int i,j,k,l,bestIdx, ncombis,*combis;
	float *isoDist,bestV;
	dispatch_queue_t queue;
	//we are doing triplets
	ncombis = ncols*(ncols-1)*(ncols-2)/6;
	//vector to hold the minimum isolation distances for each combination
	isoDist = malloc(ncombis*sizeof(float));
	//first construct the combinations
	combis = malloc(ncombis*3*sizeof(unsigned int));
	l = 0;
	for(i=0;i<ncols-2;i++)
	{
		for(j=i+1;j<ncols-1;j++)
		{
			for(k=j+1;k<ncols;k++)
			{
				combis[3*l] = i;
				combis[3*l+1] = j;
				combis[3*l+2] = k;
				l+=1;
			}
		}
	}
	//do this in parallel
	queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
	dispatch_apply(ncombis,queue,^(size_t ii)
		{
			float *D,d,dd,isoDmin;
			unsigned int ll,kk,m,s;	
			isoDmin = HUGE_VAL;
			for(ll=0;ll<nclusters;ll++)	
			{
				D = malloc((nrows-npoints[ll])*sizeof(float));
				s = 0;
				for(kk=0;kk<nrows;kk++)
				{
					if(cids[kk]!=ll+1)
					{
						dd = 0;
						//compute the euclidian distance from the mean for each data point not in this cluster
						for(m=0;m<3;m++)	
						{
							d = means[ll*ncols+combis[3*ii+m]] - data[kk*ncols+combis[3*ii+m]];
							dd += d*d;
						}
						D[s] = sqrt(dd);
						s+=1;
					}
				}
				//sort the distance
				vDSP_vsort(D,s,1);
				//use this distance if it is smaller than what we have so far
				isoDmin = MIN(isoDmin,D[npoints[ll]-1]);
				free(D);
				
			}
			isoDist[ii] = isoDmin;
		});
	//find the largest minimum isolation distance
	bestV = -HUGE_VAL;
	for(i=0;i<ncombis;i++)	
	{
		bestIdx = isoDist[i] > bestV ? i : bestIdx;
		bestV = isoDist[i] > bestV ? isoDist[i] : bestV;
	}
	*minIsoDist = bestV;
	free(isoDist);
	dims[0] = combis[3*bestIdx];
	dims[1] = combis[3*bestIdx+1];
	dims[2] = combis[3*bestIdx+2];
}

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
int matrix_inverse(double *A,int N, double *det, int *sign)
{
	//pivots
	int *IPIV = malloc((N+1)*sizeof(int));
	int LWORK = N*N;
	double *WORK = malloc(LWORK*sizeof(double));
    int neg = 1;
	int INFO;
	dgetrf_(&N,&N,A,&N,IPIV,&INFO);
    if ( det != NULL)
    {
        //compute determinant
        int i;
        *det = 0;
        for(i=0;i<N;i++)
        {
            //do this to avoid underflow
            *det+= log(fabs(A[i*N+i]));
            neg = IPIV[i] != i+1 ? -neg : neg; 
            //neg*=IPIV[i*N+i];
        }
    }
    //*det = exp(*det);
	//the sign of determinant determined by neg; if it's negative, we can return the log
	*sign = neg;
	dgetri_(&N,A,&N,IPIV,WORK,&LWORK,&INFO);
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

void eigen(double *A, unsigned int n, double **S, double **V)
{
	//use gsl routines to compute eigenvalue decomposition of the square, symmetric matrix A
	//allocates space for the output S and V; S is a vector containing the sorted eigenvalues and V is 2D-vector containing the corresponding eigenvectors. Note that the eigenvectors are in the rows of V
	//from example located at http://www.gnu.org/software/gsl/manual/html_node/Eigenvalue-and-Eigenvector-Examples.html
	unsigned int i,j;
	gsl_matrix_view m;
	gsl_vector *eval;
    gsl_vector_view v;
	gsl_matrix *evec;
	gsl_eigen_symmv_workspace *w;
	
	//allocate space for output
	//eigenvalues
	*S = malloc(n*sizeof(double));
	//eigenvectors
	*V = malloc(n*n*sizeof(double));

	m = gsl_matrix_view_array(A,n,n);
	eval = gsl_vector_alloc(n);
	evec = gsl_matrix_alloc(n,n);
	w = gsl_eigen_symmv_alloc(n);
	gsl_eigen_symmv(&m.matrix,eval,evec,w);
	gsl_eigen_symmv_free(w);
	gsl_eigen_symmv_sort(eval,evec,GSL_EIGEN_SORT_ABS_ASC);
	//copy to output
	for(i=0;i<n;i++)
	{
		(*S)[i] = gsl_vector_get(eval,i);
		for(j=0;j<n;j++)
		{
			(*V)[i*n+j] = gsl_matrix_get(evec,j,i);
		}

	}
	gsl_vector_free(eval);
	gsl_matrix_free(evec);

}


