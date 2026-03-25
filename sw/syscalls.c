#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <reent.h>

#include "uart.h"

// Provided by the linker script
// In embedded C, using extern char for linker symbols is a convention
// char maps naturally to pointer arithmetic and avoid alignment assumptions
extern char _heap_start;
extern char _heap_end;

// A low-level memory management syscall used to grow and shrink the heap
// Adjusts the program break by a specified increment of bytes
caddr_t _sbrk(int incr) {
    // Current break
    static char *heap = &_heap_start;

    char *prev = heap;
    char *next = heap + incr;   // Computes new break

    if(next < &_heap_start || next > &_heap_end) {  // Validate that next break is within bounds
        errno = ENOMEM;
        return (caddr_t) -1;
    }
    heap = next;
    return (caddr_t) prev;
}

// Stub implementation of close() 
// On a bare-metal system with no real file descriptors, this always fails with EBADF since there are no
// open files to close
int _close(int) {
    errno = EBADF; 

    return -1;
}

// Stub implementation of fstat()
// Reports all file descriptors as character
// devices (S_IFCHR), so that newlib treats stdout as unbuffered/line-buffered,
// ensuring printf output is flushed immediately over UART
int _fstat(int, struct stat *st) {
    st->st_mode = S_IFCHR;

    return 0;
}

// Stub implementation of isatty()
// Normally checks whether a file descriptor refers to a terminal/TTY
// This always returns 1 (true), telling newlib that all file descriptors are terminals
int _isatty(int) {
    return 1;
}

// Stub implementation of lseek()
// Always fails with ESPIPE since UART is sequential and do not support seeking
off_t _lseek(int, off_t, int) {
    errno = ESPIPE;

    return (off_t) -1;
}

// Stub implementation of exit()
// On bare-metal there is no OS to return to,
// so the system halts by spinning forever in an infinite loop
void _exit(int) {
    while(1) {
        // spin!
    }
}

// Reentrant wrappers for newlib stdio functions

void *_sbrk_r(struct _reent *ptr, ptrdiff_t incr) {
    return _sbrk((int) incr);
}

int _write_r(struct _reent *ptr, int fd, const void *buf, size_t n) {
    return _write(fd, buf, n);
}

int _read_r(struct _reent *ptr, int fd, void *buf, size_t n) {
    return _read(fd, buf, n);
}

int _close_r(struct _reent *ptr, int fd) {
    return _close(fd);
}

int _fstat_r(struct _reent *ptr, int fd, struct stat *st) {
    return _fstat(fd, st);
}

int _isatty_r(struct _reent *ptr, int fd) {
    return _isatty(fd);
}

off_t _lseek_r(struct _reent *ptr, int fd, off_t offset, int whence) {
    return _lseek(fd, offset, whence);
}