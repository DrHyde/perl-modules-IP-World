/* C program to test presence of Mmap on the system */
#include <sys/mman.h>

void test_mmap(size_t fileLen, int fd) {
    void *addr = mmap(0, fileLen, PROT_READ, MAP_SHARED, fd, 0);
    munmap(addr, fileLen);
}
