# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for WakaTerm NG
Creates optimized single-file binaries for cross-platform distribution
"""

import sys
from pathlib import Path

# Build configuration
block_cipher = None
workpath = Path('./build')
distpath = Path('./dist')

# Analysis configuration - AGGRESSIVE optimization for speed
a = Analysis(
    ['wakaterm.py'],  # Main script
    pathex=['.'],
    binaries=[],
    datas=[
        # Include the ignore filter module as a data file since it's imported dynamically
    ],
    hiddenimports=[
        'ignore_filter',  # Ensure ignore_filter is included
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # AGGRESSIVE exclusions for faster startup
        'tkinter', 'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        'pytest', 'unittest', 'doctest',
        'pdb', 'cProfile', 'profile',
        'ssl', 'http.server', 'xmlrpc',
        'email', 'html', 'urllib.request', 'urllib.parse',
        'ftplib', 'poplib', 'imaplib', 'nntplib', 'smtplib',
        'wave', 'aifc', 'sunau', 'sndhdr', 'ossaudiodev',
        'tty', 'pty', 'select', 'fcntl',
        # Additional exclusions for speed
        'xml', 'xmlrpc', 'xml.etree', 'xml.dom', 'xml.parsers',
        'multiprocessing', 'concurrent', 'asyncio',
        'sqlite3', 'dbm', 'csv', 'pickle',
        'distutils', 'setuptools', 'pkg_resources',
        'bz2', 'lzma', 'gzip', 'zipfile', 'tarfile',
        'webbrowser', 'calendar', 'locale',
        'mmap', 'signal', 'queue',
        'collections.abc', 'typing_extensions',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=True,  # Enable for faster startup
)

# Remove duplicate entries
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Create the executable - OPTIMIZED FOR SPEED
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,  # Create directory for faster startup
    name='wakaterm',
    debug=False,
    bootloader_ignore_signals=False,
    strip=True,  # Strip symbols for faster loading
    upx=False,  # Disable UPX - it slows startup
    runtime_tmpdir=None,
    console=True,  # Keep as console app
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # Could add an icon later
)

# Create collection for directory-based distribution (faster startup)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='wakaterm'
)

# Platform-specific configurations
if sys.platform.startswith('darwin'):
    # macOS specific optimizations
    exe.append('CFBundleShortVersionString', '2.1.1')
    exe.append('CFBundleVersion', '2.1.1')
elif sys.platform.startswith('win'):
    # Windows specific optimizations
    exe.version = 'wakaterm.exe'
    exe.append('CompanyName', 'WakaTerm NG')
    exe.append('ProductName', 'WakaTerm NG')
    exe.append('ProductVersion', '2.1.1')