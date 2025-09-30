#!/usr/bin/env python3
"""
Setup script for building WakaTerm NG with Cython
Compiles Python code to C extensions for better performance
"""

from setuptools import setup, Extension
from Cython.Build import cythonize
import sys

# Define platform-specific compiler flags
extra_compile_args = ["-O3", "-march=native"] if sys.platform != "win32" else ["/O2"]

# Define extensions to compile
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
