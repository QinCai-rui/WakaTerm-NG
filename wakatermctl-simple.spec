# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for WakatermCtl - MINIMAL exclusions for compatibility
"""

import sys
from pathlib import Path

# Build configuration
block_cipher = None

# Minimal Analysis for wakatermctl - only exclude what's definitely not needed
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
        # Only exclude the heaviest GUI/ML modules
        'tkinter', 'turtle', '_tkinter',
        'matplotlib', 'numpy', 'scipy', 'pandas',
        'PIL', 'Pillow', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6',
        'jupyter', 'ipython', 'notebook',
        'pytest', 'unittest.mock',
        'pdb',
        'ssl._create_unverified_context', 'ssl._create_default_https_context',
        'webbrowser',
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