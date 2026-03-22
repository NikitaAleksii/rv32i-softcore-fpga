// Hardware driver for UART that directly talks to the hardware registers

#include "uart.h"

#define UART_TX   (* (volatile uint32_t *) 0x10000000)
#define UART_STAT (* (volatile uint32_t *) 0x10000004)
#define UART_RX   (* (volatile uint32_t *) 0x10000008)

// Status bits
#define UART_TX_BUSY (1u << 0)
#define UART_RX_EMPTY (1u << 1)
#define UART_RX_FULL (1u << 2)
#define UART_TX_EMPTY (1u << 3)
#define UART_TX_FULL (1u << 4)

int _write(int fildes, const void *buf, size_t nbyte) {
    if (fildes != STDOUT_FILENO && fildes != STDERR_FILENO)
        return -1;
    
    const uint8_t *p = buf;

    for (size_t i = 0; i < nbyte; i++){
        while(UART_STAT & UART_TX_FULL);
        UART_TX = p[i];
    }

    return (int) nbyte;
}

int _read(int fildes, void *buf, size_t nbyte){
    if (fildes != STDIN_FILENO)
        return -1;
    
    if (nbyte == 0)
        return 0;

    uint8_t *p = buf;
    size_t i = 0;

    while (i < nbyte) {
        if (UART_STAT & UART_RX_EMPTY) {
            if (i == 0)
                continue;
            
            // Return partial 
            break;
        }
        p[i++] = (uint8_t) UART_RX;
    }

    return (int) i;
}