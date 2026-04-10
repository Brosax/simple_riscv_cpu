# Basys3 FPGA UART 验证方案设计

## 背景

将 simple_riscv_cpu 部署到 Digilent Basys3 (Xilinx Artix-7 XC7A35T) 上进行硬件验证。通过 USB-UART bridge 将 CPU 输出连接到电脑串口终端，同时用 LED 显示运行状态。

## 目标

最小化改动，先验证 CPU 能在 FPGA 上正常运行并通过 UART 输出字符。

## 硬件平台

| 资源 | 说明 |
|---|---|
| FPGA | Xilinx Artix-7 XC7A35T-CPG236 |
| USB-UART | Basys3 板载 FT2232 USB-JTAG/UART bridge |
| LED | 16 个，用于状态显示 |
| 开关 | 16 个（设计时留出扩展接口，本次最小方案不强制使用） |
| 时钟 | 12MHz 板载晶振 |

## 架构

```
CPU (riscv_core)
  tohost 写 0x80002000
    → host_write_enable (脉冲)
    → host_data_out[31:0] (数据)
           │
           ▼
    UART_TX_MODULE (新增)
      将 8-bit 字符转为 UART 115200 8N1
           │
           ▼
    Basys3 USB-UART TX 引脚 → PC 串口终端
```

### LED 状态
- **正常运行**：16 个 LED 流水灯效果（每次时钟 cycles 切换一次）
- **出错停止**：LED 停止流水，低 4 位显示错误码

## 新增文件

| 文件路径 | 说明 |
|---|---|
| `rtl/uart_tx.v` | UART 发射模块，115200 bps，8N1 |
| `rtl/basys3_top.v` | FPGA 顶层，例化 riscv_core + uart_tx |
| `constraints/basys3.xdc` | Xilinx 约束文件，引脚分配 |

### 修改文件

| 文件路径 | 修改内容 |
|---|---|
| `rtl/riscv_core.v` | 确认 host_write_enable / host_data_out 信号存在 |

## 模块设计

### 1. uart_tx.v

- **输入**：`clk`, `rst_n`, `tx_enable`, `tx_data[7:0]`
- **输出**：`uart_tx`, `tx_done`
- **行为**：
  - 检测 `tx_enable` 上升沿，开始发送
  - 115200 bps，8N1（8 数据位，1 停止位，无校验位）
  - 发送完成后 `tx_done` 拉高一个周期
  - 空闲时 `uart_tx` 保持 1（mark）

### 2. basys3_top.v

- **输入**：`clk_12m` (12MHz 时钟), `uart_rx` (预留，未来扩展)
- **输出**：`uart_tx`, `led[15:0]`
- **内部连接**：
  - 例化 `riscv_core`
  - 例化 `uart_tx`
  - `uart_tx.tx_data` ← `riscv_core.host_data_out[7:0]`
  - `uart_tx.tx_enable` ← `riscv_core.host_write_enable`
  - `led[15:0]` 由内部计数器驱动（流水灯 + 错误状态）

### 3. basys3.xdc

引脚分配（基于 Basys3 原理图）：

| 信号 | FPGA 引脚 | 说明 |
|---|---|---|
| `clk_12m` | W5 | 12MHz 时钟输入 |
| `uart_tx` | V15 | USB-UART TX |
| `led[0]` | H17 | LED0 |
| `led[1]` | K15 | LED1 |
| ... | ... | 其余 LED |
| `uart_rx` | V13 | USB-UART RX（预留） |

时钟约束：12MHz 输入，时序路径由 Vivado 自动约束。

## 测试程序（sw/test_hello.c）

简单 RISC-V C 程序或汇编，循环输出字符：

```c
// 伪代码
int main() {
    volatile int *tohost = (int *)0x80002000;
    char msg[] = "Hello FPGA!\n";
    while (1) {
        for (int i = 0; i < 13; i++) {
            *tohost = msg[i];  // 触发 host_write_enable
        }
    }
}
```

编译方式：使用 riscv-gnu-toolchain 编译为 ELF，用 objcopy 提取.text 段为 hex/mem 格式。

## 验证步骤

1. `make build` 综合 RTL（Vivado）
2. 生成 bitstream 下载到 Basys3
3. PC 端用 PuTTY/Xshell 打开对应 COM 口，波特率 115200
4. 观察串口是否输出字符
5. 观察 LED 是否流水灯效果
6. 如果程序出错，LED 停止流水显示错误码

## 扩展方向（本次最小方案不包含）

- UART_RX 接收PC指令控制CPU（暂停/恢复/单步）
- 7 段显示显示数值
- GPIO 映射到开关输入
- 更大程序（riscv-tests 加载）
