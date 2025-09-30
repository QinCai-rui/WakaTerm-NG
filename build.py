#!/usr/bin/env python3
"""
Cross-platform build script for WakaTerm NG
Compiles Python code to optimized binaries for multiple platforms and architectures
"""

import os
import sys
import subprocess
import platform
import shutil
from pathlib import Path
from typing import Dict, List, Optional

class WakatermBuilder:
    """Builder class for creating cross-platform WakaTerm binaries"""
    
    def __init__(self):
        self.root_dir = Path(__file__).parent
        self.dist_dir = self.root_dir / 'dist'
        self.build_dir = self.root_dir / 'build'
        self.binary_dir = self.root_dir / 'binaries'
        
        # Platform detection
        self.current_platform = self._detect_platform()
        self.current_arch = self._detect_architecture()
        
        print(f"🔧 WakaTerm NG Builder")
        print(f"Platform: {self.current_platform}")
        print(f"Architecture: {self.current_arch}")
        print(f"Python: {sys.version.split()[0]}")
        print()
    
    def _detect_platform(self) -> str:
        """Detect the current platform"""
        system = platform.system().lower()
        if system == 'darwin':
            return 'macos'
        elif system == 'windows':
            return 'windows'
        elif system == 'linux':
            return 'linux'
        else:
            return 'unknown'
    
    def _detect_architecture(self) -> str:
        """Detect the current architecture"""
        machine = platform.machine().lower()
        if machine in ['x86_64', 'amd64']:
            return 'x86_64'
        elif machine in ['arm64', 'aarch64']:
            return 'arm64'
        elif machine in ['i386', 'i686', 'x86']:
            return 'x86'
        else:
            return machine
    
    def _get_dir_size(self, path: Path) -> int:
        """Get total size of directory in bytes"""
        total_size = 0
        for dirpath, dirnames, filenames in os.walk(path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    total_size += os.path.getsize(fp)
        return total_size
    
    def _run_command(self, cmd: List[str], description: str) -> bool:
        """Run a command and handle errors"""
        print(f"🔄 {description}...")
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            if result.stdout.strip():
                print(f"   Output: {result.stdout.strip()}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ {description} failed!")
            print(f"   Error: {e.stderr}")
            return False
        except FileNotFoundError:
            print(f"❌ {description} failed! Command not found: {cmd[0]}")
            return False
    
    def setup_environment(self) -> bool:
        """Set up the build environment"""
        print("🏗️  Setting up build environment...")
        
        # Create directories
        self.binary_dir.mkdir(exist_ok=True)
        
        # Check if Cython is available
        try:
            result = subprocess.run([sys.executable, '-c', 'import Cython'], 
                                 capture_output=True, text=True)
            if result.returncode != 0:
                print("📦 Installing Cython...")
                return self._run_command([
                    sys.executable, '-m', 'pip', 'install', 'cython>=3.0.0'
                ], "Installing Cython")
            else:
                print("✅ Cython already available")
                return True
        except Exception as e:
            print(f"❌ Failed to check Cython: {e}")
            return False
    
    def build_binary(self, optimize: bool = True) -> Optional[Path]:
        """Build the binary for the current platform using Cython"""
        print(f"🚀 Building WakaTerm binaries with Cython for {self.current_platform}-{self.current_arch}...")
        
        # Build using Cython (setup.py)
        cmd = [
            sys.executable, 'setup.py', 'build_ext', '--inplace'
        ]
        
        if not self._run_command(cmd, "Building Cython extensions"):
            print("❌ Failed to build Cython extensions")
            return None
        
        # Create binaries directory
        self.binary_dir.mkdir(exist_ok=True)
        binaries_built = []
        
        # Get Python version for .so naming
        py_version = f"cpython-{sys.version_info.major}{sys.version_info.minor}"
        
        # Determine platform-specific extension suffix
        if self.current_platform == 'linux':
            ext_suffix = f".{py_version}-{platform.machine()}-linux-gnu.so"
        elif self.current_platform == 'macos':
            ext_suffix = f".{py_version}-darwin.so"
        elif self.current_platform == 'windows':
            ext_suffix = f".{py_version}-win_amd64.pyd"
        else:
            ext_suffix = ".so"
        
        # Create wakaterm executable wrapper
        wakaterm_so = self.root_dir / f"wakaterm{ext_suffix}"
        ignore_filter_so = self.root_dir / f"ignore_filter{ext_suffix}"
        
        if not wakaterm_so.exists():
            print(f"❌ Wakaterm extension not found at {wakaterm_so}")
            return None
        
        # Create distribution directory
        dist_dir = self.binary_dir / "wakaterm-dist"
        if dist_dir.exists():
            shutil.rmtree(dist_dir)
        dist_dir.mkdir(parents=True)
        
        # Copy compiled extensions to dist directory
        shutil.copy2(wakaterm_so, dist_dir)
        if ignore_filter_so.exists():
            shutil.copy2(ignore_filter_so, dist_dir)
        
        # Create executable wrapper script
        binary_name = f"wakaterm-{self.current_platform}-{self.current_arch}"
        if self.current_platform == 'windows':
            binary_name += '.exe'
            # For Windows, create a batch wrapper
            wrapper_path = self.binary_dir / binary_name
            wrapper_content = f"""@echo off
python -c "import sys; sys.path.insert(0, '%~dp0wakaterm-dist'); import wakaterm; wakaterm.main()" %*
"""
            with open(wrapper_path, 'w') as f:
                f.write(wrapper_content)
        else:
            # For Unix-like systems, create a shell wrapper
            wrapper_path = self.binary_dir / binary_name
            wrapper_content = f"""#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist'))
import wakaterm
wakaterm.main()
"""
            with open(wrapper_path, 'w') as f:
                f.write(wrapper_content)
            os.chmod(wrapper_path, 0o755)
        
        print(f"✅ wakaterm binary created: {wrapper_path}")
        print(f"📊 Extension size: {os.path.getsize(wakaterm_so) / 1024 / 1024:.1f} MB")
        binaries_built.append(wrapper_path)
        
        # Handle wakatermctl (copy as-is since it's already a script)
        wakatermctl_src = self.root_dir / "wakatermctl"
        if wakatermctl_src.exists():
            wakatermctl_bin = self.binary_dir / f"wakatermctl-{self.current_platform}-{self.current_arch}"
            
            # Copy wakatermctl to dist directory as well (it may import ignore_filter)
            shutil.copy2(wakatermctl_src, dist_dir / "wakatermctl")
            
            # Create wrapper
            if self.current_platform == 'windows':
                wakatermctl_bin = wakatermctl_bin.with_suffix('.exe')
                wrapper_content = f"""@echo off
python -c "import sys; sys.path.insert(0, '%~dp0wakaterm-dist'); exec(open('%~dp0wakaterm-dist\\wakatermctl').read())" %*
"""
            else:
                wrapper_content = f"""#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist'))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-dist', 'wakatermctl')) as f:
    exec(f.read())
"""
            
            with open(wakatermctl_bin, 'w') as f:
                f.write(wrapper_content)
            
            if self.current_platform != 'windows':
                os.chmod(wakatermctl_bin, 0o755)
            
            print(f"✅ wakatermctl binary created: {wakatermctl_bin}")
            binaries_built.append(wakatermctl_bin)
        
        return binaries_built[0] if binaries_built else None
    
    def test_binary(self, binary_path: Path) -> bool:
        """Test the compiled binary"""
        print(f"🧪 Testing binaries...")
        
        # Test both wakaterm and wakatermctl if they exist
        test_results = []
        
        for binary_name in ['wakaterm', 'wakatermctl']:
            binary_file = self.binary_dir / f"{binary_name}-{self.current_platform}-{self.current_arch}"
            if self.current_platform == 'windows':
                binary_file = self.binary_dir / f"{binary_name}-{self.current_platform}-{self.current_arch}.exe"
            
            if not binary_file.exists():
                print(f"⚠️  {binary_name} binary not found, skipping test")
                continue
                
            print(f"🧪 Testing {binary_name} binary")
            
            if binary_name == 'wakaterm':
                tests = [
                    ([str(binary_file), '--help'], "Help output"),
                    ([str(binary_file), '--debug', 'test_command'], "Debug tracking"),
                    ([str(binary_file), '--cleanup'], "Cleanup function"),
                ]
            else:  # wakatermctl
                tests = [
                    ([str(binary_file), '--help'], "Help output"),
                    ([str(binary_file), 'stats', '--help'], "Stats help"),
                ]
            
            binary_passed = True
            for cmd, description in tests:
                if not self._run_command(cmd, f"Testing {description}"):
                    binary_passed = False
                    break
            
            if binary_passed:
                print(f"✅ {binary_name} tests passed!")
                test_results.append(True)
            else:
                print(f"❌ {binary_name} tests failed!")
                test_results.append(False)
        
        return all(test_results) if test_results else False
    
    def clean_build_artifacts(self):
        """Clean build artifacts"""
        print("🧹 Cleaning build artifacts...")
        
        artifacts = [self.build_dir, self.dist_dir]
        for artifact in artifacts:
            if artifact.exists():
                shutil.rmtree(artifact)
                print(f"   Removed: {artifact}")
    
    def create_universal_script(self):
        """Create a universal installation script that detects platform and downloads appropriate binary"""
        script_content = '''#!/bin/bash
# WakaTerm NG Universal Installer
# Automatically detects platform and installs the appropriate binary

set -euo pipefail

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

# Configuration
GITHUB_REPO="QinCai-rui/WakaTerm-NG"
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="wakaterm"

# Detect platform and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
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
            echo -e "${RED}Error: Unsupported operating system: $os${NC}"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        i386|i686)
            ARCH="x86"
            ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac
}

# Download and install binary
install_binary() {
    echo -e "${BLUE}🚀 Installing WakaTerm NG for ${PLATFORM}-${ARCH}${NC}"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Determine binary name
    local binary_suffix="${PLATFORM}-${ARCH}"
    if [[ "$PLATFORM" == "windows" ]]; then
        binary_suffix="${binary_suffix}.exe"
        BINARY_NAME="${BINARY_NAME}.exe"
    fi
    
    # Download URL (adjust when releases are available)
    local download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/wakaterm-${binary_suffix}"
    local temp_file="/tmp/wakaterm-${binary_suffix}"
    
    echo -e "${YELLOW}📥 Downloading ${download_url}${NC}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$temp_file" "$download_url"
    else
        echo -e "${RED}Error: Neither curl nor wget found${NC}"
        exit 1
    fi
    
    # Install binary
    local install_path="${INSTALL_DIR}/${BINARY_NAME}"
    mv "$temp_file" "$install_path"
    chmod +x "$install_path"
    
    echo -e "${GREEN}✅ WakaTerm NG installed to ${install_path}${NC}"
    echo -e "${BLUE}💡 Make sure ${INSTALL_DIR} is in your PATH${NC}"
}

# Main execution
main() {
    detect_platform
    install_binary
}

main "$@"
'''
        
        script_path = self.root_dir / 'install.sh'
        with open(script_path, 'w') as f:
            f.write(script_content)
        os.chmod(script_path, 0o755)
        
        print(f"✅ Universal installer created: {script_path}")
    
    def build_all_supported_platforms(self):
        """Build binaries for all supported platforms (requires cross-compilation setup)"""
        print("🌍 Note: Cross-compilation requires platform-specific environments.")
        print("   Current build creates binary for:", f"{self.current_platform}-{self.current_arch}")
        print("   For other platforms, run this script on the target platform.")
        
        # Could be extended with Docker-based cross-compilation
        return self.build_binary()


def main():
    """Main build script entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='WakaTerm NG Build Script')
    parser.add_argument('--no-optimize', action='store_true', help='Disable optimizations for debugging')
    parser.add_argument('--test', action='store_true', help='Test the binary after building')
    parser.add_argument('--clean', action='store_true', help='Clean build artifacts before building')
    parser.add_argument('--installer', action='store_true', help='Create universal installer script')
    
    args = parser.parse_args()
    
    builder = WakatermBuilder()
    
    # Clean if requested
    if args.clean:
        builder.clean_build_artifacts()
    
    # Setup environment
    if not builder.setup_environment():
        print("❌ Failed to set up build environment")
        return 1
    
    # Build binary
    binary_path = builder.build_binary(optimize=not args.no_optimize)
    if not binary_path:
        print("❌ Build failed")
        return 1
    
    # Test binary if requested
    if args.test:
        if not builder.test_binary(binary_path):
            print("❌ Tests failed")
            return 1
    
    # Create installer if requested
    if args.installer:
        builder.create_universal_script()
    
    print()
    print("🎉 Build completed successfully!")
    print(f"📁 Binary location: {binary_path}")
    print(f"🔧 To install: cp {binary_path} ~/.local/bin/wakaterm")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())