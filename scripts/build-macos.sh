#!/bin/bash

# Doubango macOS 自动构建脚本
# 基于 GitHub Actions c-cpp.yml 配置改编
# 使用方法: ./build-macos.sh [android_abi] [enable_debug] [swig_version]

set -e  # 遇到错误立即退出

# 脚本配置参数
ANDROID_ABI="${1:-arm64-v8a}"  # 默认 arm64-v8a
ENABLE_DEBUG="${2:-true}"      # 默认启用调试符号
SWIG_VERSION="${3:-4.1.1}"     # 默认 SWIG 版本
NDK_VERSION="21.0.6113669"     # 固定 NDK 版本

# 环境变量设置
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
export NDK="$ANDROID_NDK_HOME"
export DOUBANGO_SOURCE="$(pwd)"
export DOUBANGO_OUTPUT="$HOME/doubango-build-output"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

# 日志函数
log_info() {
    echo "### [INFO] $1"
}

log_error() {
    echo "### [ERROR] $1" >&2
}

log_warn() {
    echo "### [WARN] $1"
}

# 检查系统要求
check_system_requirements() {
    log_info "检查系统要求..."
    
    # 检查 macOS 版本
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "此脚本仅支持 macOS 系统"
        exit 1
    fi
    
    # 检查 Xcode Command Line Tools
    if ! xcode-select -p &> /dev/null; then
        log_error "请先安装 Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    # 检查 Homebrew
    if ! command -v brew &> /dev/null; then
        log_error "请先安装 Homebrew: https://brew.sh"
        exit 1
    fi
    
    log_info "系统要求检查通过"
}

# 打印构建参数
print_build_parameters() {
    log_info "构建参数"
    echo "Android ABI: $ANDROID_ABI"
    echo "NDK Version: $NDK_VERSION"
    echo "macOS Version: $(sw_vers -productVersion)"
    echo "Debug Symbols: $ENABLE_DEBUG"
    echo "SWIG Version: $SWIG_VERSION"
    echo "Doubango source at: $DOUBANGO_SOURCE"
    echo "Android SDK ROOT: $ANDROID_SDK_ROOT"
    echo "Android NDK HOME: $ANDROID_NDK_HOME"
    echo "Current user: $(whoami)"
    echo "###"
}

# 安装系统依赖
install_system_dependencies() {
    log_info "安装系统依赖..."
    
    # 使用 Homebrew 安装依赖包
    brew update
    
    # 安装编译工具
    brew install \
        autoconf \
        automake \
        libtool \
        pkg-config \
        make \
        wget \
        unzip \
        python3 \
        openjdk@11 \
        openssl \
        pcre2 || log_warn "某些包可能已经安装"
    
    # 设置 Java 环境
    export JAVA_HOME=$(/usr/libexec/java_home -v 11)
    export PATH="$JAVA_HOME/bin:$PATH"
    
    # 创建 python 软链接（如果不存在）
    if ! command -v python &> /dev/null; then
        ln -sf $(which python3) /usr/local/bin/python || sudo ln -sf $(which python3) /usr/local/bin/python
    fi
    
    # 验证安装
    log_info "验证依赖安装..."
    autoconf --version | head -n 1
    automake --version | head -n 1
    make --version | head -n 1
    clang++ --version | head -n 1
    java -version
    
    log_info "系统依赖安装完成"
}

