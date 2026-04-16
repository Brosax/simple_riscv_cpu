typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

// 内存映射的 I/O 地址
#define UART_TX         ((volatile uint32_t *) 0x80002000)
#define MTIME_LOW       ((volatile uint32_t *) 0xFFFF0000)
#define MTIME_HIGH      ((volatile uint32_t *) 0xFFFF0004)
#define MTIMECMP_LOW    ((volatile uint32_t *) 0xFFFF0008)
#define MTIMECMP_HIGH   ((volatile uint32_t *) 0xFFFF000C)

#define CPU_FREQ 12500000
#define TICK_RATE CPU_FREQ  // 每 1 秒触发一次

// GCC 内置的可变参数宏（完美绕过 #include <stdarg.h> 的缺失）
typedef __builtin_va_list va_list;
#define va_start(v,l) __builtin_va_start(v,l)
#define va_end(v)     __builtin_va_end(v)
#define va_arg(v,l)   __builtin_va_arg(v,l)

// ---------------------------------------------------------
// 1. 底层 UART 驱动与精确延时
// ---------------------------------------------------------
void uart_putc(char c) {
    *UART_TX = c;
    // 软件等待：12.5MHz 时钟下，115200 波特率发送一个字符(10 bit)需要 ~1085 个周期。
    // 这里循环一次大概需要几条指令（十几个周期），循环 200 次足够安全。
    for (volatile int i = 0; i < 200; i++) {
        // 空循环，消耗 CPU 周期，等待硬件把字发完
    }
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
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

// ---------------------------------------------------------
// 3. 定时器与中断逻辑
// ---------------------------------------------------------
uint64_t get_mtime() {
    uint32_t hi, lo;
    do {
        hi = *MTIME_HIGH;
        lo = *MTIME_LOW;
    } while (hi != *MTIME_HIGH);
    return ((uint64_t)hi << 32) | lo;
}

void set_mtimecmp(uint64_t time) {
    *MTIMECMP_HIGH = 0xFFFFFFFF;
    *MTIMECMP_LOW = (uint32_t)(time & 0xFFFFFFFF);
    *MTIMECMP_HIGH = (uint32_t)(time >> 32);
}

// 全局变量，记录中断触发的次数
volatile int tick_count = 0;

void __attribute__((interrupt("machine"))) timer_handler() {
    tick_count++;
    
    // 使用我们自己写的 printf 发送格式化字符串！
    printf(">> Interrupt triggered! Timer tick: %d, MTIME: %x\r\n", tick_count, *MTIME_LOW);

    // 重新配置下一次闹钟
    uint64_t current_time = get_mtime();
    set_mtimecmp(current_time + TICK_RATE);
}

int main() {
    // 启动欢迎语
    printf("\r\n=================================\r\n");
    printf("   RISC-V CPU is Booting...      \r\n");
    printf("   printf() implementation OK!   \r\n");
    printf("=================================\r\n");

    // 1. 设置 mtvec 中断向量
    uint32_t trap_addr = (uint32_t)&timer_handler;
    asm volatile("csrw mtvec, %0" : : "r"(trap_addr));

    // 2. 预设第一次闹钟
    uint64_t current_time = get_mtime();
    set_mtimecmp(current_time + TICK_RATE);

    // 3. 开启机器模式定时器中断
    asm volatile("li t0, 0x80"); 
    asm volatile("csrs mie, t0");

    // 4. 开启全局中断
    asm volatile("li t0, 0x8");  
    asm volatile("csrs mstatus, t0");

    printf("Timer initialized. Entering main loop...\r\n");

    // 5. 主循环（死循环假装在处理其他任务）
    while (1) {
        asm volatile("nop");
    }

    return 0;
}
