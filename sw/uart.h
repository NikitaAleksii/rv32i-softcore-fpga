#ifndef UART_H
#define UART_H

#include <stdint.h>
#include <sys/types.h>

#define STDIN_FILENO 0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

extern int _write(int fildes, const void *buf, size_t nbyte);
extern int _read(int fildes, void *buf, size_t nbyte);

#endif