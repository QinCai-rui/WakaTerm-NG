# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for WakaTerm NG - OPTIMIZED FOR STARTUP SPEED
Uses --onedir mode for fastest possible startup time
"""

import sys
from pathlib import Path

# Build configuration
block_cipher = None

# SPEED-OPTIMIZED Analysis 
a = Analysis(
    ['wakaterm.py'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=['ignore_filter'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # GUI frameworks - definitely not needed
        'tkinter', 'turtle', '_tkinter',
        'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        
        # Testing frameworks - not needed in production
        'pytest', 'unittest', 'doctest', 'test',
        'pdb', 'cProfile', 'profile', 'pstats',
        
        # Network protocols we don't use
        'ssl', 'http.server', 'xmlrpc', 'wsgiref',
        'email', 'html', 'urllib.request', 'urllib.parse', 'urllib.error',
        'ftplib', 'poplib', 'imaplib', 'nntplib', 'smtplib',
        
        # Audio/Video - not needed
        'wave', 'aifc', 'sunau', 'sndhdr', 'ossaudiodev', 'audioop',
        
        # Terminal control we don't use
        'tty', 'pty',
        
        # XML processing - not needed
        'xml.etree', 'xml.dom', 'xml.parsers', 'xml.sax',
        
        # Concurrency - we don't use these
        'multiprocessing', 'concurrent', 'asyncio',
        
        # Databases - not needed
        'sqlite3', 'dbm',
        
        # Serialization we don't use
        'pickle', 'shelve',
        
        # Build tools - not needed at runtime
        'distutils', 'setuptools', 'pkg_resources', 'importlib.metadata',
        
        # Compression we don't use
        'bz2', 'lzma', 'gzip', 'zipfile', 'tarfile',
        
        # Other unused modules
        'webbrowser', 'calendar',
        'mmap', 'threading', 'queue', '_queue',
        'typing_extensions',
        'encodings.idna', 'encodings.punycode',
        'ctypes', 'ctypes.util', 'ctypes.wintypes',
        'decimal', 'fractions', 'statistics',
        'pprint', 'copy', 'deepcopy',
        'socketserver',
        'logging.config', 'logging.handlers',
        'urllib3', 'requests', 'certifi',
        
        # IMPORTANT: Do NOT exclude these core stdlib modules:
        # - collections.abc (needed by collections, inspect)
        # - reprlib (needed by collections)
        # - signal (needed by subprocess)
        # - locale (may be needed by argparse)
        # - socket (needed for hostname)
        # - selectors (needed by subprocess)
        # - fcntl/termios (may be needed on Unix)
        # - http (base module, http.server is excluded)
        # - codecs (needed for text encoding)
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=True,  # Faster startup
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# ONEDIR mode for fastest startup
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='wakaterm',
    debug=False,
    bootloader_ignore_signals=False,
    strip=True,
    upx=False,  # UPX slows startup
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles, 
    a.datas,
    strip=True,
    upx=False,
    upx_exclude=[],
    name='wakaterm'
)