#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <cuda.h>

#define NUMPARTICLES 32768  //change for different size particles
#define NEIGHBORHOOD .05
#define THREADSPERBLOCK 128  //change for different size threads

void initPos(float *);
float findDistance(float *, int, int);
__device__ float findDistanceGPU(float *, int, int);
void dumpResults(int index[]);

__global__ void findRedsGPU(float *p, int *numI);

int main() {
    cudaEvent_t start, stop;
    float time;

    float *pos,   //host pos
          *dpos;  //device pos
    int *numReds,   //host numReds
        *dnumReds;  //device numReds

    pos = (float *) malloc(NUMPARTICLES * 4 * sizeof(float));
    numReds = (int *) malloc(NUMPARTICLES * sizeof(int));

    initPos(pos);

    // your code to allocate device arrays for pos and numReds go here

    // allocate space for device pos
    cudaMalloc((void **)&dpos,NUMPARTICLES * 4 * sizeof(float));
    // allocate space for device numReds
    cudaMalloc((void **)&dnumReds,NUMPARTICLES * sizeof(int));

    // copy host pos to device pos
    cudaMemcpy(dpos,pos,NUMPARTICLES * 4 * sizeof(float),cudaMemcpyHostToDevice);
    // copy host numReds to device numReds
    //cudaMemcpy(dnumReds,numReds,NUMPARTICLES * sizeof(int),cudaMemcpyHostToDevice);


    // create timer events
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start, 0);

    /* invoke kernel findRedsGPU here */
    findRedsGPU<<<NUMPARTICLES/THREADSPERBLOCK,THREADSPERBLOCK>>>(dpos,dnumReds);
    // wait for kernel to finish
    cudaThreadSynchronize();

    // your code to copy results to numReds[] go here
    cudaMemcpy(numReds,dnumReds,NUMPARTICLES * sizeof(int),cudaMemcpyDeviceToHost);



    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&time, start, stop);

    printf("Elapsed time = %f\n", time);

    dumpResults(numReds);

}

void initPos(float *p) {

    // your code for initializing pos goes here
    int i;
    int roll;
    for (i=0; i<NUMPARTICLES; i++) {
        p[i*4] = rand() / (float) RAND_MAX;
        p[i*4+1] = rand() / (float) RAND_MAX;
        p[i*4+2] = rand() / (float) RAND_MAX;
        roll = rand() % 3;
        if (roll == 0)
            p[i*4+3] = 0xff0000;
        else if (roll == 1)
            p[i*4+3] = 0x00ff00;
        else
            p[i*4+3] = 0x0000ff;
    }

}

__device__ float findDistanceGPU(float *p, int i, int j) {

    // your code for calculating distance for particle i and j
    float dx, dy, dz;

    dx = p[i*4] - p[j*4];
    dy = p[i*4+1] - p[j*4+1];
    dz = p[i*4+2] - p[j*4+2];

    return(sqrt(dx*dx + dy*dy + dz*dz));

}

__global__ void findRedsGPU(float *p, int *numI) {

    // your code for counting red particles goes here
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    int j;
    float distance;

    numI[i] = 0;
    for (j=0; j<NUMPARTICLES; j++) {
        if (i!=j) {
            /* calculate distance between particles i, j */
            distance = findDistanceGPU(p, i, j);
            /* if distance < r and color is red, increment count */
            if (distance < NEIGHBORHOOD && p[j*4+3] == 0xff0000) {
                numI[i]++;
            }
        }
    }

}


void dumpResults(int index[]) {
    int i;
    FILE *fp;

    fp = fopen("./dump.out", "w");

    for (i=0; i<NUMPARTICLES; i++) {
        fprintf(fp, "%d %d\n", i, index[i]);
    }

    fclose(fp);
}
