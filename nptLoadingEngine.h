/*nptLoadingEngine.h*/

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <sys/types.h>
#include <CoreFoundation/CoreFoundation.h>

typedef struct{
    int headersize;
    int num_spikes;
    int channels;
    int timepts; 
} nptHeader;

nptHeader* getSpikeInfo(char *fname, nptHeader *header);
short int* getWaves(char *fname, nptHeader *header, unsigned int *index, unsigned int index_length, short int *data);
unsigned long long int* getTimes(char *fname, nptHeader *header, int *index, int index_length, unsigned long long int *data);

//void fillArray(int *array, int start, int end, int step);
