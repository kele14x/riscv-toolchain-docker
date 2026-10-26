#include <stdint.h>

int main(void)
{
    volatile uint32_t left = 20;
    volatile uint32_t right = 22;
    uint32_t result = left + right;

    return result == 42 ? 0 : 1;
}
