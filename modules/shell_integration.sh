#!/bin/bash
# WakaTerm NG Shell Integration Module
# Contains functions for setting up shell integrations

# Setup shell integration
setup_shell_integration() {
    local shell_name="$1"
    log "Setting up $shell_name integration..."
    
    case "$shell_name" in
        "bash")
            setup_bash_integration
            return $?
            ;;
        "zsh")
            setup_zsh_integration
            return $?
            ;;
        "fish")
            setup_fish_integration
            return $?
            ;;
        *)
            warn "Unsupported shell: $shell_name"
            warn "Please manually source the appropriate shell integration file."
            return 0
            ;;
    esac
}

setup_bash_integration() {
    local bashrc="$HOME/.bashrc"
    local bash_profile="$HOME/.bash_profile"
    local bashrc_local="$HOME/.bashrc.local"
    local source_line="source \"$INSTALL_DIR/shells/bash_wakaterm.sh\""
    
    # Check if .bashrc is writable (not a symlink to read-only file like in NixOS)
    local config_file="$bashrc"
    local is_readonly=false
    
    if [[ -L "$bashrc" ]]; then
        # It's a symlink, check if target is writable
        local target=$(readlink "$bashrc")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$bashrc" && ! -w "$bashrc" ]]; then
        is_readonly=true
    elif [[ ! -f "$bashrc" && -f "$bash_profile" ]]; then
        config_file="$bash_profile"
        if [[ -L "$bash_profile" ]]; then
            local target=$(readlink "$bash_profile")
            if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
                is_readonly=true
            fi
        elif [[ ! -w "$bash_profile" ]]; then
            is_readonly=true
        fi
    fi
    
    # If config files are read-only (like in NixOS), use alternative approaches
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only shell configuration (possibly NixOS/home-manager)"
        
        # Try .bashrc.local (sourced by some configurations)
        if [[ -f "$bashrc" ]] && grep -q "bashrc.local\|\.local" "$bashrc" 2>/dev/null; then
            log "Using .bashrc.local for integration"
            config_file="$bashrc_local"
        else
            warn "Cannot automatically integrate with read-only configuration."
            warn "Please manually add the following line to your shell configuration:"
            warn "  $source_line"
            warn ""
            warn "For NixOS users, add this to your home-manager configuration:"
            warn "  programs.bash.initExtra = \"source \\\"$INSTALL_DIR/shells/bash_wakaterm.sh\\\"\";"
            return 1
        fi
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$config_file" 2>/dev/null; then
        warn "Bash integration already configured"
        return 0
    fi
    
    # Add integration with tracking
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your shell configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$config_file" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$config_file"
    
    success "Bash integration added to $(basename -- "$config_file")"
    log "Please restart your terminal or run: source $config_file"
}

setup_zsh_integration() {
    local zshrc="$HOME/.zshrc"
    local zshrc_local="$HOME/.zshrc.local"
    local source_line="source \"$INSTALL_DIR/shells/zsh_wakaterm.zsh\""
    local config_file="$zshrc"
    local is_readonly=false
    
    # Check if .zshrc is writable (not a symlink to read-only file like in NixOS)
    if [[ -L "$zshrc" ]]; then
        local target=$(readlink "$zshrc")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$zshrc" && ! -w "$zshrc" ]]; then
        is_readonly=true
    fi
    
    # If .zshrc is read-only, try alternative approaches
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only zsh configuration (possibly NixOS/home-manager)"
        
        # Try .zshrc.local (sourced by some configurations)
        if [[ -f "$zshrc" ]] && grep -q "zshrc.local\|\.local" "$zshrc" 2>/dev/null; then
            log "Using .zshrc.local for integration"
            config_file="$zshrc_local"
        else
            warn "Cannot automatically integrate with read-only configuration."
            warn "Please manually add the following line to your zsh configuration:"
            warn "  $source_line"
            warn ""
            warn "For NixOS users, add this to your home-manager configuration:"
            warn "  programs.zsh.initExtra = \"source \\\"$INSTALL_DIR/shells/zsh_wakaterm.zsh\\\"\";"
            return 1
        fi
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$config_file" 2>/dev/null; then
        warn "Zsh integration already configured"
        return 0
    fi
    
    # Create config file if it doesn't exist and we can write to it
    if [[ ! -f "$config_file" ]]; then
        if ! touch "$config_file" 2>/dev/null; then
            error "Failed to create $config_file"
            warn "Please manually add the following line to your zsh configuration:"
            warn "  $source_line"
            return 1
        fi
    fi
    
    # Add integration with tracking
    if ! echo "" >> "$config_file" 2>/dev/null; then
        error "Failed to write to $config_file"
        warn "Please manually add the following line to your zsh configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$config_file" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$config_file"
    
    success "Zsh integration added to $(basename -- "$config_file")"
    log "Please restart your terminal or run: source $config_file"
}

setup_fish_integration() {
    local fish_config="$HOME/.config/fish/config.fish"
    local source_line="source \"$INSTALL_DIR/shells/fish_wakaterm.fish\""
    local is_readonly=false
    
    # Create config directory if it doesn't exist
    if ! mkdir -p "$(dirname "$fish_config")" 2>/dev/null; then
        error "Failed to create fish config directory"
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        return 1
    fi
    
    # Check if config file is writable (not a symlink to read-only file)
    if [[ -L "$fish_config" ]]; then
        local target=$(readlink "$fish_config")
        if [[ "$target" =~ /nix/store || ! -w "$target" ]]; then
            is_readonly=true
        fi
    elif [[ -f "$fish_config" && ! -w "$fish_config" ]]; then
        is_readonly=true
    fi
    
    # If fish config is read-only, provide manual instructions
    if [[ "$is_readonly" == "true" ]]; then
        warn "Detected read-only fish configuration (possibly NixOS/home-manager)"
        warn "Cannot automatically integrate with read-only configuration."
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        warn ""
        warn "For NixOS users, add this to your home-manager configuration:"
        warn "  programs.fish.interactiveShellInit = \"source \\\"$INSTALL_DIR/shells/fish_wakaterm.fish\\\"\";"
        return 1
    fi
    
    # Check if already added
    if grep -Fq "$source_line" "$fish_config" 2>/dev/null; then
        warn "Fish integration already configured"
        return 0
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "$fish_config" ]]; then
        if ! touch "$fish_config" 2>/dev/null; then
            error "Failed to create $fish_config"
            warn "Please manually add the following line to your fish configuration:"
            warn "  $source_line"
            return 1
        fi
    fi
    
    # Add integration with tracking
    if ! echo "" >> "$fish_config" 2>/dev/null; then
        error "Failed to write to $fish_config"
        warn "Please manually add the following line to your fish configuration:"
        warn "  $source_line"
        return 1
    fi
    
    local integration_content="
# WakaTerm NG Integration
$source_line"
    
    modify_file_with_backup "$fish_config" "$integration_content" "WakaTerm NG Integration"
    track_state "shell_integrations" "$fish_config"
    
    success "Fish integration added to config.fish"
    log "Please restart your terminal or run: source ~/.config/fish/config.fish"
}