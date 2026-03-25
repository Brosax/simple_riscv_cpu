git clone https://github.com/Brosax/simple_riscv_cpu.git

git submodule update --init  //para los submodulo de testing

---

## 🐳 Docker 仿真环境

本仓库提供完整的容器化仿真环境，无需在本机安装 iverilog / cocotb / pyuvm。

### 前提条件

- 安装 [Docker](https://docs.docker.com/get-docker/) 和 [Docker Compose](https://docs.docker.com/compose/install/)

### 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/Brosax/simple_riscv_cpu.git
cd simple_riscv_cpu

# 2. 构建镜像（首次约需 2–5 分钟）
docker compose build

# 3. 进入交互式开发 shell
docker compose run --rm sim

# 4. 在容器内运行 JTAG pyUVM 仿真
make -C tb/uvm sim
```

### 常用命令

| 命令 | 说明 |
|---|---|
| `docker compose run --rm sim` | 启动交互式 shell |
| `docker compose run --rm sim make -C tb/uvm sim` | 直接运行 pyUVM 仿真 |
| `docker compose run --rm sim make -C tb/uvm waves` | 运行仿真并打开 GTKWave（需 X11） |
| `docker compose build --no-cache` | 强制重新构建镜像 |

### 仿真目录结构

```
tb/uvm/
├── tb_top.v             # Verilog DUT 包装器
├── jtag_transaction.py  # UVMSequenceItem
├── jtag_driver.py       # UVMDriver（TCK/TMS/TDI 时序）
├── jtag_monitor.py      # UVMMonitor（采样 TDO）
├── jtag_scoreboard.py   # UVMScoreboard（IDCODE / BYPASS 验证）
├── jtag_agent.py        # UVMAgent
├── jtag_env.py          # UVMEnv
├── jtag_sequence.py     # 测试序列（IDCODE / BYPASS / Full）
├── jtag_test.py         # UVMTest + cocotb 入口
├── Makefile             # make sim / make waves
└── requirements.txt     # pyuvm>=2.9.0, cocotb>=1.8.0
```

### CI / GitHub Actions

每次 `git push` 或 Pull Request 都会自动触发 GitHub Actions：
1. 构建 Docker 镜像（带 layer 缓存）
2. 在容器内运行 `make sim`
3. 上传波形 `.vcd` 和 `results.xml` 作为 Artifact（保留 7 天）

CI 状态徽章：
![CI](https://github.com/Brosax/simple_riscv_cpu/actions/workflows/sim.yml/badge.svg)
