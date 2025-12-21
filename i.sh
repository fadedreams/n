#!/bin/bash

set -euo pipefail

# Detect the OS family using /etc/os-release
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    echo "Error: Cannot detect distribution (/etc/os-release not found)."
    exit 1
fi

echo "Detected distribution: $NAME ($ID)"

# Enable EPEL repository for RHEL-based systems (Rocky, Alma, CentOS, RHEL, etc.)
if [[ "$DISTRO_LIKE" =~ rhel || "$DISTRO_LIKE" =~ fedora || "$DISTRO_ID" == "rocky" || "$DISTRO_ID" == "almalinux" || "$DISTRO_ID" == "centos" ]]; then
    echo "Enabling EPEL repository for extra packages..."
    sudo dnf install -y epel-release
fi

# Temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

# Main installation logic
if [[ "$DISTRO_ID" =~ ^(debian|ubuntu)$ || "$DISTRO_LIKE" =~ debian ]]; then
    echo "Using apt for Debian-based system..."
    sudo apt update
    sudo apt install -y build-essential software-properties-common git ripgrep xclip fd-find fzf p7zip-full colordiff

    if ! command -v fd >/dev/null 2>&1; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi

elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" =~ fedora || "$DISTRO_LIKE" =~ rhel ]]; then
    echo "Using dnf for Fedora/RHEL-based system (including Rocky Linux)..."
    sudo dnf install -y gcc gcc-c++ make git ripgrep xclip fd-find fzf p7zip p7zip-plugins colordiff

    if ! command -v fd >/dev/null 2>&1; then
        sudo ln -sf "$(command -v fd-find)" /usr/local/bin/fd
    fi

else
    echo "Unsupported distribution: $ID - attempting partial + manual installs."
    sudo dnf install -y epel-release || true
    sudo dnf install -y git ripgrep xclip fzf p7zip p7zip-plugins colordiff || true
    sudo apt update && sudo apt install -y git ripgrep xclip fzf p7zip-full colordiff || true

    # Manual fzf fallback
    FZF_VERSION="0.67.0"
    FZF_ARCH="amd64"
    FZF_TAR="fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz"
    FZF_URL="https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/${FZF_TAR}"
    curl -L -o "$FZF_TAR" "$FZF_URL"
    tar -xzf "$FZF_TAR"
    sudo mv fzf /usr/local/bin/
    sudo chmod +x /usr/local/bin/fzf

    # Manual fd fallback
    FD_VERSION="v10.3.0"
    FD_ARCH="x86_64-unknown-linux-gnu"
    FD_TAR="fd-${FD_VERSION}-${FD_ARCH}.tar.gz"
    FD_URL="https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/${FD_TAR}"
    curl -L -o "$FD_TAR" "$FD_URL"
    tar -xzf "$FD_TAR"
    sudo mv "${FD_TAR%.tar.gz}/fd" /usr/local/bin/
    sudo chmod +x /usr/local/bin/fd
fi

# --- Install Neovim v0.11.5 compatible with older glibc (Rocky 8, CentOS 8, etc.) ---
echo "Installing Neovim v0.11.5 (glibc-compatible build for older systems)..."
NVIM_VERSION="v0.11.5"
NVIM_TAR="nvim-linux-x86_64.tar.gz"
NVIM_URL="https://github.com/neovim/neovim-releases/releases/download/${NVIM_VERSION}/${NVIM_TAR}"

curl -L -o "$NVIM_TAR" "$NVIM_URL"
tar -xzf "$NVIM_TAR"

sudo rm -rf /usr/local/nvim
sudo mv nvim-linux-x86_64 /usr/local/nvim
sudo ln -sf /usr/local/nvim/bin/nvim /usr/local/bin/nvim

echo "Neovim ${NVIM_VERSION} (old glibc compatible) installed successfully."

# Verify installations
echo "Verifying installed tools..."
command -v git >/dev/null && echo "git installed" || echo "git missing"
command -v rg >/dev/null && echo "ripgrep installed" || echo "rg missing"
command -v xclip >/dev/null && echo "xclip installed" || echo "xclip missing"
command -v fd >/dev/null && echo "fd installed" || echo "fd missing"
command -v fzf >/dev/null && echo "fzf installed" || echo "fzf missing"
command -v 7z >/dev/null && echo "7-Zip (7z) installed" || echo "7-Zip missing"
command -v nvim >/dev/null && nvim --version | head -n1 && echo "Neovim installed" || echo "Neovim missing"

# ========================================
# Useful Aliases
# ========================================
echo "Adding useful aliases to ~/.bashrc..."

cat << 'EOF' >> ~/.bashrc

# ========================================
# Useful Aliases
# ========================================
alias v="nvim"
alias py="python3"
alias docker-compose="docker compose"
alias unproxy="unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy all_proxy ALL_PROXY"
alias dsa='docker stop $(docker ps -a -q)'
# ls aliases (with color and better defaults)
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias la='ls -A --color=auto' # show all except . and ..
alias l='ls -CF --color=auto' # compact with indicators
# Safety-first file operations
alias rm='rm -I' # prompt before removing >3 files or recursively
alias cp='cp -i' # prompt before overwrite
alias mv='mv -i' # prompt before overwrite
# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
# Grep with color
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
# Disk usage
alias df='df -h' # human readable
alias du='du -h' # human readable
alias dus='du -sh * | sort -hr' # like duf but includes hidden
# Misc utilities
alias path='echo -e ${PATH//:/\\n}' # pretty print PATH
alias now='date +"%T"'
alias nowdate='date +"%Y-%m-%d"'
alias ping='ping -c 5' # limit to 5 pings
alias diff='colordiff' # if colordiff is installed
# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --decorate --graph'
# Reload bashrc
alias reload='source ~/.bashrc'
# Clear screen quickly
alias c='clear'
# Show open ports
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'
# Quick HTTP server (Python)
alias serve='python3 -m http.server 8000'
# Copy current working directory
alias cwd='pwd | tr -d "\n" | xclip -selection clipboard && echo "PWD copied: $(pwd)"'
# Copy last command to clipboard
alias clast='fc -ln -1 | tr -d "\n" | xclip -selection clipboard && echo "Last command copied."'
EOF

# Source .bashrc to make aliases available immediately
echo "Reloading ~/.bashrc to activate aliases in this session..."
source ~/.bashrc 2>/dev/null || true

echo "Aliases added and activated!"
echo "You can now use 'v' for nvim, 'll', 'gs', and all the other shortcuts right away."

# ========================================
# Deploy your Neovim config
# ========================================
echo "Deploying your Neovim config from GitHub release..."
cd ~
curl -L -o n.7z https://github.com/fadedreams/n/releases/download/v1.0/n.7z || { echo "Download failed! Check URL or network."; exit 1; }

echo "Extracting config... (you will be prompted for the password)"
7z x n.7z -o.config/

# Only clean up if extraction succeeded
if [ $? -eq 0 ]; then
    rm n.7z
    echo "Neovim config deployed successfully!"
else
    echo "Extraction failed (wrong password or corrupted archive). Keeping n.7z for retry."
    exit 1
fi


