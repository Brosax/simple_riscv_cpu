# ===========================================================================
# Dockerfile — simple_riscv_cpu 仿真环境
# 基础镜像：Ubuntu 22.04 LTS
# 包含：iverilog（Icarus Verilog）、Python 3.11、cocotb、pyuvm、gtkwave
# ===========================================================================
FROM ubuntu:22.04

# 避免 apt 安装时出现交互式提示（如时区选择）
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. 系统依赖：iverilog、Python 3.11、gtkwave 及构建工具
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        # Icarus Verilog 仿真器
        iverilog \
        # GTKWave 波形查看器（可选，容器内无 GUI，主要供挂载后本地使用）
        gtkwave \
        # Python 3.11 及 pip
        python3.11 \
        python3.11-dev \
        python3-pip \
        # 构建工具（编译 C 扩展用）
        build-essential \
        # 实用工具
        git \
        make \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 将 python3.11 设为默认 python3 / python
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
 && update-alternatives --install /usr/bin/python  python  /usr/bin/python3.11 1

# 升级 pip，避免旧版兼容性问题
RUN python3 -m pip install --upgrade pip

# ---------------------------------------------------------------------------
# 2. Python 依赖：cocotb + pyuvm
# ---------------------------------------------------------------------------
RUN pip3 install --no-cache-dir \
        "cocotb>=1.8.0" \
        "pyuvm>=2.9.0"

# ---------------------------------------------------------------------------
# 3. 工作目录（docker-compose 挂载仓库到此处）
# ---------------------------------------------------------------------------
WORKDIR /workspace

# ---------------------------------------------------------------------------
# 4. 默认命令（可被 docker-compose / docker run 覆盖）
# ---------------------------------------------------------------------------
CMD ["/bin/bash"]
