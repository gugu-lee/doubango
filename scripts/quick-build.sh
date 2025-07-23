#!/bin/bash

# Doubango macOS 快速构建脚本
# 简化版本，用于快速构建和测试

set -e

# 基本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_CONFIG="$SCRIPT_DIR/build-config.sh"

# 加载配置文件
if [[ -f "$BUILD_CONFIG" ]]; then
    source "$BUILD_CONFIG"
    echo "已加载配置文件: $BUILD_CONFIG"
else
    echo "警告: 配置文件不存在，使用默认设置"
    ANDROID_ABI="${1:-arm64-v8a}"
    ENABLE_DEBUG="${2:-true}"
fi

# 快速检查函数
quick_check() {
    echo "=== 快速环境检查 ==="
    
    # 检查 macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "错误: 仅支持 macOS"
        exit 1
    fi
    
    # 检查必要工具
    local missing_tools=()
    
    if ! command -v brew &> /dev/null; then
        missing_tools+=("Homebrew")
    fi
    
    if ! xcode-select -p &> /dev/null; then
        missing_tools+=("Xcode Command Line Tools")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "错误: 缺少必要工具:"
        printf '  - %s\n' "${missing_tools[@]}"
        echo ""
        echo "安装方法:"
        echo "  Homebrew: https://brew.sh"
        echo "  Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    
    echo "✓ 环境检查通过"
}

# 快速安装依赖
quick_install_deps() {
    echo "=== 安装依赖 ==="
    
    # 安装基本依赖
    echo "安装 Homebrew 包..."
    brew install autoconf automake libtool pkg-config wget unzip python3 openjdk@11 openssl pcre2 2>/dev/null || true
    
    # 设置 Java 环境
    export JAVA_HOME=$(/usr/libexec/java_home -v 11 2>/dev/null || echo "/usr/local/opt/openjdk@11")
    export PATH="$JAVA_HOME/bin:$PATH"
    
    # 安装 SWIG
    if ! command -v swig &> /dev/null; then
        echo "安装 SWIG..."
        brew install swig
    fi
    
    echo "✓ 依赖安装完成"
}

# 设置 Android 环境
setup_android() {
    echo "=== 设置 Android 环境 ==="
    
    export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
    export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/${NDK_VERSION:-21.0.6113669}"
    export NDK="$ANDROID_NDK_HOME"
    export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"
    
    # 检查 Android SDK
    if [[ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]]; then
        echo "设置 Android SDK..."
        mkdir -p "$ANDROID_SDK_ROOT"
        cd "$ANDROID_SDK_ROOT"
        
        # 下载 cmdline-tools
        wget -q https://dl.google.com/android/repository/commandlinetools-mac-9477386_latest.zip -O cmdline-tools.zip
        unzip -q cmdline-tools.zip
        mkdir -p cmdline-tools
        mv cmdline-tools cmdline-tools/latest 2>/dev/null || mv tools cmdline-tools/latest
        rm -f cmdline-tools.zip
        
        # 接受许可并安装 NDK
        yes | sdkmanager --licenses > /dev/null 2>&1 || true
        sdkmanager "platform-tools" "ndk;${NDK_VERSION:-21.0.6113669}" > /dev/null
    fi
    
    if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
        echo "错误: NDK 未正确安装"
        exit 1
    fi
    
    echo "✓ Android 环境设置完成"
    echo "  SDK: $ANDROID_SDK_ROOT"
    echo "  NDK: $ANDROID_NDK_HOME"
}

# 构建 Doubango
build_doubango() {
    echo "=== 构建 Doubango ==="
    
    cd "$PROJECT_ROOT"
    
    # 运行 autogen
    echo "运行 autogen 脚本..."
    ./autogen.sh > /dev/null
    cd bindings
    ./autogen.sh > /dev/null
    cd ..
    
    # 构建
    echo "开始构建 (ABI: ${ANDROID_ABI})..."
    echo "这可能需要几分钟时间..."
    
    if [[ "${VERBOSE_BUILD:-false}" == "true" ]]; then
        ./android_build.sh
    else
        ./android_build.sh > build.log 2>&1 || {
            echo "构建失败，查看日志:"
            tail -20 build.log
            exit 1
        }
    fi
    
    echo "✓ 构建完成"
}

