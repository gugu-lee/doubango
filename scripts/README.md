# Doubango macOS 构建脚本

本目录包含了在 macOS 系统上自动构建 Doubango 项目的脚本，基于原有的 GitHub Actions 配置改编。

## 文件说明

### 脚本文件

- **`build-macos.sh`** - 完整的构建脚本，包含所有功能
- **`quick-build.sh`** - 简化的快速构建脚本，适合日常使用
- **`build-config.sh`** - 构建配置文件，可自定义各种构建选项

### 使用方法

#### 快速开始（推荐）

```bash
# 1. 确保脚本有执行权限
chmod +x scripts/quick-build.sh

# 2. 使用默认设置构建
./scripts/quick-build.sh

# 3. 查看帮助
./scripts/quick-build.sh --help
```

#### 完整构建脚本

```bash
# 1. 确保脚本有执行权限  
chmod +x scripts/build-macos.sh

# 2. 使用默认参数构建
./scripts/build-macos.sh

# 3. 指定参数构建
./scripts/build-macos.sh arm64-v8a true 4.1.1

# 4. 查看帮助
./scripts/build-macos.sh --help
```

## 系统要求

### 必需环境

- **macOS 10.15** 或更高版本
- **Xcode Command Line Tools**
  ```bash
  xcode-select --install
  ```
- **Homebrew**
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

### 磁盘空间

- 至少 **8GB** 可用磁盘空间
- Android SDK: ~3GB
- Android NDK: ~1GB  
- 构建产物: ~500MB
- 临时文件: ~2GB

## 构建选项

### Android ABI 支持

- `armeabi-v7a` - ARM 32位 (兼容性最好)
- `arm64-v8a` - ARM 64位 (默认，推荐)  
- `x86` - x86 32位 (模拟器)
- `x86_64` - x86 64位 (模拟器)

### 调试选项

- `true` - 包含调试符号 (默认)
- `false` - 不包含调试符号 (体积更小)

## 自定义配置

编辑 `scripts/build-config.sh` 文件来自定义构建选项：

```bash
# 修改 Android ABI
ANDROID_ABI="armeabi-v7a"

# 关闭调试符号
ENABLE_DEBUG="false"

# 使用不同的 NDK 版本
NDK_VERSION="23.1.7779620"

# 自定义输出目录
BUILD_OUTPUT_DIR="/path/to/your/output"
```

## 常见用法示例

### 1. 快速构建 (默认 ARM64)

```bash
./scripts/quick-build.sh
```

### 2. 构建 ARM32 版本

```bash
./scripts/quick-build.sh --abi armeabi-v7a
```

### 3. 发布版本构建 (无调试符号)

```bash
./scripts/quick-build.sh --abi arm64-v8a --debug false
```

### 4. 详细输出模式

```bash
./scripts/quick-build.sh --verbose
```

### 5. 清理后重新构建

```bash
./scripts/quick-build.sh --clean --verbose
```

### 6. 使用自定义配置

```bash
# 创建自定义配置
cp scripts/build-config.sh my-config.sh
# 编辑 my-config.sh...

# 使用自定义配置构建
./scripts/quick-build.sh --config my-config.sh
```

## 构建产物

### 默认位置

构建完成后，产物将保存在：
```
$HOME/doubango-build-output/
├── arm64-v8a/           # ARM64 库文件
│   ├── libtinyWRAP.so
│   └── 其他 .so 文件
├── build-info.txt       # 构建信息
└── *.tar.gz            # 压缩包 (可选)
```

### 库文件说明

- **`libtinyWRAP.so`** - 主要的 JNI 包装库
- **`libtinyDAV.so`** - 音视频处理库
- **`libtinySIP.so`** - SIP 协议库
- **`libtinyNET.so`** - 网络通信库
- **其他 .so 文件** - 依赖库

## 故障排除

### 常见问题

#### 1. Homebrew 包安装失败

```bash
# 更新 Homebrew
brew update

# 清理缓存
brew cleanup

# 重新尝试
./scripts/quick-build.sh
```

#### 2. Android SDK 许可问题

```bash
# 手动接受许可
$HOME/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager --licenses
```

#### 3. NDK 版本不兼容

```bash
# 在 build-config.sh 中更改 NDK 版本
NDK_VERSION="23.1.7779620"  # 或其他版本
```

#### 4. 构建失败

```bash
# 使用详细输出查看错误
./scripts/quick-build.sh --verbose

# 检查构建日志
cat build.log
```

#### 5. 磁盘空间不足

```bash
# 清理 Homebrew 缓存
brew cleanup

# 清理 Android SDK 缓存
rm -rf $HOME/Library/Android/sdk/.temp

# 清理之前的构建
./scripts/quick-build.sh --clean
```

### 获取帮助

如果遇到问题，请：

1. 查看详细的构建日志
2. 检查系统要求是否满足
3. 尝试使用 `--clean` 选项重新构建
4. 在项目 Issues 中搜索类似问题

## 性能优化

### 加速构建

1. **使用 SSD 磁盘** - 显著提升 I/O 性能
2. **增加并行任务数** - 在 `build-config.sh` 中设置 `PARALLEL_JOBS`
3. **使用本地缓存** - 避免重复下载依赖

### 减少体积

1. **关闭调试符号** - 设置 `ENABLE_DEBUG="false"`
2. **只构建需要的 ABI** - 指定特定的 `ANDROID_ABI`
3. **使用 ProGuard/R8** - 在 Android 项目中进一步优化

## 版本兼容性

| Doubango | macOS | Android NDK | SWIG |
|----------|-------|-------------|------|
| 最新版本  | 10.15+ | 21.0.6113669 | 4.1.1 |
| 兼容版本  | 10.14+ | 20.1.5948944+ | 4.0.0+ |

## 许可证

这些构建脚本遵循与 Doubango 项目相同的许可证。
