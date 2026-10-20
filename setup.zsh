#!/usr/bin/env zsh
# =============================================================================
# Cross-Platform Event Onboarding — macOS Setup Script (setup.zsh)
# =============================================================================
# Purpose:
#   Automates and verifies the local development environment for event
#   participants on macOS (Apple Silicon and Intel):
#     1. Git CLI
#     2. Node.js (LTS >= 18) & npm
#     3. Zepher CLI (zepher-cli -> zepher)
#     4. Orca Desktop Application (Orca.app)
#     5. Orca CLI (orca)
#
#   Works both when cloned via Git and when run from an extracted GitHub ZIP
#   archive (or via './bootstrap.zsh') on a clean Mac without Git or Homebrew.
#
# Usage:
#   chmod +x setup.zsh
#   ./setup.zsh
#
# Options:
#   --check-only, --dry-run   Inspect and verify tools without installing anything
#   --no-prompt               Run non-interactively without pausing for prompts
#   --help, -h                Show usage information and exit
#
# Security & Safety Principles:
#   - Never pipes remote scripts into a shell.
#   - Verifies SHA-256 checksums / Apple code signatures on standalone downloads.
#   - Prefers per-user installations to avoid unnecessary administrator privileges.
#   - Never collects, prints, or transmits API keys, tokens, or credentials.
#   - Never modifies shell startup files (~/.zshrc, ~/.zprofile, etc.).
#   - Safe, resumable, and idempotent to run repeatedly.
# =============================================================================

emulate -L zsh
setopt PIPE_FAIL
setopt NO_UNSET

# -----------------------------------------------------------------------------
# Organizer Configuration Section (Isolated for easy maintenance)
# -----------------------------------------------------------------------------
readonly REPO_WEB_URL="${ONBOARD_REPO_WEB_URL:-https://github.com/The-Fable-Club/beyond-the-prompt}"
readonly REPO_ZIP_URL="${ONBOARD_REPO_ZIP_URL:-https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip}"

readonly ZEPHER_NPM_PACKAGE="zepher-cli"
readonly ZEPHER_BIN_NAME="zepher"
readonly ZEPHER_NPM_URL="https://www.npmjs.com/package/zepher-cli"
readonly ZEPHER_GITHUB_URL="https://github.com/YUVARAJ-R-ai/zepher"
readonly MIN_NODE_MAJOR=18
readonly HOMEBREW_NODE_FORMULA="node@22"
readonly NODE_DIST_BASE_URL="${ONBOARD_NODE_DIST_BASE_URL:-https://nodejs.org/dist/latest-v22.x}"

readonly ORCA_BREW_CASK="stablyai/orca/orca"
readonly ORCA_WEBSITE_URL="https://www.onorca.dev"
readonly ORCA_INSTALL_DOCS_URL="https://www.onorca.dev/docs/install"
readonly ORCA_CLI_DOCS_URL="https://www.onorca.dev/docs/cli/overview"
readonly ORCA_DMG_ARM64_URL="https://github.com/stablyai/orca/releases/latest/download/orca-macos-arm64.dmg"
readonly ORCA_DMG_X64_URL="https://github.com/stablyai/orca/releases/latest/download/orca-macos-x64.dmg"
readonly ORCA_RELEASES_API_URL="${ONBOARD_ORCA_RELEASES_API_URL:-https://api.github.com/repos/stablyai/orca/releases/latest}"
readonly ORCA_RELEASES_URL="https://github.com/stablyai/orca/releases"

readonly GIT_MACOS_URL="https://git-scm.com/download/mac"
readonly NODE_DOWNLOAD_URL="https://nodejs.org/en/download"
readonly HOMEBREW_DOCS_URL="https://brew.sh"

# -----------------------------------------------------------------------------
# Runtime State & Result Tracking
# -----------------------------------------------------------------------------
CHECK_ONLY="${ONBOARD_CHECK_ONLY:-0}"
NO_PROMPT="${ONBOARD_NO_PROMPT:-0}"
NETWORK_AVAILABLE=0
ARCH_NAME="unknown"
IS_APPLE_SILICON=0
HAS_HOMEBREW=0
NEW_TERMINAL_ADVISED=0

STATUS_GIT="FAIL"
DETAIL_GIT="Not checked"

STATUS_NODE="FAIL"
DETAIL_NODE="Not checked"

STATUS_ZEPHER="FAIL"
DETAIL_ZEPHER="Not checked"

STATUS_ORCA_APP="FAIL"
DETAIL_ORCA_APP="Not checked"

STATUS_ORCA_CLI="FAIL"
DETAIL_ORCA_CLI="Not checked"

typeset -a RECOVERY_NOTES
RECOVERY_NOTES=()

# -----------------------------------------------------------------------------
# Terminal Formatting Helpers
# -----------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_GREEN=$'\033[1;32m'
  readonly C_YELLOW=$'\033[1;33m'
  readonly C_RED=$'\033[1;31m'
  readonly C_CYAN=$'\033[1;36m'
  readonly C_BLUE=$'\033[1;34m'
else
  readonly C_RESET=""
  readonly C_BOLD=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_RED=""
  readonly C_CYAN=""
  readonly C_BLUE=""
fi

print_banner() {
  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  AI Development Event — macOS Environment Onboarding (setup.zsh)${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "This script independently detects and prepares your event tools:"
  print "  1. Git CLI                 (Version control)"
  print "  2. Node.js & npm           (JavaScript runtime >= v${MIN_NODE_MAJOR} LTS & package manager)"
  print "  3. Zepher CLI              (npm package: ${ZEPHER_NPM_PACKAGE} -> '${ZEPHER_BIN_NAME}')"
  print "  4. Orca Desktop App        (Agent Development Environment)"
  print "  5. Orca CLI                ('orca' command registered via Orca Settings)"
  print ""
  print "${C_BLUE}Note on macOS Execution Permissions:${C_RESET}"
  print "  If macOS ever blocks this script from running, execute:"
  print "    chmod +x setup.zsh"
  print "    xattr -d com.apple.quarantine setup.zsh 2>/dev/null || true"
  print ""
  print "${C_BLUE}Privacy & Security:${C_RESET}"
  print "  - Works even if Git and Homebrew are not pre-installed."
  print "  - Existing working installations are preserved and never overwritten."
  print "  - Standalone installers are verified with SHA-256 / Apple code signatures."
  print "  - Prefers per-user locations (~/.local, ~/Applications) to avoid sudo."
  print "  - Shell startup files (~/.zshrc, ~/.zprofile) are never modified."
  print "  - No API keys, tokens, or personal credentials are requested or collected."
  if [[ "$CHECK_ONLY" == "1" ]]; then
    print ""
    print "${C_YELLOW}[MODE] Running in --check-only mode (no installations will be performed).${C_RESET}"
  fi
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
}

print_step() {
  print ""
  print "${C_BOLD}${C_BLUE}==> $1${C_RESET}"
}

print_info() {
  print "    [INFO] $1"
}

print_pass() {
  print "    ${C_GREEN}[PASS]${C_RESET} $1"
}

print_skip() {
  print "    ${C_GREEN}[SKIPPED]${C_RESET} $1"
}

print_action() {
  print "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} $1"
}

print_fail() {
  print "    ${C_RED}[FAIL]${C_RESET} $1"
}

add_recovery_note() {
  RECOVERY_NOTES+=("$1")
}

show_help() {
  cat <<EOF
Usage: ./setup.zsh [OPTIONS]

macOS onboarding script for the AI Development Event.

Options:
  --check-only, --dry-run   Verify installed tools without making any system changes
  --no-prompt               Do not pause for interactive confirmation prompts
  --bootstrap               Download & extract full repository ZIP before running
  --local-zip <FILE>        Bootstrap repository from a local .zip archive
  --zip-url <URL>           Override repository ZIP download URL
  --sha256 <HASH>           Verify ZIP archive against expected SHA-256 hash
  --help, -h                Show this help message and exit

If macOS blocks script execution due to permissions:
  chmod +x setup.zsh
  ./setup.zsh
EOF
}

# -----------------------------------------------------------------------------
# Standalone Bootstrap Routine (Runs when invoked alone or when requested)
# -----------------------------------------------------------------------------
run_standalone_bootstrap() {
  local target_zip_url="$1"
  local target_local_zip="$2"
  local target_sha256="$3"
  shift 3
  local -a forward_args
  forward_args=("$@")

  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  AI Development Event — Standalone Repository Bootstrap${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "  - Bootstrapping repository files into a verified temporary workspace..."
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

  local temp_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/onboard-bootstrap.XXXXXX")"
  local archive_file="${temp_dir}/repo.zip"

  if [[ -n "$target_local_zip" ]]; then
    print "    [INFO] Bootstrapping from local ZIP archive: ${target_local_zip}"
    if [[ ! -f "$target_local_zip" ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} Local ZIP file not found: ${target_local_zip}" >&2
      rm -rf "$temp_dir"
      return 1
    fi
    cp "$target_local_zip" "$archive_file"
  else
    if [[ -z "$target_zip_url" ]] || [[ "$target_zip_url" == *"<"* ]]; then
      print "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} Repository ZIP URL placeholder has not been configured yet."
      print "    Please download the repository ZIP from GitHub and run:"
      print "      ./setup.zsh --local-zip ~/Downloads/<repo>.zip"
      rm -rf "$temp_dir"
      return 1
    fi

    if [[ "$target_zip_url" != https://* ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} Refusing insecure or non-HTTPS ZIP URL: ${target_zip_url}" >&2
      rm -rf "$temp_dir"
      return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
      print "    ${C_RED}[FAIL]${C_RESET} 'curl' is required to download the repository archive." >&2
      rm -rf "$temp_dir"
      return 1
    fi

    print "    [INFO] Downloading repository archive from: ${target_zip_url}"
    if ! curl -fL --retry 2 --connect-timeout 10 -o "$archive_file" "$target_zip_url"; then
      print "    ${C_RED}[FAIL]${C_RESET} Failed to download repository ZIP from ${target_zip_url}" >&2
      print "    [INFO] Please download the ZIP manually in your browser and run:" >&2
      print "           ./setup.zsh --local-zip ~/Downloads/<repo>.zip" >&2
      rm -rf "$temp_dir"
      return 1
    fi
  fi

  # Verify ZIP magic bytes (PK\x03\x04)
  local magic_hex=""
  magic_hex="$(head -c 4 "$archive_file" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$magic_hex" != "504b0304" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} File is not a valid ZIP archive (magic header: '${magic_hex:-none}', expected '504b0304')." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  # Optional SHA-256 check
  if [[ -n "$target_sha256" ]]; then
    local actual_sha256
    actual_sha256="$(shasum -a 256 "$archive_file" 2>/dev/null | awk '{print tolower($1)}' || true)"
    if [[ "$actual_sha256" != "${target_sha256:l}" ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} SHA-256 checksum mismatch for repository ZIP!" >&2
      print "           Expected: ${target_sha256:l}" >&2
      print "           Actual  : ${actual_sha256:-unknown}" >&2
      rm -rf "$temp_dir"
      return 1
    fi
    print "    ${C_GREEN}[PASS]${C_RESET} SHA-256 checksum verified (${actual_sha256})."
  fi

  if ! unzip -tq "$archive_file" >/dev/null 2>&1; then
    print "    ${C_RED}[FAIL]${C_RESET} ZIP archive integrity check failed." >&2
    rm -rf "$temp_dir"
    return 1
  fi
  print "    ${C_GREEN}[PASS]${C_RESET} ZIP archive integrity verified."

  local extract_dir="${temp_dir}/extracted"
  mkdir -p "$extract_dir"
  if ! unzip -q "$archive_file" -d "$extract_dir"; then
    print "    ${C_RED}[FAIL]${C_RESET} Failed to extract ZIP archive." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  local found_script
  found_script="$(find "$extract_dir" -maxdepth 3 -type f -name "setup.zsh" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$found_script" ]] || [[ ! -s "$found_script" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} Could not locate 'setup.zsh' inside extracted archive." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  chmod +x "$found_script" 2>/dev/null || true
  print "    ${C_GREEN}[PASS]${C_RESET} Extracted and launching setup.zsh..."
  print ""

  ONBOARD_SKIP_AUTO_BOOTSTRAP=1 /bin/zsh "$found_script" "${forward_args[@]}"
  local child_rc=$?
  rm -rf "$temp_dir"
  return $child_rc
}

# -----------------------------------------------------------------------------
# Parse Command-Line Arguments
# -----------------------------------------------------------------------------
BOOTSTRAP_REQUESTED=0
BOOTSTRAP_LOCAL_ZIP=""
BOOTSTRAP_ZIP_URL="$REPO_ZIP_URL"
BOOTSTRAP_SHA256=""
typeset -a FORWARD_ARGS
FORWARD_ARGS=()

while (( $# > 0 )); do
  case "$1" in
    --check-only|--dry-run)
      CHECK_ONLY=1
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --no-prompt|--non-interactive)
      NO_PROMPT=1
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --bootstrap)
      BOOTSTRAP_REQUESTED=1
      shift
      ;;
    --local-zip)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --local-zip requires a file path argument.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_REQUESTED=1
      BOOTSTRAP_LOCAL_ZIP="$2"
      shift 2
      ;;
    --zip-url)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --zip-url requires a URL argument.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_REQUESTED=1
      BOOTSTRAP_ZIP_URL="$2"
      shift 2
      ;;
    --sha256)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --sha256 requires a 64-character hex digest.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_SHA256="$2"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      print "${C_RED}Unknown option: $1${C_RESET}"
      show_help
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-bootstrap if explicitly requested OR running standalone without repo context
if [[ "$BOOTSTRAP_REQUESTED" == "1" ]] || \
   { [[ ! -f "${SCRIPT_DIR}/README.md" ]] && [[ ! -f "${SCRIPT_DIR}/setup.bat" ]] && [[ "${ONBOARD_SKIP_AUTO_BOOTSTRAP:-0}" != "1" ]]; }; then
  run_standalone_bootstrap "$BOOTSTRAP_ZIP_URL" "$BOOTSTRAP_LOCAL_ZIP" "$BOOTSTRAP_SHA256" "${FORWARD_ARGS[@]}"
  exit $?
fi

# -----------------------------------------------------------------------------
# Refresh Session PATH (In-Memory Only — Does Not Modify Shell Startup Files)
# -----------------------------------------------------------------------------
refresh_session_path() {
  if [[ "${ONBOARD_DISABLE_PATH_REFRESH:-0}" == "1" ]]; then
    return 0
  fi

  local -a candidate_dirs
  candidate_dirs=(
    "${HOME}/.local/node-lts/bin"
    "${HOME}/.local/bin"
    "${HOME}/.npm-global/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/opt/homebrew/opt/${HOMEBREW_NODE_FORMULA}/bin"
    "/opt/homebrew/opt/node@20/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/usr/local/opt/${HOMEBREW_NODE_FORMULA}/bin"
    "/usr/local/opt/node@20/bin"
    "${HOME}/.volta/bin"
    "${HOME}/.asdf/shims"
    "${HOME}/.fnm"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  )

  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local latest_nvm_bin
    latest_nvm_bin="$(find "${HOME}/.nvm/versions/node" -maxdepth 2 -type d -name bin 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$latest_nvm_bin" ]]; then
      candidate_dirs+=("$latest_nvm_bin")
    fi
  fi

  local dir
  for dir in "${candidate_dirs[@]}"; do
    if [[ -d "$dir" ]] && [[ ":${PATH}:" != *":${dir}:"* ]]; then
      export PATH="${PATH}:${dir}"
    fi
  done

  if command -v npm >/dev/null 2>&1; then
    local npm_prefix=""
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]] && [[ -d "${npm_prefix}/bin" ]] && [[ ":${PATH}:" != *":${npm_prefix}/bin:"* ]]; then
      export PATH="${PATH}:${npm_prefix}/bin"
    fi
  fi
}

# -----------------------------------------------------------------------------
# 0. Independent Prerequisite & Environment Detection
# -----------------------------------------------------------------------------
is_git_usable_macos() {
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  local git_path
  git_path="$(command -v git 2>/dev/null || true)"

  # On macOS, /usr/bin/git is an Apple shim that opens a GUI popup if Xcode
  # Command Line Tools are not installed. Check xcode-select -p first!
  if [[ "$git_path" == "/usr/bin/git" ]]; then
    local xcode_check_cmd="${ONBOARD_XCODE_CHECK_CMD:-xcode-select -p}"
    if ! eval "$xcode_check_cmd" >/dev/null 2>&1; then
      return 1
    fi
  fi

  git --version >/dev/null 2>&1
  return $?
}

find_orca_app_macos() {
  local -a search_paths
  if [[ -n "${ONBOARD_ORCA_APP_PATHS:-}" ]]; then
    search_paths=("${(@s/:/)ONBOARD_ORCA_APP_PATHS}")
  else
    search_paths=(
      "/Applications/Orca.app"
      "${HOME}/Applications/Orca.app"
    )
  fi

  local candidate
  for candidate in "${search_paths[@]}"; do
    if [[ -d "$candidate" ]]; then
      print "$candidate"
      return 0
    fi
  done
  return 1
}

detect_environment() {
  print_step "Step 0: Detecting Operating System, Architecture & Independent Tool States"

  local os_name
  os_name="$(uname -s 2>/dev/null || echo "Unknown")"
  ARCH_NAME="$(uname -m 2>/dev/null || echo "Unknown")"

  print_info "Running script  : setup.zsh (Zsh ${ZSH_VERSION:-unknown})"
  print_info "Operating System: ${os_name}"

  if [[ "$os_name" != "Darwin" ]]; then
    print_action "Detected non-macOS platform (${os_name}). This script is designed for macOS."
    print_info "On Windows, please run: setup.bat in Command Prompt."
  fi

  # Detect Apple Silicon even if running inside a Rosetta 2 x86_64 terminal
  local arm64_capable="0"
  arm64_capable="$(sysctl -n hw.optional.arm64 2>/dev/null || echo "0")"
  if [[ "$ARCH_NAME" == "arm64" ]] || [[ "$arm64_capable" == "1" ]]; then
    IS_APPLE_SILICON=1
    if [[ "$ARCH_NAME" != "arm64" ]]; then
      print_info "Architecture    : Apple Silicon (arm64 hardware running under Rosetta 2 x86_64 translation)"
    else
      print_info "Architecture    : Apple Silicon (arm64)"
    fi
  else
    IS_APPLE_SILICON=0
    print_info "Architecture    : Intel (${ARCH_NAME})"
  fi

  refresh_session_path

  # Independent detection snapshot (never assumes any package manager or tool exists)
  if [[ "${ONBOARD_FORCE_NO_BREW:-0}" != "1" ]] && command -v brew >/dev/null 2>&1; then
    HAS_HOMEBREW=1
    local brew_ver
    brew_ver="$(brew --version 2>/dev/null | head -n 1 || echo "Homebrew")"
    print_info "Detect Homebrew : Found (${brew_ver} at $(command -v brew))"
  else
    HAS_HOMEBREW=0
    print_info "Detect Homebrew : Not installed (will use official standalone installers)"
  fi

  if is_git_usable_macos; then
    print_info "Detect Git CLI  : Found ($(command -v git))"
  else
    print_info "Detect Git CLI  : Not found"
  fi

  if command -v node >/dev/null 2>&1; then
    print_info "Detect Node.js  : Found ($(node --version 2>/dev/null | head -n 1 || echo "unknown") at $(command -v node))"
  else
    print_info "Detect Node.js  : Not found"
  fi

  if command -v npm >/dev/null 2>&1; then
    print_info "Detect npm      : Found (v$(npm --version 2>/dev/null | head -n 1 || echo "unknown") at $(command -v npm))"
  else
    print_info "Detect npm      : Not found"
  fi

  if command -v "${ZEPHER_BIN_NAME}" >/dev/null 2>&1; then
    print_info "Detect Zepher   : Found ($(command -v "${ZEPHER_BIN_NAME}"))"
  else
    print_info "Detect Zepher   : Not found"
  fi

  local snap_orca_app=""
  if snap_orca_app="$(find_orca_app_macos)"; then
    print_info "Detect Orca App : Found (${snap_orca_app})"
  else
    print_info "Detect Orca App : Not found"
  fi

  if command -v orca >/dev/null 2>&1; then
    print_info "Detect Orca CLI : Found ($(command -v orca))"
  else
    print_info "Detect Orca CLI : Not found"
  fi
}

check_network() {
  print_step "Step 1: Checking Network Connectivity"

  if [[ "${ONBOARD_SIMULATE_OFFLINE:-0}" == "1" ]]; then
    NETWORK_AVAILABLE=0
    print_action "Network check simulated as OFFLINE (ONBOARD_SIMULATE_OFFLINE=1)."
    print_info "Existing local installations will still be checked."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    NETWORK_AVAILABLE=0
    print_action "'curl' is not available to verify network access."
    return 0
  fi

  if curl -fsSI --max-time 8 "https://registry.npmjs.org" >/dev/null 2>&1 || \
     curl -fsSI --max-time 8 "${ORCA_WEBSITE_URL}" >/dev/null 2>&1; then
    NETWORK_AVAILABLE=1
    print_pass "Internet connection verified."
  else
    NETWORK_AVAILABLE=0
    print_action "Unable to reach external package servers (https://registry.npmjs.org)."
    print_info "Already-installed tools will still be verified, but downloads cannot proceed while offline."
  fi
}

# -----------------------------------------------------------------------------
# 1. Git CLI
# -----------------------------------------------------------------------------
check_and_setup_git() {
  print_step "Step 2: Checking Git CLI"

  if is_git_usable_macos; then
    local git_ver
    git_ver="$(git --version 2>/dev/null | head -n 1)"
    STATUS_GIT="SKIPPED"
    DETAIL_GIT="Already installed (${git_ver})"
    print_skip "Git is already installed and available on PATH: ${git_ver}"
    return 0
  fi

  print_info "Git CLI was not detected (or Apple Command Line Tools are not yet installed)."
  print_info "Bootstrap Note: If you haven't cloned the repo yet, you can always use './bootstrap.zsh' or GitHub's 'Download ZIP'."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_GIT="FAIL"
    DETAIL_GIT="Missing (not installed; ran with --check-only)"
    print_fail "Git is not installed."
    add_recovery_note "Git CLI: Run 'xcode-select --install' in Terminal (or download from ${GIT_MACOS_URL}), then re-run ./setup.zsh."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GIT="FAIL"
    DETAIL_GIT="Missing and cannot install while offline"
    print_fail "Git is missing and network connectivity is unavailable."
    add_recovery_note "Git CLI: Connect to the internet and run 'xcode-select --install' or download from ${GIT_MACOS_URL}."
    return 0
  fi

  # Prefer Apple's Command Line Tools on macOS (works without Homebrew!)
  if command -v xcode-select >/dev/null 2>&1; then
    print_info "Requesting Apple Command Line Developer Tools installation ('xcode-select --install')..."
    print_info "A macOS dialog window may appear asking you to click 'Install' and agree to the license."

    xcode-select --install >/dev/null 2>&1
    local xcs_rc=$?

    if is_git_usable_macos; then
      local git_ver_after
      git_ver_after="$(git --version 2>/dev/null | head -n 1)"
      STATUS_GIT="PASS"
      DETAIL_GIT="Installed (${git_ver_after})"
      print_pass "Git installed and verified: ${git_ver_after}"
      return 0
    fi

    # xcode-select --install launches an asynchronous GUI installer on macOS.
    # Never falsely claim installation completed while the dialog is still running.
    if [[ "$xcs_rc" -eq 0 ]]; then
      STATUS_GIT="ACTION REQUIRED"
      DETAIL_GIT="macOS Command Line Tools installer launched — complete the GUI prompt"
      print_action "The macOS Command Line Developer Tools installer dialog has been opened."
      print_info "Please complete the installation in the macOS popup window, then re-run ./setup.zsh."
      add_recovery_note "Git CLI: Complete the macOS 'Install Command Line Developer Tools' popup window, or install via '${GIT_MACOS_URL}', then re-run ./setup.zsh."
      return 0
    fi
  fi

  # Fallback: If Homebrew is available, try brew install git
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Attempting to install Git via Homebrew ('brew install git')..."
    if brew install git; then
      refresh_session_path
      if is_git_usable_macos; then
        local git_ver_brew
        git_ver_brew="$(git --version 2>/dev/null | head -n 1)"
        STATUS_GIT="PASS"
        DETAIL_GIT="Installed via Homebrew (${git_ver_brew})"
        print_pass "Git installed and verified: ${git_ver_brew}"
        return 0
      fi
    fi
  fi

  STATUS_GIT="FAIL"
  DETAIL_GIT="Automatic installation did not complete"
  print_fail "Could not verify a working Git installation."
  print_info "Official download & instructions: ${GIT_MACOS_URL}"
  add_recovery_note "Git CLI: Run 'xcode-select --install' or download Git from ${GIT_MACOS_URL}, then open a new terminal and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 2. Node.js and npm (Homebrew or Official Verified Standalone Per-User Archive)
# -----------------------------------------------------------------------------
detect_node_version_manager() {
  local managers=()
  [[ -n "${NVM_DIR:-}" || -d "${HOME}/.nvm" ]] && managers+=("nvm")
  [[ -n "${FNM_DIR:-}" || -d "${HOME}/.fnm" ]] && managers+=("fnm")
  [[ -n "${VOLTA_HOME:-}" || -d "${HOME}/.volta" ]] && managers+=("volta")
  [[ -n "${ASDF_DIR:-}" || -d "${HOME}/.asdf" ]] && managers+=("asdf")
  if (( ${#managers[@]} > 0 )); then
    print "${(j:, :)managers}"
  else
    print ""
  fi
}

parse_node_major() {
  local raw_ver="$1"
  local cleaned="${raw_ver#v}"
  local major="${cleaned%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]]; then
    print "$major"
  else
    print "0"
  fi
}

install_node_standalone_macos() {
  local arch_suffix="x64"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    arch_suffix="arm64"
  fi

  print_info "Homebrew is not installed. Using official Node.js v22 LTS standalone distribution (${arch_suffix})..."
  print_info "Fetching official SHA-256 checksum manifest from: ${NODE_DIST_BASE_URL}/SHASUMS256.txt"

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/node-standalone.XXXXXX")"

  local shasums_file="${tmp_dir}/SHASUMS256.txt"
  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "$shasums_file" "${NODE_DIST_BASE_URL}/SHASUMS256.txt"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download official Node.js SHASUMS256.txt manifest."
    return 1
  fi

  local match_line
  match_line="$(grep -E "node-v[0-9]+\.[0-9]+\.[0-9]+-darwin-${arch_suffix}\.tar\.gz$" "$shasums_file" | head -n 1 || true)"
  if [[ -z "$match_line" ]]; then
    rm -rf "$tmp_dir"
    print_fail "Could not locate darwin-${arch_suffix}.tar.gz entry in SHASUMS256.txt."
    return 1
  fi

  local expected_sha256 archive_name
  expected_sha256="$(print "$match_line" | awk '{print tolower($1)}')"
  archive_name="$(print "$match_line" | awk '{print $2}')"

  local archive_path="${tmp_dir}/${archive_name}"
  local download_url="${NODE_DIST_BASE_URL}/${archive_name}"

  print_info "Downloading official standalone Node.js archive: ${download_url}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "$archive_path" "$download_url"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download ${download_url}."
    return 1
  fi

  print_info "Verifying SHA-256 checksum against official Node.js manifest..."
  local actual_sha256
  actual_sha256="$(shasum -a 256 "$archive_path" 2>/dev/null | awk '{print tolower($1)}' || true)"

  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "SHA-256 checksum mismatch for ${archive_name}! Aborting installation."
    print_info "Expected: ${expected_sha256}"
    print_info "Actual  : ${actual_sha256:-unknown}"
    return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  local install_root="${ONBOARD_USER_NODE_DIR:-${HOME}/.local/node-lts}"
  local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"

  print_info "Installing Node.js per-user into '${install_root}' (no administrator/sudo required)..."
  mkdir -p "$install_root" "$user_bin_dir"

  if ! tar -xzf "$archive_path" -C "$install_root" --strip-components=1; then
    rm -rf "$tmp_dir"
    print_fail "Failed to extract ${archive_name} into ${install_root}."
    return 1
  fi

  rm -rf "$tmp_dir"

  # Create symlinks in ~/.local/bin so user tools are available in standard per-user bin
  local bin_item
  for bin_item in node npm npx corepack; do
    if [[ -x "${install_root}/bin/${bin_item}" ]]; then
      ln -sf "${install_root}/bin/${bin_item}" "${user_bin_dir}/${bin_item}"
    fi
  done

  if [[ ":${PATH}:" != *":${install_root}/bin:"* ]]; then
    export PATH="${PATH}:${install_root}/bin"
  fi
  if [[ ":${PATH}:" != *":${user_bin_dir}:"* ]]; then
    export PATH="${PATH}:${user_bin_dir}"
  fi

  NEW_TERMINAL_ADVISED=1
  print_info "Note for future terminal sessions: Ensure '${user_bin_dir}' is in your PATH:"
  print_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  return 0
}

check_and_setup_node() {
  print_step "Step 3: Checking Node.js (>= v${MIN_NODE_MAJOR} LTS) and npm"

  refresh_session_path

  local detected_managers
  detected_managers="$(detect_node_version_manager)"
  if [[ -n "$detected_managers" ]]; then
    print_info "Detected Node version manager footprint: ${detected_managers}"
  fi

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    local node_ver npm_ver node_major
    node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
    npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
    node_major="$(parse_node_major "$node_ver")"

    if (( node_major >= MIN_NODE_MAJOR )) && [[ -n "$npm_ver" ]]; then
      STATUS_NODE="SKIPPED"
      DETAIL_NODE="Already installed (Node ${node_ver}, npm v${npm_ver})"
      print_skip "Compatible Node.js (${node_ver}) and npm (v${npm_ver}) are already installed."
      return 0
    fi

    print_action "Detected Node.js ${node_ver:-unknown} (npm ${npm_ver:-unknown}), but ${ZEPHER_NPM_PACKAGE} requires Node.js >= v${MIN_NODE_MAJOR}.0.0."
    print_info "To avoid breaking your existing Node setup${detected_managers:+ (${detected_managers})}, this script will NOT overwrite it automatically."
    STATUS_NODE="FAIL"
    DETAIL_NODE="Installed Node ${node_ver:-unknown} is older than required v${MIN_NODE_MAJOR}+"
    if [[ -n "$detected_managers" ]]; then
      add_recovery_note "Node.js & npm: Upgrade Node to v${MIN_NODE_MAJOR}+ LTS using your version manager (${detected_managers}), e.g. 'nvm install --lts && nvm use --lts', or visit ${NODE_DOWNLOAD_URL}."
    else
      add_recovery_note "Node.js & npm: Upgrade Node.js to v${MIN_NODE_MAJOR}+ LTS via 'brew upgrade node' or the official installer at ${NODE_DOWNLOAD_URL}."
    fi
    return 0
  fi

  if command -v node >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
    local partial_node_ver
    partial_node_ver="$(node --version 2>/dev/null | head -n 1 || echo "unknown")"
    STATUS_NODE="FAIL"
    DETAIL_NODE="Node (${partial_node_ver}) found, but 'npm' is missing from PATH"
    print_fail "Node.js (${partial_node_ver}) is installed, but 'npm' was not found on PATH."
    add_recovery_note "Node.js & npm: Reinstall Node.js LTS (which bundles npm) from ${NODE_DOWNLOAD_URL} or fix your Node version manager PATH."
    return 0
  fi

  print_info "Node.js and npm were not found on PATH."

  if [[ -n "$detected_managers" ]]; then
    print_action "A Node version manager (${detected_managers}) directory exists on your machine, but 'node' is not on PATH."
    print_info "Skipping standalone/system Node installation to avoid conflicting with ${detected_managers}."
    STATUS_NODE="ACTION REQUIRED"
    DETAIL_NODE="Version manager (${detected_managers}) detected, but Node/npm not active on PATH"
    add_recovery_note "Node.js & npm: Activate your version manager (${detected_managers}) and install Node LTS (e.g., 'nvm install --lts'), or install from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing (not installed; ran with --check-only)"
    print_fail "Node.js and npm are not installed."
    add_recovery_note "Node.js & npm: Re-run './setup.zsh' without --check-only to install Node.js LTS automatically, or download from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing and cannot install while offline"
    print_fail "Cannot install Node.js because network connectivity is unavailable."
    add_recovery_note "Node.js & npm: Connect to the internet and re-run ./setup.zsh, or install Node.js LTS from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  # Route A: Homebrew is available
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Installing Node.js LTS via Homebrew ('brew install ${HOMEBREW_NODE_FORMULA}')..."
    if brew install "${HOMEBREW_NODE_FORMULA}"; then
      refresh_session_path
      if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local new_node_ver new_npm_ver new_major
        new_node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
        new_npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
        new_major="$(parse_node_major "$new_node_ver")"
        if (( new_major >= MIN_NODE_MAJOR )) && [[ -n "$new_npm_ver" ]]; then
          STATUS_NODE="PASS"
          DETAIL_NODE="Installed via Homebrew (Node ${new_node_ver}, npm v${new_npm_ver})"
          NEW_TERMINAL_ADVISED=1
          print_pass "Installed and verified Node.js (${new_node_ver}) and npm (v${new_npm_ver})."
          print_info "Note: Open a new terminal window after setup (or run 'brew link --overwrite ${HOMEBREW_NODE_FORMULA}') if 'node' is not found in other tabs."
          return 0
        fi
      fi
    fi
    print_info "Homebrew Node installation did not complete; attempting official standalone Node.js LTS installer..."
  fi

  # Route B: Official verified standalone per-user distribution from nodejs.org (works without Homebrew or sudo!)
  if install_node_standalone_macos; then
    refresh_session_path
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      local std_node_ver std_npm_ver std_major
      std_node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
      std_npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
      std_major="$(parse_node_major "$std_node_ver")"
      if (( std_major >= MIN_NODE_MAJOR )) && [[ -n "$std_npm_ver" ]]; then
        STATUS_NODE="PASS"
        DETAIL_NODE="Installed per-user standalone LTS (Node ${std_node_ver}, npm v${std_npm_ver})"
        print_pass "Installed and verified standalone Node.js (${std_node_ver}) and npm (v${std_npm_ver})."
        return 0
      fi
    fi
  fi

  STATUS_NODE="FAIL"
  DETAIL_NODE="Standalone and package-manager installation failed"
  print_fail "Could not automatically install and verify Node.js + npm."
  print_info "Official Node.js LTS macOS installer (.pkg): ${NODE_DOWNLOAD_URL}"
  add_recovery_note "Node.js & npm: Download and run the official macOS (.pkg) LTS installer from ${NODE_DOWNLOAD_URL}, open a new terminal, and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 3. Zepher CLI (zepher-cli -> zepher)
# -----------------------------------------------------------------------------
verify_zepher_binary() {
  if ! command -v "${ZEPHER_BIN_NAME}" >/dev/null 2>&1; then
    return 1
  fi

  local ver_out
  ver_out="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1 || true)"
  if [[ -z "$ver_out" ]]; then
    return 1
  fi

  if ! "${ZEPHER_BIN_NAME}" --help >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

check_and_setup_zepher() {
  print_step "Step 4: Checking Zepher CLI (${ZEPHER_NPM_PACKAGE})"

  # Guard against accidental confusion with 'zephyr-cli'
  if [[ "${ZEPHER_NPM_PACKAGE}" == "zephyr-cli" ]] || [[ "${ZEPHER_NPM_PACKAGE}" != "zepher-cli" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Package identity mismatch (${ZEPHER_NPM_PACKAGE} != zepher-cli)"
    print_fail "Refusing to install '${ZEPHER_NPM_PACKAGE}'. Only verified package 'zepher-cli' is allowed (do not confuse with 'zephyr-cli')."
    add_recovery_note "Zepher CLI: Ensure ZEPHER_NPM_PACKAGE is set to 'zepher-cli' (${ZEPHER_NPM_URL})."
    return 0
  fi

  refresh_session_path

  if verify_zepher_binary; then
    local existing_zepher_ver
    existing_zepher_ver="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)"
    STATUS_ZEPHER="SKIPPED"
    DETAIL_ZEPHER="Already installed (${ZEPHER_BIN_NAME} v${existing_zepher_ver})"
    print_skip "Zepher CLI is already installed and verified: ${ZEPHER_BIN_NAME} v${existing_zepher_ver} ($(command -v "${ZEPHER_BIN_NAME}"))"
    return 0
  fi

  print_info "Zepher CLI ('${ZEPHER_BIN_NAME}') is not currently installed."

  if [[ "$STATUS_NODE" != "PASS" ]] && [[ "$STATUS_NODE" != "SKIPPED" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Blocked because Node.js (>= v${MIN_NODE_MAJOR}) & npm are not ready"
    print_fail "Cannot install ${ZEPHER_NPM_PACKAGE} because a compatible Node.js (>= v${MIN_NODE_MAJOR}) and npm environment is not available."
    add_recovery_note "Zepher CLI: First install Node.js LTS from ${NODE_DOWNLOAD_URL}, then run 'npm install -g ${ZEPHER_NPM_PACKAGE}'."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Missing (not installed; ran with --check-only)"
    print_fail "Zepher CLI (${ZEPHER_NPM_PACKAGE}) is not installed."
    add_recovery_note "Zepher CLI: Run 'npm install -g ${ZEPHER_NPM_PACKAGE}' and verify with '${ZEPHER_BIN_NAME} --version'."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Missing and cannot verify/install while offline"
    print_fail "Cannot verify or install ${ZEPHER_NPM_PACKAGE} without internet access."
    add_recovery_note "Zepher CLI: Connect to the internet and run 'npm install -g ${ZEPHER_NPM_PACKAGE}'."
    return 0
  fi

  # Verify exact package identity on npm before installing
  print_info "Verifying package identity for '${ZEPHER_NPM_PACKAGE}' against ${ZEPHER_NPM_URL}..."
  local pkg_name_remote pkg_bin_remote
  pkg_name_remote="$(npm view "${ZEPHER_NPM_PACKAGE}" name 2>/dev/null | tr -d '[:space:]' || true)"
  pkg_bin_remote="$(npm view "${ZEPHER_NPM_PACKAGE}" "bin.${ZEPHER_BIN_NAME}" 2>/dev/null | tr -d '[:space:]' || true)"

  if [[ "$pkg_name_remote" != "${ZEPHER_NPM_PACKAGE}" ]] || [[ -z "$pkg_bin_remote" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Could not verify '${ZEPHER_NPM_PACKAGE}' metadata on npm registry"
    print_fail "Could not verify package identity or '${ZEPHER_BIN_NAME}' executable for '${ZEPHER_NPM_PACKAGE}' on npm."
    print_info "Stopping installation step to avoid installing an unverified package. Official URL: ${ZEPHER_NPM_URL}"
    add_recovery_note "Zepher CLI: Check your npm registry connection and inspect ${ZEPHER_NPM_URL}, then run 'npm install -g ${ZEPHER_NPM_PACKAGE}'."
    return 0
  fi

  print_info "Verified package '${pkg_name_remote}' (executable '${ZEPHER_BIN_NAME}' -> '${pkg_bin_remote}')."

  # Prefer writable npm prefix or per-user ~/.npm-global so sudo is never required
  local npm_global_prefix
  npm_global_prefix="$(npm prefix -g 2>/dev/null || echo "/usr/local")"
  local install_cmd_rc=1

  if [[ -w "${npm_global_prefix}/lib/node_modules" ]] || [[ -w "${npm_global_prefix}" ]]; then
    print_info "Running: npm install -g ${ZEPHER_NPM_PACKAGE}"
    npm install -g "${ZEPHER_NPM_PACKAGE}"
    install_cmd_rc=$?
  else
    local user_npm_prefix="${ONBOARD_USER_NPM_PREFIX:-${HOME}/.npm-global}"
    local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"
    print_info "Global npm prefix (${npm_global_prefix}) requires administrator permissions."
    print_info "Installing per-user into '${user_npm_prefix}' to avoid requiring sudo..."
    mkdir -p "${user_npm_prefix}/bin" "${user_npm_prefix}/lib" "$user_bin_dir"
    npm install -g --prefix "${user_npm_prefix}" "${ZEPHER_NPM_PACKAGE}"
    install_cmd_rc=$?
    if [[ -x "${user_npm_prefix}/bin/${ZEPHER_BIN_NAME}" ]]; then
      ln -sf "${user_npm_prefix}/bin/${ZEPHER_BIN_NAME}" "${user_bin_dir}/${ZEPHER_BIN_NAME}"
    fi
    NEW_TERMINAL_ADVISED=1
    print_info "Note: To use '${ZEPHER_BIN_NAME}' in future terminal sessions, ensure '${user_npm_prefix}/bin' or '~/.local/bin' is on your PATH."
  fi

  refresh_session_path

  if [[ "$install_cmd_rc" -eq 0 ]] && verify_zepher_binary; then
    local installed_zepher_ver
    installed_zepher_ver="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)"
    STATUS_ZEPHER="PASS"
    DETAIL_ZEPHER="Installed (${ZEPHER_BIN_NAME} v${installed_zepher_ver})"
    print_pass "Zepher CLI installed and verified: ${ZEPHER_BIN_NAME} v${installed_zepher_ver}"
    return 0
  fi

  STATUS_ZEPHER="FAIL"
  DETAIL_ZEPHER="Installation or post-install verification failed"
  print_fail "Failed to install or verify '${ZEPHER_NPM_PACKAGE}'."
  print_info "Official package page: ${ZEPHER_NPM_URL}"
  add_recovery_note "Zepher CLI: Run 'npm install -g ${ZEPHER_NPM_PACKAGE}' manually and verify with '${ZEPHER_BIN_NAME} --version' (see ${ZEPHER_NPM_URL})."
}

# -----------------------------------------------------------------------------
# 4. Orca Desktop Application (Homebrew Cask or Official Standalone DMG)
# -----------------------------------------------------------------------------
install_orca_dmg_standalone_macos() {
  local dmg_url="$1"
  local dmg_filename="$2"
  local arch_label="$3"

  print_info "Homebrew is not installed. Attempting official Orca standalone DMG installation (${arch_label})..."
  print_info "Fetching official release metadata from: ${ORCA_RELEASES_API_URL}"

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/orca-dmg.XXXXXX")"
  local dmg_path="${tmp_dir}/${dmg_filename}"
  local release_json="${tmp_dir}/release.json"

  local expected_sha256=""
  if curl -fsSL --retry 2 --connect-timeout 10 -o "$release_json" "${ORCA_RELEASES_API_URL}" 2>/dev/null; then
    # Extract sha256 digest for the specific DMG asset
    expected_sha256="$(grep -B 3 -A 6 "\"name\": \"${dmg_filename}\"" "$release_json" 2>/dev/null | grep -oE "sha256:[0-9a-fA-F]{64}" | head -n 1 | cut -d: -f2 | tr '[:upper:]' '[:lower:]' || true)"
  fi

  print_info "Downloading official Orca installer: ${dmg_url}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "$dmg_path" "$dmg_url"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download ${dmg_url}."
    return 1
  fi

  if [[ -n "$expected_sha256" ]]; then
    print_info "Verifying SHA-256 digest against official Orca GitHub Release metadata..."
    local actual_sha256
    actual_sha256="$(shasum -a 256 "$dmg_path" 2>/dev/null | awk '{print tolower($1)}' || true)"
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
      rm -rf "$tmp_dir"
      print_fail "SHA-256 checksum mismatch for ${dmg_filename}!"
      print_info "Expected: ${expected_sha256}"
      print_info "Actual  : ${actual_sha256:-unknown}"
      return 1
    fi
    print_pass "Verified official SHA-256 checksum (${actual_sha256})."
  fi

  if ! command -v hdiutil >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 1
  fi

  local mount_point="${tmp_dir}/mnt"
  mkdir -p "$mount_point"
  print_info "Mounting ${dmg_filename} read-only..."
  if ! hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -readonly -quiet; then
    rm -rf "$tmp_dir"
    print_fail "Could not mount ${dmg_filename}."
    return 1
  fi

  if [[ ! -d "${mount_point}/Orca.app" ]]; then
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    rm -rf "$tmp_dir"
    print_fail "Orca.app was not found inside mounted ${dmg_filename}."
    return 1
  fi

  # Verify Apple code signature before copying
  if command -v codesign >/dev/null 2>&1; then
    print_info "Verifying Apple code signature on Orca.app..."
    if ! codesign --verify --deep --strict "${mount_point}/Orca.app" >/dev/null 2>&1; then
      hdiutil detach "$mount_point" -quiet 2>/dev/null || true
      rm -rf "$tmp_dir"
      print_fail "Orca.app code signature verification failed! Refusing to install."
      return 1
    fi
    print_pass "Verified Apple code signature on Orca.app."
  fi

  # Prefer /Applications if writable without sudo, otherwise per-user ~/Applications
  local target_apps_dir="${HOME}/Applications"
  if [[ -n "${ONBOARD_ORCA_INSTALL_DIR:-}" ]]; then
    target_apps_dir="${ONBOARD_ORCA_INSTALL_DIR}"
  elif [[ -w "/Applications" ]]; then
    target_apps_dir="/Applications"
  fi

  mkdir -p "$target_apps_dir"
  print_info "Copying Orca.app to '${target_apps_dir}/Orca.app'..."
  local copy_rc=0
  ditto "${mount_point}/Orca.app" "${target_apps_dir}/Orca.app" || copy_rc=$?

  hdiutil detach "$mount_point" -quiet 2>/dev/null || true
  rm -rf "$tmp_dir"

  if [[ "$copy_rc" -ne 0 ]] || [[ ! -d "${target_apps_dir}/Orca.app" ]]; then
    print_fail "Failed to copy Orca.app into ${target_apps_dir}."
    return 1
  fi

  return 0
}

check_and_setup_orca_app() {
  print_step "Step 5: Checking Orca Desktop Application"

  local existing_app=""
  if existing_app="$(find_orca_app_macos)"; then
    STATUS_ORCA_APP="SKIPPED"
    DETAIL_ORCA_APP="Already installed (${existing_app})"
    print_skip "Orca desktop application is already installed at: ${existing_app}"
    return 0
  fi

  print_info "Orca.app was not found in /Applications or ~/Applications."

  local recommended_dmg_url="${ORCA_DMG_X64_URL}"
  local recommended_dmg_name="orca-macos-x64.dmg"
  local arch_label="Intel (x64)"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    recommended_dmg_url="${ORCA_DMG_ARM64_URL}"
    recommended_dmg_name="orca-macos-arm64.dmg"
    arch_label="Apple Silicon (arm64)"
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_ORCA_APP="ACTION REQUIRED"
    DETAIL_ORCA_APP="Not installed (ran with --check-only)"
    print_action "Orca desktop application is not installed."
    print_info "Install with Homebrew: brew install --cask ${ORCA_BREW_CASK}"
    print_info "Or download for ${arch_label}: ${recommended_dmg_url}"
    add_recovery_note "Orca Desktop App: Re-run './setup.zsh' without --check-only, or install via 'brew install --cask ${ORCA_BREW_CASK}' / ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_ORCA_APP="FAIL"
    DETAIL_ORCA_APP="Missing and cannot download while offline"
    print_fail "Cannot download or install Orca because network connectivity is unavailable."
    add_recovery_note "Orca Desktop App: Connect to the internet and re-run ./setup.zsh or download from ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  # Route A: Homebrew Cask if Homebrew is available
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Installing Orca via official Homebrew Cask ('brew install --cask ${ORCA_BREW_CASK}')..."
    print_info "Note: macOS may ask for your password to move Orca.app into /Applications."

    if brew install --cask "${ORCA_BREW_CASK}"; then
      local installed_app=""
      if installed_app="$(find_orca_app_macos)"; then
        STATUS_ORCA_APP="PASS"
        DETAIL_ORCA_APP="Installed via Homebrew (${installed_app})"
        print_pass "Orca desktop application installed and verified at: ${installed_app}"
        return 0
      fi
    fi

    STATUS_ORCA_APP="FAIL"
    DETAIL_ORCA_APP="Homebrew cask installation failed or Orca.app not found afterward"
    print_fail "Homebrew installation of '${ORCA_BREW_CASK}' did not complete cleanly."
    print_info "Official installation docs : ${ORCA_INSTALL_DOCS_URL}"
    print_info "Direct download (${arch_label}): ${recommended_dmg_url}"
    add_recovery_note "Orca Desktop App: Download the macOS installer for ${arch_label} from ${ORCA_INSTALL_DOCS_URL} (${recommended_dmg_url}) and move Orca.app to /Applications."
    return 0
  fi

  # Route B: Official standalone DMG when Homebrew is absent (no Homebrew installation required!)
  if install_orca_dmg_standalone_macos "$recommended_dmg_url" "$recommended_dmg_name" "$arch_label"; then
    local dmg_installed_app=""
    if dmg_installed_app="$(find_orca_app_macos)"; then
      STATUS_ORCA_APP="PASS"
      DETAIL_ORCA_APP="Installed via official standalone DMG (${dmg_installed_app})"
      print_pass "Orca desktop application installed and verified at: ${dmg_installed_app}"
      return 0
    fi
  fi

  # Fallback if standalone DMG download/mount could not complete automatically
  STATUS_ORCA_APP="ACTION REQUIRED"
  DETAIL_ORCA_APP="Manual download required (${ORCA_INSTALL_DOCS_URL})"
  print_action "Could not complete automated DMG installation of Orca."
  print_info "Note on Homebrew: Homebrew is NOT installed automatically because it modifies"
  print_info "system directories (/opt/homebrew or /usr/local) and requires administrator access."
  print_info "Please install Orca manually using the official download page:"
  print_info "  Official Install Page          : ${ORCA_INSTALL_DOCS_URL}"
  print_info "  Direct Download (${arch_label}): ${recommended_dmg_url}"
  print_info "After opening the .dmg and dragging Orca.app into /Applications, re-run ./setup.zsh."
  add_recovery_note "Orca Desktop App: Download Orca from ${ORCA_INSTALL_DOCS_URL} (${recommended_dmg_url}), move Orca.app to /Applications, and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 5. Orca CLI (orca)
# -----------------------------------------------------------------------------
print_orca_cli_registration_guide() {
  print_info "How to enable and register the Orca CLI:"
  print_info "  1. Open the Orca desktop application (/Applications/Orca.app or ~/Applications/Orca.app)."
  print_info "  2. In Orca, go to: Settings -> General -> Orca CLI"
  print_info "  3. Click to register/enable the 'orca' command on your PATH."
  print_info "  4. Open a NEW terminal window so the updated PATH takes effect."
  print_info "  5. Verify with: command -v orca && orca status --json"
  print_info "  Official CLI documentation: ${ORCA_CLI_DOCS_URL}"
}

check_and_setup_orca_cli() {
  print_step "Step 6: Checking Orca CLI ('orca')"

  refresh_session_path

  # Never assume installing Orca.app automatically registers the CLI on PATH.
  if ! command -v orca >/dev/null 2>&1; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    if [[ "$STATUS_ORCA_APP" == "PASS" ]] || [[ "$STATUS_ORCA_APP" == "SKIPPED" ]]; then
      DETAIL_ORCA_CLI="Orca.app is installed, but 'orca' CLI is not yet registered on PATH"
      print_action "Orca desktop app is installed, but the 'orca' CLI is not yet on your PATH."
    else
      DETAIL_ORCA_CLI="Install Orca desktop app first, then register CLI in Settings -> General -> Orca CLI"
      print_action "The 'orca' CLI is not available on PATH (Orca desktop app must be installed first)."
    fi
    print_orca_cli_registration_guide
    add_recovery_note "Orca CLI: Open the Orca app -> Settings -> General -> Orca CLI to register 'orca' on your PATH, open a new terminal, and run 'orca status --json' (see ${ORCA_CLI_DOCS_URL})."
    return 0
  fi

  local orca_bin_path
  orca_bin_path="$(command -v orca 2>/dev/null || true)"
  print_info "Found 'orca' executable on PATH: ${orca_bin_path}"
  print_info "Verifying with documented command: orca status --json"

  local status_output=""
  if status_output="$(orca status --json 2>&1)"; then
    STATUS_ORCA_CLI="SKIPPED"
    DETAIL_ORCA_CLI="Registered on PATH and verified ('orca status --json' succeeded)"
    print_skip "Orca CLI is registered and verified via 'orca status --json'."
    return 0
  fi

  # If 'orca status --json' returned non-zero, check if the binary works when Orca GUI isn't running
  if orca --help >/dev/null 2>&1 || orca --version >/dev/null 2>&1; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    DETAIL_ORCA_CLI="CLI is on PATH (${orca_bin_path}), but 'orca status --json' requires Orca app to be running"
    print_action "'orca' CLI is registered on PATH (${orca_bin_path}), but 'orca status --json' could not reach a running Orca session."
    print_info "Please launch the Orca desktop app and run 'orca status --json' to confirm full connectivity."
    add_recovery_note "Orca CLI: Launch the Orca desktop application so 'orca status --json' can connect to the active Orca instance."
    return 0
  fi

  STATUS_ORCA_CLI="FAIL"
  DETAIL_ORCA_CLI="Found '${orca_bin_path}', but execution failed"
  print_fail "'orca' was found at ${orca_bin_path}, but failed verification."
  print_orca_cli_registration_guide
  add_recovery_note "Orca CLI: Re-register the CLI in Orca under Settings -> General -> Orca CLI (see ${ORCA_CLI_DOCS_URL})."
}

# -----------------------------------------------------------------------------
# Final Summary & Readiness Report
# -----------------------------------------------------------------------------
format_status_badge() {
  local st="$1"
  case "$st" in
    PASS)
      print "${C_GREEN}PASS           ${C_RESET}"
      ;;
    SKIPPED)
      print "${C_GREEN}SKIPPED        ${C_RESET}"
      ;;
    "ACTION REQUIRED")
      print "${C_YELLOW}ACTION REQUIRED${C_RESET}"
      ;;
    *)
      print "${C_RED}FAIL           ${C_RESET}"
      ;;
  esac
}

print_summary() {
  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  Onboarding Setup Summary (macOS — ${ARCH_NAME})${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "  Component            Status           Details"
  print "  -------------------- ---------------- -------------------------------------"
  print "  1. Git CLI           $(format_status_badge "$STATUS_GIT") ${DETAIL_GIT}"
  print "  2. Node.js & npm     $(format_status_badge "$STATUS_NODE") ${DETAIL_NODE}"
  print "  3. Zepher CLI        $(format_status_badge "$STATUS_ZEPHER") ${DETAIL_ZEPHER}"
  print "  4. Orca Desktop App  $(format_status_badge "$STATUS_ORCA_APP") ${DETAIL_ORCA_APP}"
  print "  5. Orca CLI          $(format_status_badge "$STATUS_ORCA_CLI") ${DETAIL_ORCA_CLI}"
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
  print "  Status Legend:"
  print "    PASS            = Installed and verified during this run."
  print "    SKIPPED         = Already installed and verified (no reinstall needed)."
  print "    ACTION REQUIRED = Manual user action required (see next steps below)."
  print "    FAIL            = Required check or installation failed."
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

  if [[ "$NEW_TERMINAL_ADVISED" == "1" ]]; then
    print ""
    print "${C_BLUE}  [PATH Notice] New binaries were installed during this session.${C_RESET}"
    print "  Please open a NEW terminal window after this script finishes so your"
    print "  updated PATH is active in future terminal sessions."
  fi

  local fail_count=0
  local action_count=0
  local st
  for st in "$STATUS_GIT" "$STATUS_NODE" "$STATUS_ZEPHER" "$STATUS_ORCA_APP" "$STATUS_ORCA_CLI"; do
    if [[ "$st" == "FAIL" ]]; then
      (( fail_count += 1 ))
    elif [[ "$st" == "ACTION REQUIRED" ]]; then
      (( action_count += 1 ))
    fi
  done

  if (( ${#RECOVERY_NOTES[@]} > 0 )); then
    print ""
    print "${C_BOLD}Recommended Next Steps / Manual Actions:${C_RESET}"
    local idx=1
    local note
    for note in "${RECOVERY_NOTES[@]}"; do
      print "  ${idx}. ${note}"
      (( idx += 1 ))
    done
    print ""
    print "${C_BOLD}Official Documentation & Download Links:${C_RESET}"
    print "  - Git CLI        : ${GIT_MACOS_URL}"
    print "  - Node.js LTS    : ${NODE_DOWNLOAD_URL}"
    print "  - Zepher CLI     : ${ZEPHER_NPM_URL}"
    print "  - Orca Website   : ${ORCA_WEBSITE_URL}"
    print "  - Orca Install   : ${ORCA_INSTALL_DOCS_URL}"
    print "  - Orca CLI Docs  : ${ORCA_CLI_DOCS_URL}"
  fi

  print ""
  if (( fail_count == 0 && action_count == 0 )); then
    print "${C_GREEN}=============================================================================${C_RESET}"
    print "${C_GREEN}  FINAL READINESS STATUS: FULLY READY${C_RESET}"
    print "${C_GREEN}  All required tools and CLIs are installed, verified, and ready for the event!${C_RESET}"
    print "${C_GREEN}=============================================================================${C_RESET}"
    return 0
  elif (( fail_count == 0 && action_count > 0 )); then
    print "${C_YELLOW}=============================================================================${C_RESET}"
    print "${C_YELLOW}  FINAL READINESS STATUS: PARTIALLY READY (${action_count} manual action(s) required)${C_RESET}"
    print "${C_YELLOW}  Automated steps succeeded, but please complete the manual steps listed above${C_RESET}"
    print "${C_YELLOW}  and re-run './setup.zsh' in a new terminal window to confirm full readiness.${C_RESET}"
    print "${C_YELLOW}=============================================================================${C_RESET}"
    return 0
  else
    print "${C_RED}=============================================================================${C_RESET}"
    print "${C_RED}  FINAL READINESS STATUS: NOT READY (${fail_count} failure(s), ${action_count} manual action(s))${C_RESET}"
    print "${C_RED}  One or more required components could not be verified. Follow the recovery${C_RESET}"
    print "${C_RED}  steps above and re-run './setup.zsh'.${C_RESET}"
    print "${C_RED}=============================================================================${C_RESET}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Main Execution Flow
# -----------------------------------------------------------------------------
main() {
  print_banner
  detect_environment
  check_network
  check_and_setup_git
  check_and_setup_node
  check_and_setup_zepher
  check_and_setup_orca_app
  check_and_setup_orca_cli
  print_summary
}

main "$@"
