#define UART_TX   (*(volatile unsigned int *) 0x10000000)
#define UART_STAT (*(volatile unsigned int *) 0x10000004)
#define UART_RX   (*(volatile unsigned int *) 0x10000008)

void uart_putc(char c){
    while (UART_STAT & 0x1);
    UART_TX = (unsigned int) c;
}

void uart_puts(const char *s){
    while (*s){
        uart_putc(*s++);
    }
}

char uart_getc(void){
    while (!(UART_STAT >> 1 & 0x1));
    return (char) UART_RX;
}