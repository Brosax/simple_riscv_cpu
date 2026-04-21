#include <stdint.h>
#include <stddef.h>
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"

// GCC 内置的可变参数宏（完美绕过 #include <stdarg.h> 的缺失）
typedef __builtin_va_list va_list;
#define va_start(v,l) __builtin_va_start(v,l)
#define va_end(v)     __builtin_va_end(v)
#define va_arg(v,l)   __builtin_va_arg(v,l)

// 内存映射的 I/O 地址
#define UART_TX         ((volatile uint32_t *) 0x80002000)

SemaphoreHandle_t xUartMutex = NULL;

void uart_putc(char c) {
    *UART_TX = c;
    for (volatile int i = 0; i < 5000; i++) {
        // 空循环，消耗 CPU 周期，等待硬件把字发完
        // 12.5MHz clk / 115200 = 109 cycles per bit -> ~1100 cycles per char.
        // multi-cycle FSM makes this even safer. We use 5000 to be very safe.
    }
}

void uart_puts(const char *s) {
    if (xUartMutex != NULL) {
        xSemaphoreTake(xUartMutex, portMAX_DELAY);
    }
    while (*s) {
        uart_putc(*s++);
    }
    if (xUartMutex != NULL) {
        xSemaphoreGive(xUartMutex);
    }
}

void *memset(void *s, int c, size_t n) {
    unsigned char *p = s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}

void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = dest;
    const unsigned char *s = src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

// Dummy handler for FreeRTOS timer setup
void vApplicationSetupTimerInterrupt(void) {
    // The config parameters configMTIME_BASE_ADDRESS and configMTIMECMP_BASE_ADDRESS
    // are already defined in FreeRTOSConfig.h and the FreeRTOS RISC-V port will use them.
}

void Task1(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        uart_puts("Task 1 is running\n");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void Task2(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        uart_puts("Task 2 is running\n");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

// ---------------------------------------------------------
// 2. 极简版 printf 实现
// ---------------------------------------------------------

// 纯软件实现除以 10 和取余（因为 rv32i 没有硬件除法，且编译禁用了 stdlib）
uint32_t udivmod10(uint32_t num, uint32_t *rem) {
    uint32_t q = 0;
    uint32_t r = 0;
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((num >> i) & 1);
        if (r >= 10) {
            r -= 10;
            q |= (1U << i);
        }
    }
    *rem = r;
    return q;
}

void print_int(int num) {
    if (num == 0) {
        uart_putc('0');
        return;
    }
    uint32_t unum;
    if (num < 0) {
        uart_putc('-');
        unum = -num;
    } else {
        unum = num;
    }
    
    char buf[12];
    int i = 0;
    while (unum > 0) {
        uint32_t rem;
        unum = udivmod10(unum, &rem);
        buf[i++] = rem + '0';
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

void print_hex(uint32_t num) {
    uart_puts("0x");
    if (num == 0) {
        uart_putc('0');
        return;
    }
    char buf[8];
    int i = 0;
    while (num > 0) {
        int rem = num & 0xF; // 替换 % 16，使用位运算
        buf[i++] = (rem < 10) ? (rem + '0') : (rem - 10 + 'a');
        num >>= 4;           // 替换 / 16，使用位运算
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

// 支持 %d (整数), %x (十六进制), %s (字符串), %c (字符)
void printf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    
    while (*format) {
        if (*format == '%') {
            format++;
            if (*format == 'd') {
                int i = va_arg(args, int);
                print_int(i);
            } else if (*format == 's') {
                char *s = va_arg(args, char *);
                uart_puts(s);
            } else if (*format == 'x') {
                uint32_t x = va_arg(args, uint32_t);
                print_hex(x);
            } else if (*format == 'c') {
                char c = (char)va_arg(args, int);
                uart_putc(c);
            } else if (*format == '%') {
                uart_putc('%');
            }
        } else {
            uart_putc(*format);
        }
        format++;
    }
    va_end(args);
}

int main() {
    // 初始化串口 Mutex
    xUartMutex = xSemaphoreCreateMutex();

    uart_puts("Starting FreeRTOS\n");

    xTaskCreate(Task1, "Task1", configMINIMAL_STACK_SIZE, NULL, 1, NULL);
    xTaskCreate(Task2, "Task2", configMINIMAL_STACK_SIZE, NULL, 1, NULL);

    vTaskStartScheduler();

    for (;;);
    return 0;
}
