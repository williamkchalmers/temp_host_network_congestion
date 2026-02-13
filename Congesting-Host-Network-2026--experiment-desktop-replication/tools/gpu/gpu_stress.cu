#include <cuda_runtime.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

// 100 MB buffer (Pinned memory for max PCIe speed)
#define SIZE (100 * 1024 * 1024)

int main(int argc, char* argv[]) {
    int duration = 10; // Default seconds
    if (argc > 1) duration = atoi(argv[1]);

    int *h_a, *d_a;
    // Allocate Pinned Memory (Crucial for P2M/DMA stress)
    cudaMallocHost((void**)&h_a, SIZE);
    cudaMalloc((void**)&d_a, SIZE);

    printf("Running GPU PCIe Stress for %d seconds...\n", duration);

    time_t start = time(NULL);
    while (time(NULL) - start < duration) {
        // Host to Device (P2M Write)
        cudaMemcpy(d_a, h_a, SIZE, cudaMemcpyHostToDevice);
        // Device to Host (P2M Read)
        cudaMemcpy(h_a, d_a, SIZE, cudaMemcpyDeviceToHost);
    }

    cudaFreeHost(h_a);
    cudaFree(d_a);
    return 0;
}