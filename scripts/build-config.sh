# Doubango macOS 构建配置文件
# 可以通过修改此文件来自定义构建选项

# Android 构建配置
ANDROID_ABI="arm64-v8a"                    # 支持: armeabi-v7a, arm64-v8a, x86, x86_64
ENABLE_DEBUG="true"                        # 启用调试符号: true/false
NDK_VERSION="21.0.6113669"                 # Android NDK 版本

# 工具版本配置  
SWIG_VERSION="4.1.1"                       # SWIG 版本
JAVA_VERSION="11"                          # Java 版本

# 路径配置
ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
BUILD_OUTPUT_DIR="$HOME/doubango-build-output"

# 构建选项
PARALLEL_JOBS="$(sysctl -n hw.ncpu)"       # 并行编译任务数（默认使用所有CPU核心）
CLEAN_BUILD="false"                        # 是否清理之前的构建: true/false
VERBOSE_BUILD="false"                      # 详细构建日志: true/false

# 依赖包配置（Homebrew）
BREW_PACKAGES=(
    "autoconf"
    "automake" 
    "libtool"
    "pkg-config"
    "make"
    "wget"
    "unzip"
    "python3"
    "openjdk@11"
    "openssl"
    "pcre2"
)

# 可选功能开关
INSTALL_SWIG_FROM_SOURCE="true"            # 是否从源码安装SWIG: true/false (false则使用brew安装)
SKIP_DEPENDENCIES_CHECK="false"           # 跳过依赖检查: true/false
AUTO_ACCEPT_LICENSES="true"                # 自动接受Android SDK许可: true/false

# 构建后操作
CREATE_ARCHIVE="true"                      # 创建tar.gz压缩包: true/false
ARCHIVE_NAME="doubango-macos-$(date +%Y%m%d-%H%M%S).tar.gz"

# 日志配置
LOG_LEVEL="INFO"                           # 日志级别: DEBUG/INFO/WARN/ERROR
LOG_FILE="$HOME/doubango-build.log"        # 日志文件路径（为空则不保存日志文件）

# 高级选项
CUSTOM_CFLAGS=""                           # 自定义 CFLAGS
CUSTOM_CXXFLAGS=""                         # 自定义 CXXFLAGS  
CUSTOM_LDFLAGS=""                          # 自定义 LDFLAGS
