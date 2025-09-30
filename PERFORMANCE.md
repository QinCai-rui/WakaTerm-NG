# WakaTerm NG Performance Analysis

## Overview

WakaTerm NG provides two distribution methods, each with different performance characteristics:

1. **Python Script** (`wakaterm.py`) - Direct execution
2. **Cython Binary** - Compiled C extension for optimal performance

## Performance Benchmarks

### x86_64 Linux (Ubuntu 22.04, Python 3.12)

| Distribution | Startup Time | Size | Features |
|-------------|-------------|------|----------|
| Python Script (full) | ~0.046s | 15KB | Full (requires Python) |
| Cython Binary (full) | ~0.043s | 1.4MB | Full (requires Python) |

**Result: Cython binary is ~6.5% faster than raw Python!**

### ARM64 Linux (Raspberry Pi, Python 3.11)

*Note: These are estimated based on typical ARM64 performance characteristics*

| Distribution | Startup Time | Size | Features |
|-------------|-------------|------|----------|
| Python Script (full) | ~0.14s | 15KB | Full (requires Python) |
| Cython Binary (full) | ~0.12s | 1.5MB | Full (requires Python) |

## Why is Cython Faster?

Cython compiles Python code to C, which provides several advantages:
- Direct C function calls instead of Python bytecode interpretation
- Optimized type handling and memory operations
- Removal of Python overhead for performance-critical paths
- Native machine code execution

Unlike PyInstaller which bundles the entire Python interpreter (adding overhead), Cython creates lean C extensions that leverage the existing Python runtime.

## When to Use Each Distribution

### Python Script (Recommended for Development)
✅ **Use when:**
- You have Python installed
- You want the smallest disk footprint
- You need to modify the code frequently
- Portability across Python versions is important

❌ **Avoid when:**
- You need the absolute best performance
- You're deploying to many systems

### Cython Binary (Recommended for Production)
✅ **Use when:**
- Performance is important
- You have Python installed
- You want optimized execution speed
- You're deploying to production systems

❌ **Avoid when:**
- Target systems don't have Python
- You need to support multiple Python versions with one binary

## Optimization Strategies

### For Cython Binary Performance

1. **Aggressive compiler optimizations** (already implemented)
   - `-O3` optimization level
   - `-march=native` for CPU-specific optimizations
   - Disabled bounds checking and overflow checks

2. **Cython compiler directives** (already implemented)
   - `boundscheck=False` - Skip array bounds checking
   - `wraparound=False` - Disable negative indexing
   - `cdivision=True` - Use C division semantics
   - `nonecheck=False` - Skip None checks

3. **Static typing** (can be added)
   - Add type annotations for hot paths
   - Use `cdef` for C-level variables

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

# Build Cython binary for your platform
python build.py

# Test performance
time ./binaries/wakaterm-linux-x86_64 --help
time python3 wakaterm.py --help
```

## Recommendations

### All Users
Use the **Cython binary** for best performance:
```bash
# Install and build
curl -fsSL https://go.qincai.xyz/wakaterm-ng | bash
# or
git clone https://github.com/QinCai-rui/WakaTerm-NG.git
cd WakaTerm-NG
python build.py
```

### For Development
Use the **Python script** directly for rapid iteration:
```bash
python3 wakaterm.py <command>
```

## Conclusion

WakaTerm NG now uses **Cython compilation** for superior performance:
- **Speed**: Cython binary is ~6.5% faster than raw Python
- **Size**: Compact 1.4MB extensions vs 20MB PyInstaller bundles
- **Reliability**: Native C compilation is more stable than PyInstaller bundling
- **Efficiency**: Lean extensions leverage existing Python runtime

The Cython approach provides the best of both worlds - the performance of compiled code with the flexibility of Python.
