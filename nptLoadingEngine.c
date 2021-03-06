//nptLoadingEngine.c

#include "nptLoadingEngine.h"

/*int main(int argc, char *argv[])
{
    if(argc < 2)
    {
        printf("Usage: nptLoadingEngine <filename>\n");
        exit(0);
    }
    
    nptHeader header;
    
    header.headersize = 0;
    
    header.num_spikes = 0;
    header.channels = 0;
    header.timepts = 32;
    
    getSpikeInfo(argv[1], &header);
    
    short int *data = malloc(header.num_spikes*header.channels*header.timepts*sizeof(short int));
    int index[100];
    fillArray(index, 0, 100,1);
    printf("t\n");
    getWaves(argv[1], &header, index, data);
    int i;
    int start = header.channels*header.timepts;
    for(i = start; i < start + header.channels*header.timepts; i++)
    {
        printf("%d ", data[i]);
    }
    free(data);
    return 0;
}*/

nptHeader* getSpikeInfo(const char *fname, nptHeader *header)
{
    FILE *f;
    int hs,ns;
    char chs;
    
    f = fopen(fname, "r");
    
    if(f==NULL)
    {
        return header;
    }
    hs = 0;
    ns = 0;
    chs = 0;
    
    fread(&hs, sizeof(int), 1, f);
    hs = CFSwapInt32LittleToHost(hs);
    header->headersize = hs;
    fread(&ns, sizeof(int), 1, f);
    ns = CFSwapInt32LittleToHost(ns);
    header->num_spikes = ns;    
    fread(&chs, sizeof(char), 1, f);
    //chs = CFSwapInt16LittleToHost(chs);
    header->channels = chs;
    fclose(f);
    header->timepts = 32;
    return header;
}

short int* getWaves(const char *fname, nptHeader *header, unsigned int *index, unsigned int index_length, short int *data)
{
    FILE *f;
    int chs,pts,waveLength,i,j,status;
    short int buffer;
    f = fopen(fname, "r");
    if(f==NULL)
        return NULL;
    chs = header->channels;
    pts = header->timepts;
    waveLength = chs*pts;
    
    for(i = 0; i < index_length; i++ )
    //for(i = 0; i < header->num_spikes; i++)
    {
        status = fseeko(f, header->headersize+index[i]*2*waveLength, SEEK_SET);
        if(status!=0)
        {
            fprintf(stderr,"fseek could not complete");
        }
        buffer = 0;
        for(j = 0; j < waveLength; j++)
        {
            fread(&buffer, 2, 1, f);
            buffer = (short int)CFSwapInt16LittleToHost((unsigned short int)buffer);
            //if( (i==111) & (j>=17*32) & (j<18*32) )
            //    fprintf(stderr,"%d : %d : %d \n",index[i],ftello(f),buffer);
            data[i*waveLength + j] = buffer;
        }
    }
    fclose(f);
    return data;
}

short int* getWavesForChannels(const char *fname, nptHeader *header, unsigned int *index, unsigned int index_length, unsigned int *channels, unsigned int nchannels,short int *data)
{
    FILE *f;
    int chs,pts,waveLength,i,j,status,offset,readSize;
    short int buffer;
    f = fopen(fname, "r");
    if(f==NULL)
        return NULL;
    chs = header->channels;
    pts = header->timepts;
    waveLength = chs*pts;
	//offset to where we should start reading
    offset = channels[0]*pts;
	readSize = (channels[nchannels-1] - channels[0])*pts;
    for(i = 0; i < index_length; i++ )
    //for(i = 0; i < header->num_spikes; i++)
    {
        status = fseeko(f, header->headersize+index[i]*2*waveLength + offset*2, SEEK_SET);
        if(status!=0)
        {
            fprintf(stderr,"fseek could not complete");
        }
        buffer = 0;
        for(j = 0; j < readSize; j++)
        {
            fread(&buffer, 2, 1, f);
            buffer = (short int)CFSwapInt16LittleToHost((unsigned short int)buffer);
            //if( (i==111) & (j>=17*32) & (j<18*32) )
            //    fprintf(stderr,"%d : %d : %d \n",index[i],ftello(f),buffer);
            data[i*readSize + j] = buffer;
        }
    }
    fclose(f);
    return data;
}

unsigned long long int* getTimes(const char *fname, nptHeader *header, unsigned int *index, unsigned int index_length, unsigned long long int *data)
{
    FILE *f;
    int i;
    unsigned long long int buffer;

    f = fopen(fname, "r");
    
    for(i = 0; i < index_length; i++ )
    {
        fseek(f, header->headersize+2*header->num_spikes*header->channels*header->timepts + index[i]*8, SEEK_SET);
        buffer = 0;
        fread(&buffer, sizeof(buffer),1,f);
        buffer = CFSwapInt64LittleToHost(buffer);
        data[i] = buffer;
    }

    fclose(f);
    return data;
}

/*void fillArray(int *array, int start, int end, int step)
{
    int i;
    int mstep = floor((end-start)/step);
    for(i = 0; i < mstep; i = i++)
    {
        array[i] = start + i*step; 
    }
}*/


