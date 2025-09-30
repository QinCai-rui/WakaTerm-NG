#!/bin/bash
# WakaTerm NG Binary Installer
# Automatically detects platform and installs the appropriate binaries

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
readonly BINARIES=("wakaterm" "wakatermctl")
readonly CONFIG_DIR="${HOME}/.config/wakaterm"

# Global variables
PLATFORM=""
ARCH=""
TEMP_DIR=""
INSTALL_TYPE="binary"  # Can be "binary" (Cython compiled) or "python" (raw Python)

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

# Ask user for installation type preference
ask_installation_type() {
    echo ""
    log_info "Choose your installation type:"
    echo "  1) Cython compiled binaries (recommended - faster performance, smaller size)"
    echo "  2) Python source files (easier to modify, requires Python runtime)"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-2) [default: 1]: " -r choice
        case "${choice:-1}" in
            1)
                INSTALL_TYPE="binary"
                log_info "Selected: Cython compiled binaries"
                break
                ;;
            2)
                INSTALL_TYPE="python"
                log_info "Selected: Python source files"
                break
                ;;
            *)
                log_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
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
    for binary_name in "${BINARIES[@]}"; do
        if command -v "$binary_name" >/dev/null 2>&1; then
            local existing_path
            existing_path=$(which "$binary_name")
            log_warning "$binary_name is already installed at: $existing_path"
            
            if [[ "$existing_path" == "$INSTALL_DIR/$binary_name" ]]; then
                read -p "Do you want to upgrade the existing installation? (y/N): " -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Installation cancelled."
                    exit 0
                fi
                break
            else
                log_warning "Found $binary_name in different location. Continuing with installation to $INSTALL_DIR"
            fi
        fi
    done
}

# Create necessary directories
setup_directories() {
    log_step "Setting up directories"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    
    log_success "Directories created"
}

