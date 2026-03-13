#include "uart.h"

int main() {
    uart_puts("Hello from RV32I!\n");
    uart_puts("Type a character:\n");

    while (1) {
        char c = uart_getc();
        uart_puts("You typed: ");
        uart_putc(c);
        uart_putc('\n');
    }

    return 0;
}