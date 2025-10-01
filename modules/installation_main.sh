#!/bin/bash
# WakaTerm NG Main Installation Module
# Orchestrates different installation types and provides main entry points

# Install wakaterm files (binary or source based on INSTALL_TYPE)
install_wakaterm() {
    # Handle Python source installation
    if [[ "${INSTALL_TYPE:-binary}" == "python" ]]; then
        install_python_source
        return $?
    fi
    
    # For binary mode, try to download pre-built binaries first
    # If that fails, fall back to source installation
    install_prebuilt_binary
    return $?
}