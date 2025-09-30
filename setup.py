#!/usr/bin/env python3
"""
Setup script for building WakaTerm NG with optional Cython compilation
Supports both Cython compilation and regular Python installation
"""

from setuptools import setup, Extension
import sys
import os

# Check if user wants Cython compilation or regular Python installation
USE_CYTHON = True
if "--no-cython" in sys.argv:
    sys.argv.remove("--no-cython")
    USE_CYTHON = False
elif "--python-only" in sys.argv:
    sys.argv.remove("--python-only")
    USE_CYTHON = False
elif os.environ.get("WAKATERM_PYTHON_ONLY", "").lower() in ("1", "true", "yes"):
    USE_CYTHON = False

# Try to import Cython, fall back to regular Python if not available
if USE_CYTHON:
    try:
        from Cython.Build import cythonize
    except ImportError:
        print("Cython not found. Installing as regular Python package...")
        print("To install Cython: pip install cython>=3.0.0")
        USE_CYTHON = False

# Setup configuration based on installation type
if USE_CYTHON:
    # Define platform-specific compiler flags for Cython
    extra_compile_args = ["-O3", "-march=native"] if sys.platform != "win32" else ["/O2"]

    # Define extensions to compile with Cython
    extensions = [
        Extension(
            "wakaterm",
            ["wakaterm.py"],
            extra_compile_args=extra_compile_args,
        ),
        Extension(
            "ignore_filter",
            ["ignore_filter.py"],
            extra_compile_args=extra_compile_args,
        ),
    ]

    # Cython compiler directives for optimization
    compiler_directives = {
        "language_level": "3",
        "embedsignature": True,
        "boundscheck": False,  # Disable bounds checking for speed
        "wraparound": False,   # Disable negative indexing for speed
        "initializedcheck": False,  # Disable initialization checks
        "nonecheck": False,    # Disable None checks for speed
        "cdivision": True,     # Use C division semantics
        "overflowcheck": False,  # Disable overflow checks
    }

    # Cython setup
    setup(
        name="wakaterm-ng",
        version="2.0.0",
        description="WakaTerm NG - Terminal Activity Logger (Cython-compiled)",
        author="QinCai-rui",
        ext_modules=cythonize(
            extensions,
            compiler_directives=compiler_directives,
            build_dir="build",
        ),
        scripts=["wakatermctl"],
    )
else:
    # Regular Python setup (no Cython compilation)
    setup(
        name="wakaterm-ng",
        version="2.0.0",
        description="WakaTerm NG - Terminal Activity Logger (Pure Python)",
        author="QinCai-rui",
        py_modules=["wakaterm", "ignore_filter"],
        scripts=["wakatermctl"],
        python_requires=">=3.6",
        classifiers=[
            "Development Status :: 4 - Beta",
            "Intended Audience :: Developers",
            "License :: OSI Approved :: MIT License",
            "Programming Language :: Python :: 3",
            "Programming Language :: Python :: 3.6",
            "Programming Language :: Python :: 3.7",
            "Programming Language :: Python :: 3.8",
            "Programming Language :: Python :: 3.9",
            "Programming Language :: Python :: 3.10",
            "Programming Language :: Python :: 3.11",
            "Programming Language :: Python :: 3.12",
            "Topic :: Software Development :: Libraries",
            "Topic :: System :: Monitoring",
        ],
    )

# Print installation type information
if __name__ == "__main__":
    if USE_CYTHON:
        print("🚀 Building WakaTerm NG with Cython compilation for optimal performance")
    else:
        print("🐍 Installing WakaTerm NG as pure Python package")