# 从源码安装 SWIG
install_swig_from_source() {
    log_info "从源码安装 SWIG $SWIG_VERSION..."
    
    # 检查是否已安装正确版本
    if command -v swig &> /dev/null; then
        CURRENT_SWIG_VERSION=$(swig -version | head -n 1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        if [[ "$CURRENT_SWIG_VERSION" == "$SWIG_VERSION" ]]; then
            log_info "SWIG $SWIG_VERSION 已经安装"
            return 0
        fi
    fi
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 下载并编译 SWIG
    log_info "下载 SWIG $SWIG_VERSION..."
    wget "https://github.com/swig/swig/archive/refs/tags/v${SWIG_VERSION}.tar.gz"
    tar xzf "v${SWIG_VERSION}.tar.gz"
    cd "swig-${SWIG_VERSION}"
    
    # 配置和编译
    log_info "配置并编译 SWIG..."
    ./autogen.sh
    ./configure --prefix=/usr/local
    make -j$(sysctl -n hw.ncpu)
    sudo make install
    
    # 验证安装
    swig -version | head -n 1
    log_info "SWIG 安装位置: $(which swig)"
    
    # 清理临时文件
    cd "$DOUBANGO_SOURCE"
    rm -rf "$TEMP_DIR"
    
    log_info "SWIG 安装完成"
}

# 设置 Android SDK 和 NDK
setup_android_sdk_ndk() {
    log_info "设置 Android SDK 和 NDK..."
    
    # 创建 SDK 目录
    mkdir -p "$ANDROID_SDK_ROOT"
    
    # 检查是否已有 cmdline-tools
    if [[ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]]; then
        log_info "下载 Android Command Line Tools..."
        cd "$ANDROID_SDK_ROOT"
        wget https://dl.google.com/android/repository/commandlinetools-mac-9477386_latest.zip -O cmdline-tools.zip
        unzip cmdline-tools.zip
        mkdir -p cmdline-tools
        mv cmdline-tools cmdline-tools/latest 2>/dev/null || mv tools cmdline-tools/latest
        rm -f cmdline-tools.zip
    fi
    
    # 设置环境变量
    export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    
    # 接受许可协议
    log_info "接受 Android SDK 许可协议..."
    yes | sdkmanager --licenses > /dev/null 2>&1 || true
    
    # 安装平台工具
    log_info "安装 Android 平台工具..."
    sdkmanager "platform-tools"
    
    # 检查并安装 NDK
    if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
        log_info "安装 Android NDK $NDK_VERSION..."
        sdkmanager "ndk;$NDK_VERSION"
    else
        log_info "NDK $NDK_VERSION 已经安装"
    fi
    
    # 验证 NDK 安装
    log_info "验证 NDK 安装..."
    echo "ANDROID_NDK_HOME 应为: $ANDROID_NDK_HOME"
    if [[ -d "$ANDROID_NDK_HOME" ]]; then
        echo "NDK 目录存在"
        "$ANDROID_NDK_HOME/ndk-build" --version
    else
        log_error "NDK 未安装在预期位置!"
        echo "检查 NDK 安装目录:"
        ls -la "$ANDROID_SDK_ROOT/ndk/" || true
        exit 1
    fi
    
    # 检查关键文件
    TOOLCHAIN_SCRIPT="$ANDROID_NDK_HOME/build/tools/make-standalone-toolchain.sh"
    echo "检查 make-standalone-toolchain.sh: $TOOLCHAIN_SCRIPT"
    
    if [[ -f "$TOOLCHAIN_SCRIPT" ]]; then
        echo "make-standalone-toolchain.sh 找到"
        chmod +x "$TOOLCHAIN_SCRIPT"
    else
        log_error "make-standalone-toolchain.sh 未找到!"
        ls -la "$ANDROID_NDK_HOME/build/tools/" || true
        exit 1
    fi
    
    # 输出 NDK 环境变量状态
    echo "最终 NDK 环境变量:"
    echo "ANDROID_NDK_HOME = $ANDROID_NDK_HOME"
    echo "NDK = $NDK"
    
    log_info "Android SDK 和 NDK 设置完成"
}

# 准备 NDK 工具链
prepare_ndk_toolchains() {
    log_info "准备 NDK 工具链..."
    
    # NDK 21+ 已经不需要创建符号链接了，但为了兼容性保留检查
    TOOLCHAIN_DIR="$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin"
    if [[ -d "$TOOLCHAIN_DIR" ]]; then
        log_info "NDK 工具链目录存在: $TOOLCHAIN_DIR"
    else
        log_warn "NDK 工具链目录不存在，可能需要检查 NDK 版本"
    fi
    
    log_info "NDK 工具链准备完成"
}

# 配置和构建 Doubango
configure_and_build_doubango() {
    log_info "配置和构建 Doubango..."
    
    cd "$DOUBANGO_SOURCE"
    
    # 输出 NDK 环境变量状态
    echo "构建前 NDK 环境变量:"
    echo "NDK = $NDK"
    echo "ANDROID_NDK_HOME = $ANDROID_NDK_HOME"
    
    # 检查关键文件
    TOOLCHAIN_SCRIPT="$NDK/build/tools/make-standalone-toolchain.sh"
    echo "验证文件存在: $TOOLCHAIN_SCRIPT"
    ls -l "$TOOLCHAIN_SCRIPT" || true
    
    # 运行 autogen 脚本序列
    log_info "运行 autogen 脚本..."
    ./autogen.sh
    
    cd bindings
    ./autogen.sh
    cd ..
    
    # 执行 Android 构建脚本
    log_info "执行 Android 构建脚本..."
    ./android_build.sh
    
    log_info "Doubango 构建完成"
}

# 收集构建产物
collect_artifacts() {
    log_info "收集构建产物..."
    
    # 创建输出目录
    mkdir -p "$DOUBANGO_OUTPUT"
    
    # 复制编译产物
    if [[ -d "$DOUBANGO_SOURCE/android-projects/output/gpl/imsdroid/libs" ]]; then
        cp -r "$DOUBANGO_SOURCE/android-projects/output/gpl/imsdroid/libs/"* "$DOUBANGO_OUTPUT/"
    else
        log_warn "未找到预期的构建产物目录"
        echo "尝试查找其他可能的输出目录..."
        find "$DOUBANGO_SOURCE" -name "*.so" -o -name "*.a" | head -20
    fi
    
    # 验证编译结果
    log_info "验证编译结果..."
    find "$DOUBANGO_OUTPUT" -name "*.so" -o -name "*.a" | while read file; do
        ls -lh "$file"
    done
    
    # 创建构建信息文件
    BUILD_INFO="$DOUBANGO_OUTPUT/build-info.txt"
    echo "Doubango macOS Build Report" > "$BUILD_INFO"
    echo "Build Date: $(date)" >> "$BUILD_INFO"
    echo "Android ABI: $ANDROID_ABI" >> "$BUILD_INFO"
    echo "NDK Version: $NDK_VERSION" >> "$BUILD_INFO"
    echo "macOS Version: $(sw_vers -productVersion)" >> "$BUILD_INFO"
    echo "Debug Symbols Enabled: $ENABLE_DEBUG" >> "$BUILD_INFO"
    echo "SWIG Version: $SWIG_VERSION" >> "$BUILD_INFO"
    echo "PCRE2 Version: $(pcre2-config --version 2>/dev/null || echo 'N/A')" >> "$BUILD_INFO"
    "$ANDROID_NDK_HOME/ndk-build" --version >> "$BUILD_INFO"
    echo "make-standalone-toolchain.sh: $(ls -l $NDK/build/tools/make-standalone-toolchain.sh)" >> "$BUILD_INFO"
    echo "NDK环境变量: $NDK" >> "$BUILD_INFO"
    echo "构建主机: $(hostname)" >> "$BUILD_INFO"
    
    log_info "构建产物收集完成，保存在: $DOUBANGO_OUTPUT"
}

# 生成构建摘要
generate_build_summary() {
    log_info "生成构建摘要..."
    
    echo ""
    echo "=== Doubango macOS 构建报告 ==="
    echo "Android ABI: $ANDROID_ABI"
    echo "NDK 版本: $NDK_VERSION"
    echo "macOS 版本: $(sw_vers -productVersion)"
    echo "调试符号: $ENABLE_DEBUG"
    echo "SWIG 版本: $SWIG_VERSION"
    echo "构建时间: $(date)"
    echo ""
    echo "NDK 环境变量:"
    echo "ANDROID_NDK_HOME = $ANDROID_NDK_HOME"
    echo "NDK = $NDK"
    echo ""
    echo "包含的库文件:"
    find "$DOUBANGO_OUTPUT" -name "*.so" -o -name "*.a" | sort
    echo ""
    echo "构建产物位置: $DOUBANGO_OUTPUT"
    echo "================================"
}

# 清理函数
cleanup() {
    log_info "清理临时文件..."
    # 在这里添加任何需要清理的内容
}

# 主函数
main() {
    log_info "开始 Doubango macOS 构建脚本"
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    # 执行构建步骤
    print_build_parameters
    check_system_requirements
    install_system_dependencies
    install_swig_from_source
    setup_android_sdk_ndk
    prepare_ndk_toolchains
    configure_and_build_doubango
    collect_artifacts
    generate_build_summary
    
    log_info "Doubango macOS 构建完成!"
    echo ""
    echo "构建产物保存在: $DOUBANGO_OUTPUT"
    echo "构建信息文件: $DOUBANGO_OUTPUT/build-info.txt"
}

# 显示使用帮助
show_help() {
    echo "Doubango macOS 自动构建脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [android_abi] [enable_debug] [swig_version]"
    echo ""
    echo "参数:"
    echo "  android_abi   : Android ABI (armeabi-v7a, arm64-v8a, x86, x86_64) [默认: arm64-v8a]"
    echo "  enable_debug  : 启用调试符号 (true/false) [默认: true]"
    echo "  swig_version  : SWIG 版本 (如: 4.1.1) [默认: 4.1.1]"
    echo ""
    echo "示例:"
    echo "  $0                           # 使用默认参数"
    echo "  $0 arm64-v8a true 4.1.1     # 指定所有参数"
    echo "  $0 armeabi-v7a false         # 指定前两个参数"
    echo ""
    echo "环境要求:"
    echo "  - macOS 10.15 或更高版本"
    echo "  - Xcode Command Line Tools"
    echo "  - Homebrew"
    echo "  - 至少 8GB 可用磁盘空间"
}

# 检查帮助参数
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 运行主函数
main "$@"
