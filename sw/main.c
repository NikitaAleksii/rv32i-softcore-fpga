#include <stdio.h>

int main() {
    printf("Hello world!\n");
    printf("Type a character:\n");

    while (1) {
        char c = getchar();
        printf("You typed: %c\n", c);
    }

    return 0;
}