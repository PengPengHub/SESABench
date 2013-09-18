/*
 * Copyright 1993-2013 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

// This example shows how to use the clock function to measure the performance of
// a kernel accurately.
//
// Blocks are executed in parallel and out of order. Since there's no synchronization
// mechanism between blocks, we measure the clock once for each block. The clock
// samples are written to device memory.

// System includes
#include <stdio.h>
#include <assert.h>

// CUDA runtime
#include <cuda_runtime.h>

// helper functions and utilities to work with CUDA
//#include <helper_functions.h>
//#include <helper_cuda.h>

// This kernel computes a standard parallel reduction and evaluates the
// time it takes to do that for each block. The timing results are stored
// in device memory.
__extern__shared__ float shared[];
__global__ static void timedReduction(const float *input, float *output, clock_t *timer)
{
    // __shared__ float shared[2 * blockDim.x];

    const int tid = threadIdx.x;
    const int bid = blockIdx.x;

    if (tid == 0) timer[bid] = clock();

    // Copy input.
    shared[tid] = input[tid];
    shared[tid + blockDim.x] = input[tid + blockDim.x];

    // Perform reduction to find minimum.
    for (int d = blockDim.x; d > 0; d /= 2)
    {
        __syncthreads();

        if (tid < d)
        {
            float f0 = shared[tid];
            float f1 = shared[tid + d];

            if (f1 < f0)
            {
                shared[tid] = f1;
            }
        }
    }

    // Write result.
    if (tid == 0) output[bid] = shared[0];

    __syncthreads();

    if (tid == 0) timer[bid+gridDim.x] = clock();
}


// This example shows how to use the clock function to measure the performance of
// a kernel accurately.
//
// Blocks are executed in parallel and out of order. Since there's no synchronization
// mechanism between blocks, we measure the clock once for each block. The clock
// samples are written to device memory.

#define NUM_BLOCKS    64
#define NUM_THREADS   256

// It's interesting to change the number of blocks and the number of threads to
// understand how to keep the hardware busy.
//
// Here are some numbers I get on my G80:
//    blocks - clocks
//    1 - 3096
//    8 - 3232
//    16 - 3364
//    32 - 4615
//    64 - 9981
//
// With less than 16 blocks some of the multiprocessors of the device are idle. With
// more than 16 you are using all the multiprocessors, but there's only one block per
// multiprocessor and that doesn't allow you to hide the latency of the memory. With
// more than 32 the speed scales linearly.

// Start the main SDK sample here
int main(int argc, char **argv)
{
    printf("CUDA Clock sample\n");

    // This will pick the best possible CUDA capable device
    // int dev = findCudaDevice(argc, (const char **)argv);

    float *dinput = NULL;
    float *doutput = NULL;
    clock_t *dtimer = NULL;

    clock_t timer[NUM_BLOCKS * 2];
    float input[NUM_THREADS * 2];

#ifdef _SYM
    klee_make_symbolic(input, sizeof(input), "input_h");
    klee_make_symbolic(timer, sizeof(timer), "timer_h");
#else
    for (int i = 0; i < NUM_THREADS * 2; i++)
    {
        input[i] = (float)i;
    }
#endif

    //checkCudaErrors(cudaMalloc((void **)&dinput, sizeof(float) * NUM_THREADS * 2));
    //checkCudaErrors(cudaMalloc((void **)&doutput, sizeof(float) * NUM_BLOCKS));
    //checkCudaErrors(cudaMalloc((void **)&dtimer, sizeof(clock_t) * NUM_BLOCKS * 2));
    cudaMalloc((void **)&dinput, sizeof(float) * NUM_THREADS * 2);
    cudaMalloc((void **)&doutput, sizeof(float) * NUM_BLOCKS);
    cudaMalloc((void **)&dtimer, sizeof(clock_t) * NUM_BLOCKS * 2);

    //checkCudaErrors(cudaMemcpy(dinput, input, sizeof(float) * NUM_THREADS * 2, cudaMemcpyHostToDevice));
    cudaMemcpy(dinput, input, sizeof(float) * NUM_THREADS * 2, cudaMemcpyHostToDevice);

    timedReduction<<<NUM_BLOCKS, NUM_THREADS, sizeof(float) * 2 *NUM_THREADS>>>(dinput, doutput, dtimer);

    //checkCudaErrors(cudaMemcpy(timer, dtimer, sizeof(clock_t) * NUM_BLOCKS * 2, cudaMemcpyDeviceToHost));
    cudaMemcpy(timer, dtimer, sizeof(clock_t) * NUM_BLOCKS * 2, cudaMemcpyDeviceToHost);

    //checkCudaErrors(cudaFree(dinput));
    //checkCudaErrors(cudaFree(doutput));
    //checkCudaErrors(cudaFree(dtimer));
    cudaFree(dinput);
    cudaFree(doutput);
    cudaFree(dtimer);


    // Compute the difference between the last block end and the first block start.
/*
    clock_t minStart = timer[0];
    clock_t maxEnd = timer[NUM_BLOCKS];

    for (int i = 1; i < NUM_BLOCKS; i++)
    {
        minStart = timer[i] < minStart ? timer[i] : minStart;
        maxEnd = timer[NUM_BLOCKS+i] > maxEnd ? timer[NUM_BLOCKS+i] : maxEnd;
    }

    printf("Total clocks = %d\n", (int)(maxEnd - minStart));
*/
    cudaDeviceReset();

    return EXIT_SUCCESS;
}
