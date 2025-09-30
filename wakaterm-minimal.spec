# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for WakaTerm NG MINIMAL - ULTRA-OPTIMIZED FOR SPEED
Uses the minimal wakaterm_minimal.py for fastest possible startup
"""

import sys

# Build configuration  
block_cipher = None

# ULTRA-MINIMAL Analysis - only include what's absolutely necessary
a = Analysis(
    ['wakaterm_minimal.py'],
    pathex=['.'],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude everything we can
        'tkinter', 'turtle', '_tkinter',
        'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        'pytest', 'unittest', 'doctest', 'test',
        'pdb', 'cProfile', 'profile',
        'email', 'ftplib', 'poplib', 'imaplib', 'nntplib', 'smtplib',
        'xmlrpc', 'wsgiref', 'http.server',
        'wave', 'aifc', 'sunau', 'sndhdr', 'ossaudiodev', 'audioop',
        'xml.etree', 'xml.dom', 'xml.parsers', 'xml.sax',
        'asyncio', 'concurrent.futures', 'multiprocessing',
        'sqlite3', 'dbm',
        'distutils', 'setuptools', 'pkg_resources',
        'bz2', 'lzma',
        'webbrowser', 'pprint', 'socketserver',
        'urllib3', 'requests', 'certifi',
        'typing', 'typing_extensions',
        'argparse',  # We don't use argparse in minimal version
        'ignore_filter',  # Not used in minimal
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=True,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Use onedir for fastest startup
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='wakaterm-minimal',
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
    name='wakaterm-minimal'
)