# 收集结果
collect_results() {
    echo "=== 收集构建结果 ==="
    
    local output_dir="${BUILD_OUTPUT_DIR:-$HOME/doubango-build-output}"
    mkdir -p "$output_dir"
    
    # 查找并复制 .so 和 .a 文件
    if [[ -d "$PROJECT_ROOT/android-projects/output/gpl/imsdroid/libs" ]]; then
        cp -r "$PROJECT_ROOT/android-projects/output/gpl/imsdroid/libs/"* "$output_dir/"
        
        echo "✓ 构建产物已保存到: $output_dir"
        echo ""
        echo "包含的文件:"
        find "$output_dir" -name "*.so" -o -name "*.a" | sort
        
        # 创建压缩包
        if [[ "${CREATE_ARCHIVE:-true}" == "true" ]]; then
            local archive_name="doubango-macos-$(date +%Y%m%d-%H%M%S).tar.gz"
            cd "$(dirname "$output_dir")"
            tar -czf "$archive_name" "$(basename "$output_dir")"
            echo "✓ 压缩包已创建: $(pwd)/$archive_name"
        fi
    else
        echo "警告: 未找到预期的构建产物"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
Doubango macOS 快速构建脚本

用法: $0 [选项]

选项:
    -h, --help          显示此帮助信息
    -v, --verbose       详细输出
    -c, --clean         清理之前的构建
    --abi ABI          指定 Android ABI (默认: arm64-v8a)
    --debug            启用调试模式 (默认: true)
    --config FILE      使用指定的配置文件

示例:
    $0                  # 使用默认设置构建
    $0 --verbose        # 详细输出模式
    $0 --abi armeabi-v7a --debug false  # 指定参数
    
支持的 ABI: armeabi-v7a, arm64-v8a, x86, x86_64

构建产物将保存在: ${BUILD_OUTPUT_DIR:-$HOME/doubango-build-output}
EOF
}

# 主函数
main() {
    local verbose=false
    local clean=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                export VERBOSE_BUILD="true"
                shift
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            --abi)
                ANDROID_ABI="$2"
                shift 2
                ;;
            --debug)
                ENABLE_DEBUG="$2"
                shift 2
                ;;
            --config)
                if [[ -f "$2" ]]; then
                    source "$2"
                    echo "已加载配置: $2"
                else
                    echo "错误: 配置文件不存在: $2"
                    exit 1
                fi
                shift 2
                ;;
            *)
                echo "未知选项: $1"
                echo "使用 -h 查看帮助"
                exit 1
                ;;
        esac
    done
    
    echo "Doubango macOS 快速构建脚本"
    echo "=============================="
    echo "Android ABI: ${ANDROID_ABI}"
    echo "调试模式: ${ENABLE_DEBUG}"
    echo "详细输出: ${verbose}"
    echo "=============================="
    echo ""
    
    # 清理
    if [[ "$clean" == "true" ]]; then
        echo "清理之前的构建..."
        rm -rf "$PROJECT_ROOT/android-projects/output" 2>/dev/null || true
        rm -f "$PROJECT_ROOT/build.log" 2>/dev/null || true
    fi
    
    # 执行构建步骤
    quick_check
    quick_install_deps
    setup_android
    build_doubango
    collect_results
    
    echo ""
    echo "🎉 构建完成!"
    echo ""
    echo "下一步:"
    echo "1. 检查构建产物: ${BUILD_OUTPUT_DIR:-$HOME/doubango-build-output}"
    echo "2. 集成到你的 Android 项目中"
    echo "3. 在 Android Studio 中测试"
}

# 运行主函数
main "$@"
