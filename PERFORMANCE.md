# WakaTerm NG Performance Analysis

## Overview

WakaTerm NG provides three distribution methods, each with different performance characteristics:

1. **Python Script** (`wakaterm.py`) - Direct execution
2. **PyInstaller Binary** (`wakaterm-fast.spec`) - Full-featured compiled binary
3. **Minimal Binary** (`wakaterm-minimal.spec`) - Ultra-optimized minimal build

## Performance Benchmarks

### x86_64 Linux (Ubuntu 22.04, Python 3.12)

| Distribution | Startup Time | Size | Features |
|-------------|-------------|------|----------|
| Python Script (full) | ~0.04s | 15KB | Full (requires Python) |
| Python Script (minimal) | ~0.01s | 2KB | Basic (requires Python) |
| PyInstaller Binary (full) | ~0.05s | 20MB | Full (standalone) |
| PyInstaller Binary (minimal) | ~0.04s | 20MB | Basic (standalone) |

### ARM64 Linux (Raspberry Pi, Python 3.11)

*Note: These are estimated based on typical ARM64 performance characteristics*

| Distribution | Startup Time | Size | Features |
|-------------|-------------|------|----------|
| Python Script (full) | ~0.14s | 15KB | Full (requires Python) |
| Python Script (minimal) | ~0.04s | 2KB | Basic (requires Python) |
| PyInstaller Binary (full) | ~0.20-0.30s | 20MB | Full (standalone) |
| PyInstaller Binary (minimal) | ~0.15s | 20MB | Basic (standalone) |

## Why is the Binary Slower?

PyInstaller binaries include:
- The Python interpreter
- All required libraries
- Bootloader code

This means every execution must:
1. Extract/map the bundled Python interpreter
2. Load all required libraries
3. Initialize the Python runtime
4. Run your code

For very lightweight scripts like WakaTerm, this overhead can exceed the actual execution time.

## When to Use Each Distribution

### Python Script (Recommended for Development)
✅ **Use when:**
- You have Python installed
- You want the fastest startup time
- You need to modify the code frequently
- Disk space is limited

❌ **Avoid when:**
- Target systems don't have Python
- You need true standalone deployment

### PyInstaller Binary (Recommended for Production)
✅ **Use when:**
- Deploying to systems without Python
- You need a single-file distribution
- Installation simplicity is critical
- System has adequate resources

❌ **Avoid when:**
- Performance is absolutely critical
- Running on very low-powered devices (< 1GB RAM)
- Disk space is extremely limited

### Minimal Binary
✅ **Use when:**
- You need standalone deployment
- Performance is important
- You don't need advanced features (ignore patterns, WakaTime sync)

❌ **Avoid when:**
- You need full feature set
- You're okay with Python dependency

## Optimization Strategies

### For Binary Performance

1. **Use onedir mode** (already implemented)
   - Faster startup than onefile
   - Avoids extraction overhead

2. **Minimize imports** (already implemented)
   - Fewer modules = faster startup
   - Use conditional imports

3. **Exclude unnecessary modules** (already implemented)
   - See `excludes` in spec files
   - Balance between size and functionality

4. **Disable UPX compression** (already implemented)
   - UPX adds decompression overhead
   - Modern systems prefer uncompressed

### For Script Performance

1. **Use minimal version** for simple tracking
2. **Lazy imports** for optional features
3. **Cache expensive operations** (project detection, git info)

## Building for Your Platform

For best performance on your specific hardware:

```bash
# Clone and build locally
git clone https://github.com/QinCai-rui/WakaTerm-NG.git
cd WakaTerm-NG

# Install dependencies
pip install -r requirements.txt

# Build for your platform
python build.py

# Test performance
time ./binaries/wakaterm-dist/wakaterm --help
time python3 wakaterm.py --help
```

## Recommendations

### Raspberry Pi / ARM64 Users
Use the **Python script** directly for best performance:
```bash
# Install Python version (fastest)
curl -fsSL https://go.qincai.xyz/wakaterm-ng | bash
```

### x86_64 Desktop/Server Users
Use the **PyInstaller binary** for convenience:
```bash
# Install binary version (most convenient)
curl -fsSL https://raw.githubusercontent.com/QinCai-rui/WakaTerm-NG/main/install-binary.sh | bash
```

### High-Performance Requirements
Use the **minimal script** or build a **minimal binary**:
```bash
# Use minimal script directly
python3 wakaterm_minimal.py <command>

# Or build minimal binary
python3 -m PyInstaller wakaterm-minimal.spec
```

## Conclusion

The "best" distribution depends on your priorities:
- **Speed**: Python script (requires Python installed)
- **Convenience**: PyInstaller binary (standalone)
- **Balance**: Minimal binary (fast + standalone)

For terminal command tracking, the overhead difference (0.01-0.05s) is generally negligible compared to the command execution time itself.
