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
        self.build_type = 'cython'  # Default to Cython, can be changed to 'python'
        
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
    
    def ask_build_type(self) -> None:
        """Ask user for build type preference"""
        if '--python' in sys.argv:
            self.build_type = 'python'
            print("🐍 Build type: Python source (from command line)")
            return
        elif '--cython' in sys.argv:
            self.build_type = 'cython'
            print("🚀 Build type: Cython compiled (from command line)")
            return

        env_choice = os.environ.get('WAKATERM_BUILD_TYPE', '').strip().lower()
        choice_map = {
            '1': 'cython',
            'cython': 'cython',
            'default': 'cython',
            '2': 'python',
            'python': 'python',
            'source': 'python',
        }

        if env_choice:
            selected = choice_map.get(env_choice)
            if selected:
                self.build_type = selected
                label = 'Cython compiled' if selected == 'cython' else 'Python source'
                print(f"🔧 Build type: {label} (from WAKATERM_BUILD_TYPE={env_choice})")
                return
            else:
                print(f"⚠️  Ignoring invalid WAKATERM_BUILD_TYPE value: {env_choice}")

        if not sys.stdin.isatty() or os.environ.get('CI') or os.environ.get('GITHUB_ACTIONS'):
            self.build_type = 'cython'
            print("🤖 Non-interactive environment detected; defaulting to Cython build")
            return

        print("\n🏗️  Choose build type:")
        print("  1) Cython compiled binaries (recommended - faster performance)")
        print("  2) Python source package (easier development, no compilation)")
        print()

        while True:
            try:
                choice = input("Enter your choice (1-2) [default: 1]: ").strip()
                if choice == '' or choice == '1':
                    self.build_type = 'cython'
                    print("🚀 Selected: Cython compiled binaries")
                    break
                elif choice == '2':
                    self.build_type = 'python'
                    print("🐍 Selected: Python source package")
                    break
                else:
                    print("❌ Invalid choice. Please enter 1 or 2.")
            except (EOFError, KeyboardInterrupt):
                print("\n🛑 Build cancelled by user")
                sys.exit(1)
    
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
python -c "import sys; import os; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath('%~f0')), 'wakaterm-dist')); import wakaterm; wakaterm.main()" %*
"""
            with open(wrapper_path, 'w') as f:
                f.write(wrapper_content)
        else:
            # For Unix-like systems, create a Python wrapper with better error handling
            wrapper_path = self.binary_dir / binary_name
            wrapper_content = f"""#!/usr/bin/env python3
import sys
import os

# Add the distribution directory to Python path
script_dir = os.path.dirname(os.path.abspath(__file__))
dist_dir = os.path.join(script_dir, 'wakaterm-dist')
sys.path.insert(0, dist_dir)

try:
    import wakaterm
except ImportError as e:
    print(f"Error: Could not import wakaterm module from {{dist_dir}}", file=sys.stderr)
    print(f"Make sure the 'wakaterm-dist' directory is in the same location as this script.", file=sys.stderr)
    print(f"Python version: {{sys.version}}", file=sys.stderr)
    print(f"Available files in {{dist_dir}}:", file=sys.stderr)
    try:
        for f in os.listdir(dist_dir):
            print(f"  {{f}}", file=sys.stderr)
    except OSError:
        print(f"  Could not list directory contents", file=sys.stderr)
    print(f"Import error details: {{e}}", file=sys.stderr)
    sys.exit(1)

if __name__ == '__main__':
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
python -c "import sys; sys.path.insert(0, '%~dp0wakaterm-dist'); import wakatermctl; wakatermctl.main()" %*
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
    
    def build_python_package(self) -> Optional[Path]:
        """Create Python source package without Cython compilation"""
        print(f"🐍 Creating Python source package for {self.current_platform}-{self.current_arch}...")
        
        # Create binaries directory
        self.binary_dir.mkdir(exist_ok=True)
        
        # Create source distribution directory
        source_dist_dir = self.binary_dir / "wakaterm-python-dist"
        if source_dist_dir.exists():
            shutil.rmtree(source_dist_dir)
        source_dist_dir.mkdir(parents=True)
        
        # Copy Python source files
        source_files = ["wakaterm.py", "wakaterm_minimal.py", "ignore_filter.py", "wakatermctl"]
        for src_file in source_files:
            src_path = self.root_dir / src_file
            if src_path.exists():
                shutil.copy2(src_path, source_dist_dir)
                print(f"   Copied: {src_file}")
            else:
                if src_file in ["wakaterm.py", "ignore_filter.py", "wakatermctl"]:
                    print(f"❌ Required file missing: {src_file}")
                    return None
                else:
                    print(f"⚠️  Optional file missing: {src_file}")
        
        # Create wrapper scripts
        binary_name = f"wakaterm-{self.current_platform}-{self.current_arch}"
        if self.current_platform == 'windows':
            binary_name += '.exe'
            # Windows batch wrapper
            wrapper_path = self.binary_dir / binary_name
            wrapper_content = f"""@echo off
python "%~dp0wakaterm-python-dist\\wakaterm.py" %*
"""
            with open(wrapper_path, 'w') as f:
                f.write(wrapper_content)
        else:
            # Unix shell wrapper
            wrapper_path = self.binary_dir / binary_name
            wrapper_content = f"""#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-python-dist'))
import wakaterm
wakaterm.main()
"""
            with open(wrapper_path, 'w') as f:
                f.write(wrapper_content)
            os.chmod(wrapper_path, 0o755)
        
        print(f"✅ wakaterm Python wrapper created: {wrapper_path}")
        
        # Create wakatermctl wrapper
        wakatermctl_name = f"wakatermctl-{self.current_platform}-{self.current_arch}"
        if self.current_platform == 'windows':
            wakatermctl_name += '.exe'
            wrapper_content = f"""@echo off
python "%~dp0wakaterm-python-dist\\wakatermctl" %*
"""
        else:
            wrapper_content = f"""#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-python-dist'))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'wakaterm-python-dist', 'wakatermctl')) as f:
    exec(f.read())
"""
        
        wakatermctl_path = self.binary_dir / wakatermctl_name
        with open(wakatermctl_path, 'w') as f:
            f.write(wrapper_content)
        
        if self.current_platform != 'windows':
            os.chmod(wakatermctl_path, 0o755)
        
        print(f"✅ wakatermctl Python wrapper created: {wakatermctl_path}")
        
        # Calculate and show package size
        package_size = self._get_dir_size(source_dist_dir) / 1024
        print(f"📊 Source package size: {package_size:.1f} KB")
        
        return wrapper_path
    
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
    parser.add_argument('--python', action='store_true', help='Build Python source package instead of Cython binary')
    parser.add_argument('--cython', action='store_true', help='Build Cython compiled binary (default)')
    
    args = parser.parse_args()
    
    builder = WakatermBuilder()
    
    # Ask for build type if not specified via command line
    if not args.python and not args.cython:
        builder.ask_build_type()
    elif args.python:
        builder.build_type = 'python'
    else:
        builder.build_type = 'cython'
    
    # Clean if requested
    if args.clean:
        builder.clean_build_artifacts()
    
    # Setup environment (only check Cython for Cython builds)
    if builder.build_type == 'cython':
        if not builder.setup_environment():
            print("❌ Failed to set up build environment")
            return 1
    else:
        print("🐍 Python source build - skipping Cython environment setup")
        builder.binary_dir.mkdir(exist_ok=True)
    
    # Build based on selected type
    if builder.build_type == 'python':
        binary_path = builder.build_python_package()
    else:
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
    print(f"📁 Build location: {binary_path}")
    
    if builder.build_type == 'python':
        print("🐍 Python source package created")
        print(f"🔧 To install Python version: python -m pip install -e .")
    else:
        print("🚀 Cython compiled binary created")
        print(f"🔧 To install binary: cp {binary_path} ~/.local/bin/wakaterm")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())