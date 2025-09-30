#!/bin/bash
# WakaTerm NG Binary Installer
# Automatically detects platform and installs the appropriate binary

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly GITHUB_REPO="QinCai-rui/WakaTerm-NG"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly BINARY_NAME="wakaterm"
readonly CONFIG_DIR="${HOME}/.config/wakaterm"

# Global variables
PLATFORM=""
ARCH=""
DOWNLOAD_URL=""
TEMP_FILE=""

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${BOLD}🔄 $1${NC}"
}

# Platform detection
detect_platform() {
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$os" in
        linux*)
            PLATFORM="linux"
            ;;
        darwin*)
            PLATFORM="macos"
            ;;
        cygwin*|mingw*|msys*)
            PLATFORM="windows"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    log_info "Detected platform: $PLATFORM"
}

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        i386|i686)
            ARCH="x86"
            log_warning "32-bit architecture detected. Consider upgrading to 64-bit."
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    log_info "Detected architecture: $ARCH"
}

# Check if binary already exists
check_existing_installation() {
    if command -v wakaterm >/dev/null 2>&1; then
        local existing_path
        existing_path=$(which wakaterm)
        log_warning "WakaTerm is already installed at: $existing_path"
        
        if [[ "$existing_path" == "$INSTALL_DIR/$BINARY_NAME" ]]; then
            read -p "Do you want to upgrade the existing installation? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled."
                exit 0
            fi
        else
            log_warning "Found WakaTerm in different location. Continuing with installation to $INSTALL_DIR"
        fi
    fi
}

# Create necessary directories
setup_directories() {
    log_step "Setting up directories"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    
    log_success "Directories created"
}

# Download the binary
download_binary() {
    log_step "Downloading WakaTerm binary for $PLATFORM-$ARCH"
    
    # Determine binary filename
    local binary_filename="wakaterm-$PLATFORM-$ARCH"
    if [[ "$PLATFORM" == "windows" ]]; then
        binary_filename="${binary_filename}.exe"
    fi
    
    # Construct download URL
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${binary_filename}"
    TEMP_FILE="/tmp/${binary_filename}"
    
    log_info "Download URL: $DOWNLOAD_URL"
    
    # Download using curl or wget
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
            log_success "Binary downloaded successfully"
        else
            log_error "Failed to download binary with curl"
            log_info "Trying to build from source instead..."
            build_from_source
            return
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -O "$TEMP_FILE" "$DOWNLOAD_URL"; then
            log_success "Binary downloaded successfully"
        else
            log_error "Failed to download binary with wget"
            log_info "Trying to build from source instead..."
            build_from_source
            return
        fi
    else
        log_error "Neither curl nor wget found"
        log_info "Trying to build from source instead..."
        build_from_source
        return
    fi
}

# Build from source as fallback
build_from_source() {
    log_step "Building WakaTerm from source"
    
    # Check if Python is available
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 is required to build from source"
        exit 1
    fi
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git is required to build from source"
        exit 1
    fi
    
    # Clone repository
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log_info "Cloning repository..."
    git clone "https://github.com/${GITHUB_REPO}.git" wakaterm
    cd wakaterm
    
    # Install dependencies and build
    log_info "Installing build dependencies..."
    python3 -m pip install --user -r requirements.txt
    
    log_info "Building binary..."
    python3 build.py
    
    # Copy the built binary
    local binary_pattern="binaries/wakaterm-$PLATFORM-$ARCH"
    if [[ "$PLATFORM" == "windows" ]]; then
        binary_pattern="${binary_pattern}.exe"
    fi
    
    if compgen -G "$binary_pattern" > /dev/null; then
        local files=($binary_pattern)
        TEMP_FILE="$temp_dir/wakaterm/${files[0]}"
        log_success "Binary built successfully"
    else
        log_error "Failed to build binary"
        exit 1
    fi
}

# Install the binary
install_binary() {
    log_step "Installing WakaTerm binary"
    
    local install_path="$INSTALL_DIR/$BINARY_NAME"
    if [[ "$PLATFORM" == "windows" ]]; then
        install_path="${install_path}.exe"
    fi
    
    # Copy binary to install directory
    cp "$TEMP_FILE" "$install_path"
    chmod +x "$install_path"
    
    log_success "WakaTerm installed to: $install_path"
}

# Verify installation
verify_installation() {
    log_step "Verifying installation"
    
    local install_path="$INSTALL_DIR/$BINARY_NAME"
    
    # Test if binary works
    if "$install_path" --help >/dev/null 2>&1; then
        log_success "Installation verified successfully"
    else
        log_error "Installation verification failed"
        exit 1
    fi
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "Install directory $INSTALL_DIR is not in PATH"
        echo ""
        log_info "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo -e "${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
        log_info "Or run wakaterm directly: $install_path"
    else
        log_info "You can now run: wakaterm --help"
    fi
}

# Cleanup temporary files
cleanup() {
    if [[ -n "${TEMP_FILE:-}" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi
}

# Main installation function
main() {
    echo -e "${BLUE}${BOLD}"
    echo "🚀 WakaTerm NG Binary Installer"
    echo "==============================="
    echo -e "${NC}"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Detection phase
    detect_platform
    detect_architecture
    
    # Pre-installation checks
    check_existing_installation
    setup_directories
    
    # Download and install
    download_binary
    install_binary
    verify_installation
    
    echo ""
    log_success "WakaTerm NG installation completed!"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure WakaTime: wakaterm --help"
    echo "  2. Set up shell integration (see README.md)"
    echo "  3. Start tracking your terminal activity!"
    echo ""
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi