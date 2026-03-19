# Scripts and Justfile 使用指南

本项目已优化脚本配置，使用 **justfile** 统一管理所有构建、运行、测试任务。

## 快速开始

### 1. 查看可用命令

```bash
just help
# 或
just
```

### 2. 完整构建流程

```bash
# 构建 Docker 镜像
just build

# 导出编译好的二进制文件
just export

# 检查构建状态
just check-build
```

或一键完成：

```bash
just all
```

## 常用命令

### 构建相关

| 命令 | 说明 |
|------|------|
| `just build` | 构建 Docker 镜像 |
| `just build-nocache` | 不使用缓存构建 |
| `just export` | 导出编译的二进制文件 |
| `just check-build` | 检查构建状态 |
| `just all` | 完整构建流程 |
| `just rebuild` | 从零开始重新构建 |

### 运行相关

| 命令 | 说明 |
|------|------|
| `just run` | 启动 llama-server |
| `just run-cli` | 启动交互式 llama-cli |

### 性能测试

| 命令 | 说明 |
|------|------|
| `just bench` | 运行性能基准测试 |
| `just profile` | 使用 rocprofv3 进行性能分析 |
| `just test` | 运行基本测试套件 |

### 清理

| 命令 | 说明 |
|------|------|
| `just clean` | 清理构建产物 |
| `just clean-all` | 清理构建产物和 Docker 镜像 |

## 环境变量配置

可以通过环境变量自定义行为：

```bash
# 指定 llama.cpp 分支/标签
LLAMA_CPP_REF=mybranch just build

# 指定导出目录
LLAMA_EXPORT_DIR=/custom/path just export

# 指定基准测试用的模型
BENCH_MODEL=/path/to/model.gguf just bench

# 指定基准测试的序列长度
just bench -- --seq-lens 2048,4096,8192
```

## 脚本详解

### 脚本目录结构

```
scripts/
├── build-docker.sh      # Docker 镜像构建脚本
├── export-binary.sh     # 二进制导出脚本
├── run-server.sh        # llama-server 启动脚本
├── run-cli.sh          # llama-cli 启动脚本
├── benchmark.sh        # 性能基准测试脚本
├── profile.sh          # rocprofv3 性能分析脚本
└── test.sh             # 基本测试脚本
```

### 脚本特点

- **参数化设计**: 所有脚本都支持命令行参数，便于集成和自定义
- **环境隔离**: 每个脚本都设置必要的环境变量（如 `LD_LIBRARY_PATH`）
- **错误处理**: 使用 `set -euo pipefail` 确保错误快速失败
- **日志输出**: 清晰的进度提示和错误信息

### 脚本用法示例

```bash
# 直接使用脚本（需要指定所有参数）
./scripts/run-server.sh \
    --binary-dir ./target/bin \
    --model ./models/model.gguf \
    --export-dir ./target \
    --port 8000

# 通过 justfile 使用（参数自动处理）
just run
```

## 高级用法

### 自定义模型路径

编辑 `justfile` 中的 `MODEL_PATH` 变量：

```makefile
MODEL_PATH := PROJECT_ROOT / "models" / "your-model.gguf"
```

### 自定义服务器参数

编辑 `scripts/run-server.sh` 中的 llama-server 命令行参数：

```bash
exec "$BINARY_DIR/llama-server" \
    -m "$MODEL_PATH" \
    -ngl 999 \
    -c 131072 \
    # ... 其他参数
```

### 添加新的 just 命令

编辑 `justfile`，添加新的任务：

```makefile
# 自定义任务示例
my-task:
    @echo "Running my task..."
    @./scripts/custom-script.sh
```

## 环境要求

- **podman** 或 **docker** - 用于容器构建
- **just** - 命令执行器
- **bash** - 脚本运行时
- **ROCm** 工具链（仅用于性能分析）

## 安装 just

```bash
# Fedora/RHEL
sudo dnf install just

# Ubuntu/Debian
sudo apt install just

# macOS
brew install just

# 或从源码编译
cargo install just
```

## 故障排除

### 问题：`just: command not found`

**解决方案**: 安装 just（见上文）

### 问题：二进制文件未找到

**解决方案**: 确保先运行 `just build && just export`

### 问题：模型文件不存在

**解决方案**: 将模型放在 `./models/` 目录，或通过环境变量指定路径

### 问题：权限拒绝

**解决方案**: 检查脚本是否有执行权限

```bash
chmod +x scripts/*.sh
```