# Download the binaries
download_binaries() {
    log_step "Downloading WakaTerm binaries for $PLATFORM-$ARCH"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Try to download the zip package first (GitHub Actions format)
    local zip_filename="wakaterm-$PLATFORM-$ARCH.zip"
    local download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/${zip_filename}"
    local zip_file="$TEMP_DIR/${zip_filename}"
    
    log_info "Trying to download binary package: $download_url"
    
    local zip_downloaded=false
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -o "$zip_file" "$download_url" 2>/dev/null; then
            zip_downloaded=true
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -O "$zip_file" "$download_url" 2>/dev/null; then
            zip_downloaded=true
        fi
    fi
    
    if [[ "$zip_downloaded" == "true" ]]; then
        log_success "Binary package downloaded successfully"
        
        # Extract the zip file
        if command -v unzip >/dev/null 2>&1; then
            log_info "Extracting binary package..."
            cd "$TEMP_DIR"
            if unzip -q "$zip_file"; then
                log_success "Package extracted successfully"
                # Check if wakaterm-dist directory exists
                if [[ -d "wakaterm-dist" ]]; then
                    log_info "Found wakaterm-dist directory with compiled modules"
                else
                    log_warning "wakaterm-dist directory not found in package"
                fi
                return
            else
                log_error "Failed to extract package"
            fi
        else
            log_error "unzip command not found - cannot extract binary package"
        fi
    fi
    
    log_info "Zip package not available, trying individual binary downloads..."
    
    # Fallback to individual binary downloads (legacy method)
    local success_count=0
    for binary_name in "${BINARIES[@]}"; do
        # Determine binary filename
        local binary_filename="${binary_name}-$PLATFORM-$ARCH"
        if [[ "$PLATFORM" == "windows" ]]; then
            binary_filename="${binary_filename}.exe"
        fi
        
        # Construct download URL
        local download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/${binary_filename}"
        local temp_file="$TEMP_DIR/${binary_filename}"
        
        log_info "Downloading $binary_name: $download_url"
        
        # Download using curl or wget
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL -o "$temp_file" "$download_url"; then
                log_success "$binary_name downloaded successfully"
                ((success_count++))
            else
                log_error "Failed to download $binary_name with curl"
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q -O "$temp_file" "$download_url"; then
                log_success "$binary_name downloaded successfully" 
                ((success_count++))
            else
                log_error "Failed to download $binary_name with wget"
            fi
        else
            log_error "Neither curl nor wget found"
            break
        fi
    done
    
    if [[ $success_count -eq 0 ]]; then
        log_info "Trying to build from source instead..."
        build_from_source
        return
    elif [[ $success_count -lt ${#BINARIES[@]} ]]; then
        log_warning "Only $success_count of ${#BINARIES[@]} binaries downloaded successfully"
        log_info "Continuing with available binaries..."
    fi
}

# Install Python source files directly
install_python_source() {
    log_step "Installing WakaTerm Python source files"
    
    # Check if Python is available
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 is required for Python source installation"
        exit 1
    fi
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git is required to download source files"
        exit 1
    fi
    
    # Clone repository to temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log_info "Cloning repository..."
    git clone "https://github.com/${GITHUB_REPO}.git" wakaterm
    cd wakaterm
    
    # Create source installation directory
    local source_dir="$HOME/.local/share/wakaterm-source"
    mkdir -p "$source_dir"
    
    # Copy Python source files
    log_info "Copying source files..."
    cp wakaterm.py "$source_dir/"
    cp wakaterm_minimal.py "$source_dir/" 2>/dev/null || true
    cp ignore_filter.py "$source_dir/"
    cp wakatermctl "$source_dir/"
    
    # Create wrapper scripts in install directory
    local wakaterm_wrapper="$INSTALL_DIR/wakaterm"
    local wakatermctl_wrapper="$INSTALL_DIR/wakatermctl"
    
    cat > "$wakaterm_wrapper" << EOF
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.expanduser('~/.local/share/wakaterm-source'))
import wakaterm
wakaterm.main()
EOF
    
    cat > "$wakatermctl_wrapper" << EOF
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.expanduser('~/.local/share/wakaterm-source'))
with open(os.path.expanduser('~/.local/share/wakaterm-source/wakatermctl'), 'r') as f:
    exec(f.read())
EOF
    
    chmod +x "$wakaterm_wrapper" "$wakatermctl_wrapper"
    
    # Clean up
    cd /
    rm -rf "$temp_dir"
    
    log_success "Python source installation completed"
    TEMP_DIR=""  # Prevent cleanup of non-existent temp dir
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

# Install the binaries
install_binaries() {
    log_step "Installing WakaTerm binaries"
    
    local installed_count=0
    
    # Check if we have the new zip package format (with wakaterm-dist)
    if [[ -d "$TEMP_DIR/wakaterm-dist" ]]; then
        log_info "Installing from zip package format..."
        
        # Create a shared directory for the compiled modules
        local shared_dir="$HOME/.local/share/wakaterm-ng"
        mkdir -p "$shared_dir"
        
        # Copy the wakaterm-dist directory
        log_info "Installing compiled modules..."
        cp -r "$TEMP_DIR/wakaterm-dist" "$shared_dir/"
        
        # Install each binary wrapper
        for binary_name in "${BINARIES[@]}"; do
            local binary_filename="${binary_name}-$PLATFORM-$ARCH"
            local temp_file="$TEMP_DIR/${binary_filename}"
            local install_path="$INSTALL_DIR/$binary_name"
            
            if [[ -f "$temp_file" ]]; then
                # Copy the wrapper script and make it executable
                cp "$temp_file" "$install_path"
                chmod +x "$install_path"
                
                # Update the wrapper to point to the correct shared location
                if [[ "$binary_name" == "wakaterm" ]]; then
                    # Fix the Python path in the wrapper
                    sed -i "s|sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist'))|sys.path.insert(0, os.path.expanduser('$shared_dir/wakaterm-dist'))|" "$install_path"
                elif [[ "$binary_name" == "wakatermctl" ]]; then
                    # Fix the Python path in the wakatermctl wrapper
                    sed -i "s|sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist'))|sys.path.insert(0, os.path.expanduser('$shared_dir/wakaterm-dist'))|" "$install_path"
                    sed -i "s|os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist', 'wakatermctl')|os.path.expanduser('$shared_dir/wakaterm-dist/wakatermctl')|" "$install_path"
                fi
                
                log_success "$binary_name installed to: $install_path"
                ((installed_count++))
            else
                log_warning "$binary_name wrapper not found in package"
            fi
        done
        
        log_info "Compiled modules installed to: $shared_dir/wakaterm-dist"
    else
        # Legacy individual binary format
        log_info "Installing from individual binary format..."
        
        for binary_name in "${BINARIES[@]}"; do
            local binary_filename="${binary_name}-$PLATFORM-$ARCH"
            if [[ "$PLATFORM" == "windows" ]]; then
                binary_filename="${binary_filename}.exe"
            fi
            
            local temp_file="$TEMP_DIR/${binary_filename}"
            
            if [[ ! -f "$temp_file" ]]; then
                log_warning "$binary_name binary not found, skipping"
                continue
            fi
            
            local install_path="$INSTALL_DIR/$binary_name"
            if [[ "$PLATFORM" == "windows" ]]; then
                install_path="${install_path}.exe"
            fi
            
            # Copy binary to install directory
            cp "$temp_file" "$install_path"
            chmod +x "$install_path"
            
            log_success "$binary_name installed to: $install_path"
            ((installed_count++))
        done
    fi
    
    if [[ $installed_count -eq 0 ]]; then
        log_error "No binaries were installed successfully"
        exit 1
    else
        log_success "$installed_count of ${#BINARIES[@]} binaries installed successfully"
    fi
}

# Verify installation
verify_installation() {
    log_step "Verifying installation"
    
    local verified_count=0
    
    for binary_name in "${BINARIES[@]}"; do
        local install_path="$INSTALL_DIR/$binary_name"
        
        # Test if binary works
        if "$install_path" --help >/dev/null 2>&1; then
            log_success "$binary_name installation verified"
            ((verified_count++))
        else
            log_warning "$binary_name installation verification failed"
        fi
    done
    
    if [[ $verified_count -eq 0 ]]; then
        log_error "No binaries passed verification"
        exit 1
    fi
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warning "Install directory $INSTALL_DIR is not in PATH"
        echo ""
        log_info "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo -e "${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
        log_info "Or run binaries directly from: $INSTALL_DIR"
    else
        log_info "You can now run: wakaterm --help and wakatermctl --help"
    fi
}

# Cleanup temporary files
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Uninstall function
uninstall_wakaterm() {
    log_step "Uninstalling WakaTerm NG"
    
    local removed_count=0
    
    # Remove binary wrappers
    for binary_name in "${BINARIES[@]}"; do
        local install_path="$INSTALL_DIR/$binary_name"
        if [[ -f "$install_path" ]]; then
            rm -f "$install_path"
            log_success "Removed $binary_name from $install_path"
            ((removed_count++))
        fi
    done
    
    # Remove shared compiled modules directory
    local shared_dir="$HOME/.local/share/wakaterm-ng"
    if [[ -d "$shared_dir" ]]; then
        rm -rf "$shared_dir"
        log_success "Removed compiled modules from $shared_dir"
    fi
    
    # Remove config directory if empty or ask user
    if [[ -d "$CONFIG_DIR" ]]; then
        if [[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
            rmdir "$CONFIG_DIR" 2>/dev/null || true
            log_success "Removed empty config directory"
        else
            log_info "Config directory $CONFIG_DIR contains files"
            read -p "Do you want to remove config files as well? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$CONFIG_DIR"
                log_success "Removed config directory"
            else
                log_info "Keeping config directory"
            fi
        fi
    fi
    
    if [[ $removed_count -gt 0 ]]; then
        log_success "WakaTerm NG uninstalled successfully"
    else
        log_warning "No WakaTerm binaries found to remove"
    fi
}

# Show usage information
show_usage() {
    echo "WakaTerm NG Binary Installer"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  install     Install WakaTerm NG (default)"
    echo "  uninstall   Remove WakaTerm NG installation"
    echo "  help        Show this help message"
    echo ""
    echo "Options:"
    echo "  --python    Force Python source installation"
    echo "  --binary    Force binary installation (default)"
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive installation"
    echo "  $0 install      # Install with defaults"
    echo "  $0 --python     # Install Python source version"
    echo "  $0 uninstall    # Remove installation"
}

# Main installation function
install_wakaterm_main() {
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
    
    # Ask user for installation preference (unless forced via command line)
    if [[ "$INSTALL_TYPE" == "binary" ]]; then
        ask_installation_type
    fi
    
    setup_directories
    
    # Install based on user choice
    if [[ "$INSTALL_TYPE" == "python" ]]; then
        install_python_source
    else
        # Download and install binaries (Cython compiled)
        download_binaries
        install_binaries
    fi
    
    verify_installation
    
    echo ""
    log_success "WakaTerm NG installation completed!"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure WakaTime: wakaterm --help"
    echo "  2. View statistics: wakatermctl stats"
    echo "  3. Manage ignore patterns: wakatermctl ignore --help"
    echo "  4. Set up shell integration (see README.md)"
    echo "  5. Start tracking your terminal activity!"
    echo ""
}

# Main function - handle commands and options
main() {
    local command="install"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            install)
                command="install"
                shift
                ;;
            uninstall)
                command="uninstall"
                shift
                ;;
            help|--help|-h)
                command="help"
                shift
                ;;
            --python)
                INSTALL_TYPE="python"
                shift
                ;;
            --binary|--cython)
                INSTALL_TYPE="binary"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Execute the appropriate command
    case "$command" in
        install)
            install_wakaterm_main
            ;;
        uninstall)
            echo -e "${BLUE}${BOLD}"
            echo "🗑️  WakaTerm NG Uninstaller"
            echo "=========================="
            echo -e "${NC}"
            uninstall_wakaterm
            ;;
        help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi