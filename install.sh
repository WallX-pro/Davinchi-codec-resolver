#!/usr/bin/env bash
# =============================================================================
#  install.sh — Universal Installer for convert-video
#  Works on any Linux distribution with bash 4+ and an internet or local copy.
#
#  What this script does:
#    1. Detects your package manager and installs ffmpeg if missing
#    2. Verifies ffmpeg includes the DNxHD/DNxHR encoder
#    3. Installs convert-video to ~/.local/bin (no sudo required)
#    4. Adds ~/.local/bin to your PATH in .bashrc / .zshrc if needed
#    5. Prints a verification summary
#
#  Usage:
#    chmod +x install.sh
#    ./install.sh
# =============================================================================

set -euo pipefail

# ─── Colours ─────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$(tput bold 2>/dev/null || printf '')
    RESET=$(tput sgr0 2>/dev/null || printf '')
    RED=$(tput setaf 1 2>/dev/null || printf '')
    GREEN=$(tput setaf 2 2>/dev/null || printf '')
    YELLOW=$(tput setaf 3 2>/dev/null || printf '')
    CYAN=$(tput setaf 6 2>/dev/null || printf '')
else
    BOLD='' RESET='' RED='' GREEN='' YELLOW='' CYAN=''
fi

log_info()  { printf '%s[INFO]%s  %s\n'  "${CYAN}"   "${RESET}" "$*"; }
log_ok()    { printf '%s[ OK ]%s  %s\n'  "${GREEN}"  "${RESET}" "$*"; }
log_warn()  { printf '%s[WARN]%s  %s\n'  "${YELLOW}" "${RESET}" "$*" >&2; }
log_error() { printf '%s[ERR]%s   %s\n'  "${RED}"    "${RESET}" "$*" >&2; }
log_step()  { printf '\n%s══ %s%s\n'     "${CYAN}${BOLD}" "$*" "${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="convert-video"
INSTALL_DIR="${HOME}/.local/bin"

# ─────────────────────────── Banner ──────────────────────────────────────────
printf '%s\n' "${CYAN}${BOLD}"
printf '  ╔══════════════════════════════════════════════════════╗\n'
printf '  ║     codec-resolver — Universal Installer             ║\n'
printf '  ║     convert-video for DaVinci Resolve on Linux       ║\n'
printf '  ╚══════════════════════════════════════════════════════╝\n'
printf '%s\n\n' "${RESET}"

# ─────────────────────────── 1. Detect OS / package manager ──────────────────
log_step "Detecting system"

DISTRO="unknown"
PKG_MGR="unknown"

if   command -v pacman  &>/dev/null; then PKG_MGR="pacman";  DISTRO="Arch"
elif command -v apt-get &>/dev/null; then PKG_MGR="apt";     DISTRO="Debian/Ubuntu"
elif command -v dnf     &>/dev/null; then PKG_MGR="dnf";     DISTRO="Fedora/RHEL"
elif command -v zypper  &>/dev/null; then PKG_MGR="zypper";  DISTRO="openSUSE"
elif command -v xbps-install &>/dev/null; then PKG_MGR="xbps"; DISTRO="Void"
elif command -v emerge  &>/dev/null; then PKG_MGR="emerge";  DISTRO="Gentoo"
elif command -v nix-env &>/dev/null; then PKG_MGR="nix";     DISTRO="NixOS"
fi

log_info "Detected: ${DISTRO} (package manager: ${PKG_MGR})"

# ─────────────────────────── 2. Check / install ffmpeg ───────────────────────
log_step "Checking FFmpeg"

install_ffmpeg() {
    log_info "FFmpeg not found. Attempting to install..."
    case "$PKG_MGR" in
        pacman)  sudo pacman -S --needed --noconfirm ffmpeg ;;
        apt)     sudo apt-get update -qq && sudo apt-get install -y ffmpeg ;;
        dnf)     sudo dnf install -y ffmpeg 2>/dev/null \
                     || { log_warn "Trying RPM Fusion fallback..."
                          sudo dnf install -y \
                              https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                              2>/dev/null || true
                          sudo dnf install -y ffmpeg; } ;;
        zypper)  sudo zypper install -y ffmpeg ;;
        xbps)    sudo xbps-install -Sy ffmpeg ;;
        emerge)  sudo emerge --ask=n media-video/ffmpeg ;;
        nix)     nix-env -iA nixpkgs.ffmpeg ;;
        *)
            log_error "Cannot auto-install ffmpeg: unknown package manager."
            log_error "Please install ffmpeg manually, then re-run this installer."
            log_error ""
            log_error "Static build (works on any distro):"
            log_error "  wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
            log_error "  tar xf ffmpeg-release-amd64-static.tar.xz"
            log_error "  sudo cp ffmpeg-*/ffmpeg ffmpeg-*/ffprobe /usr/local/bin/"
            exit 1
            ;;
    esac
}

if command -v ffmpeg &>/dev/null; then
    FFMPEG_VER=$(ffmpeg -version 2>&1 | head -1)
    log_ok "ffmpeg found: ${FFMPEG_VER}"
else
    install_ffmpeg
    if ! command -v ffmpeg &>/dev/null; then
        log_error "ffmpeg installation failed. Please install it manually."
        exit 1
    fi
    log_ok "ffmpeg installed successfully."
fi

if ! command -v ffprobe &>/dev/null; then
    log_error "ffprobe not found. It should be bundled with ffmpeg."
    log_error "Re-install ffmpeg to get ffprobe."
    exit 1
fi
log_ok "ffprobe found."

# ─────────────────────────── 3. Verify DNxHD encoder ─────────────────────────
log_step "Verifying DNxHD/DNxHR encoder"

ENC_LIST="$(ffmpeg -encoders 2>/dev/null || true)"
if ! printf '%s' "$ENC_LIST" | grep -q 'dnxhd'; then
    log_error "Your ffmpeg does NOT include the DNxHD/DNxHR encoder."
    log_error ""
    log_error "This can happen if your distro ships a stripped-down ffmpeg."
    log_error "Solutions:"
    log_error "  Arch:         sudo pacman -S ffmpeg"
    log_error "  Ubuntu:       sudo apt install ffmpeg"
    log_error "  Any distro:   use static build from https://johnvansickle.com/ffmpeg/"
    exit 1
fi
log_ok "DNxHD/DNxHR encoder is available."

# ─────────────────────────── 4. Install the script ───────────────────────────
log_step "Installing convert-video"

SCRIPT_SRC="${SCRIPT_DIR}/${SCRIPT_NAME}"
if [[ ! -f "$SCRIPT_SRC" ]]; then
    log_error "Cannot find '${SCRIPT_SRC}'."
    log_error "Make sure install.sh is in the same folder as convert-video."
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_SRC" "${INSTALL_DIR}/${SCRIPT_NAME}"
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"
log_ok "Installed to: ${INSTALL_DIR}/${SCRIPT_NAME}"

# ─────────────────────────── 5. PATH setup ───────────────────────────────────
log_step "Checking PATH"

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
ADDED_TO=()

# Helper: add PATH line to a shell rc file if not already present
add_to_rc() {
    local rcfile="$1"
    if [[ -f "$rcfile" ]]; then
        if grep -qF '.local/bin' "$rcfile" 2>/dev/null; then
            log_info "${rcfile}: ~/.local/bin already in PATH — no change needed."
        else
            printf '\n# Added by codec-resolver install.sh\n%s\n' "$PATH_LINE" >> "$rcfile"
            ADDED_TO+=("$rcfile")
            log_ok "Added PATH entry to: ${rcfile}"
        fi
    fi
}

add_to_rc "${HOME}/.bashrc"
add_to_rc "${HOME}/.zshrc"
add_to_rc "${HOME}/.profile"

# Check if it's already in current PATH
if [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]]; then
    log_ok "~/.local/bin is already active in current session PATH."
else
    log_warn "~/.local/bin is not in your current session PATH."
    log_warn "It will be available in new terminal sessions automatically."
    log_warn "To activate it NOW without opening a new terminal, run:"
    log_warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ─────────────────────────── 6. Verify ───────────────────────────────────────
log_step "Verification"

export PATH="${INSTALL_DIR}:${PATH}"   # make it available immediately in this process

if command -v convert-video &>/dev/null; then
    log_ok "convert-video is accessible as a command."
else
    log_warn "convert-video is not yet in PATH for this session."
    log_warn "Open a new terminal or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ─────────────────────────── Summary ─────────────────────────────────────────
printf '\n'
printf '%s%s══════════════════════════════════════════════════%s\n' \
       "${CYAN}" "${BOLD}" "${RESET}"
printf '%s  ✅  Installation complete!%s\n' "${GREEN}${BOLD}" "${RESET}"
printf '%s══════════════════════════════════════════════════%s\n\n' \
       "${CYAN}${BOLD}" "${RESET}"

printf '%sScript location:%s  %s\n' "${BOLD}" "${RESET}" "${INSTALL_DIR}/${SCRIPT_NAME}"
printf '%sHow to use:%s\n' "${BOLD}" "${RESET}"
printf '  convert-video recording.mp4\n'
printf '  convert-video *.mp4 *.mkv\n'
printf '  convert-video --quality hq clip.mp4\n'
printf '  convert-video --help\n'
printf '\n'
printf '%sRead the full guide:%s\n' "${BOLD}" "${RESET}"
printf '  %s\n' "${SCRIPT_DIR}/GUIDE.md"
printf '\n'
