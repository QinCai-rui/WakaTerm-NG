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
        # Only exclude heavy GUI and ML frameworks that are definitely not needed
        'tkinter', 'turtle', '_tkinter',
        'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        
        # Testing frameworks - not needed in production
        'pytest', 'unittest.mock', 'doctest',
        'pdb', 'cProfile', 'profile',
        
        # Heavy network protocols we definitely don't use
        'email', 'ftplib', 'poplib', 'imaplib', 'nntplib', 'smtplib',
        'xmlrpc', 'wsgiref',
        
        # Audio/Video - not needed
        'wave', 'aifc', 'sunau', 'sndhdr', 'ossaudiodev', 'audioop',
        
        # XML processing - not needed
        'xml.etree', 'xml.dom', 'xml.parsers', 'xml.sax',
        
        # Heavy async frameworks - not needed
        'asyncio', 'concurrent.futures',
        
        # Databases - not needed
        'sqlite3', 'dbm',
        
        # Build tools - not needed at runtime
        'distutils', 'setuptools', 'pkg_resources',
        
        # Compression we don't use
        'bz2', 'lzma',
        
        # Other truly unused modules
        'webbrowser',
        'pprint',
        'socketserver',
        'urllib3', 'requests', 'certifi',
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