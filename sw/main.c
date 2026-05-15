#include <stdio.h>
#include <stdlib.h>

void calculate_fibonacci_helper(int* nums, int number){
    nums[0] = 0;
    nums[1] = 1;
    for (int i = 2; i <= number; i++) {
        nums[i] = nums[i-1] + nums[i-2];
    }
}

int calculate_fibonacci(int num) {
    if (num == 0) return 0;
    if (num == 1) return 1;

    int *nums = (int *) malloc ((num + 1) * sizeof(int));
    calculate_fibonacci_helper(nums, num);
    int number = nums[num];
    free(nums);
    return number;
}

int main() {
    for (int i = 1; i <= 45; i++){
        printf("%d ", calculate_fibonacci(i));
        fflush(stdout);
    }
    return 0;
}