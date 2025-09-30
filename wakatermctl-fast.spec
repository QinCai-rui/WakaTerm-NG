# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for WakatermCtl - OPTIMIZED FOR STARTUP SPEED
"""

import sys
from pathlib import Path

# Build configuration
block_cipher = None

# Analysis for wakatermctl
a = Analysis(
    ['wakatermctl'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=['ignore_filter'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Lighter exclusions for wakatermctl to avoid missing modules
        'tkinter', 'turtle', '_tkinter',
        'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        'pytest', 'unittest', 'doctest', 'test',
        'pdb', 'cProfile', 'profile', 'pstats',
        'ssl', 'http', 'xmlrpc', 'wsgiref',
        'email', 'html',
        'ftplib', 'poplib', 'imaplib', 'nntplib', 'smtplib',
        'wave', 'aifc', 'sunau', 'sndhdr', 'ossaudiodev', 'audioop',
        'tty', 'pty', 'select', 'fcntl', 'termios',
        'xml', 'xmlrpc', 'xml.etree', 'xml.dom', 'xml.parsers',
        'multiprocessing', 'concurrent', 'asyncio',
        'sqlite3', 'dbm', 'shelve',
        'distutils', 'setuptools', 'pkg_resources', 'importlib.metadata',
        'bz2', 'lzma', 'gzip', 'zipfile', 'tarfile',
        'webbrowser', 'calendar', 'locale', 'gettext',
        'mmap', 'signal', 'threading', 'queue', '_queue',
        'ctypes', 'ctypes.util', 'ctypes.wintypes',
        'decimal', 'fractions', 'statistics',
        'socket', 'socketserver', 'selectors',
        'logging', 'logging.config', 'logging.handlers',
        'urllib', 'urllib3', 'requests', 'certifi',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=True,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# ONEDIR mode for fastest startup
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='wakatermctl',
    debug=False,
    bootloader_ignore_signals=False,
    strip=True,
    upx=False,
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
    name='wakatermctl'
)