#!/usr/bin/env zsh
# =============================================================================
# Cross-Platform Event Onboarding — macOS First-Run Bootstrap Launcher
# File: bootstrap.zsh
# =============================================================================
# Purpose:
#   Provides a lightweight first-run bootstrap route on macOS when Git and
#   Homebrew are NOT installed and the repository has not been cloned yet.
#
#   It can:
#     1. Download the repository ZIP archive from a configured official GitHub
#        URL (using macOS built-in 'curl'),
#     2. Verify the downloaded ZIP archive (non-empty, ZIP magic header PK\x03\x04,
#        optional SHA-256 checksum via 'shasum -a 256', and 'unzip -tq' integrity),
#     3. Extract the archive to an isolated temporary directory, and
#     4. Launch 'setup.zsh' with any forwarded arguments.
#
#   It also supports bootstrapping from a browser-downloaded local .zip file
#   ('--local-zip /path/to/repo.zip') or launching a co-located './setup.zsh'.
#
# Usage:
#   chmod +x bootstrap.zsh
#   ./bootstrap.zsh [OPTIONS] [-- SETUP_ARGS...]
#
# Options:
#   --zip-url <URL>       Override the repository ZIP download URL
#   --local-zip <PATH>    Bootstrap from a locally downloaded GitHub .zip file
#   --sha256 <HASH>       Verify the ZIP archive against an expected SHA-256 hash
#   --force-download      Download and extract ZIP even if ./setup.zsh exists locally
#   --keep-temp           Do not delete the extracted temporary folder after running
#   --check-only          Forwarded to setup.zsh (inspect only, no installations)
#   --help, -h            Show this help message and exit
# =============================================================================

emulate -L zsh
setopt PIPE_FAIL
setopt NO_UNSET

# -----------------------------------------------------------------------------
# ORGANIZER CONFIGURATION (Configured for The-Fable-Club/beyond-the-prompt)
# -----------------------------------------------------------------------------
readonly REPO_WEB_URL="${ONBOARD_REPO_WEB_URL:-https://github.com/The-Fable-Club/beyond-the-prompt}"
readonly DEFAULT_REPO_ZIP_URL="${ONBOARD_REPO_ZIP_URL:-https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip}"

# Optional: Set a 64-character hex SHA-256 checksum if pinning a fixed release ZIP
readonly DEFAULT_REPO_ZIP_SHA256="${ONBOARD_REPO_ZIP_SHA256:-}"

# -----------------------------------------------------------------------------
# Runtime State
# -----------------------------------------------------------------------------
ZIP_URL="$DEFAULT_REPO_ZIP_URL"
LOCAL_ZIP="${ONBOARD_LOCAL_ZIP:-}"
EXPECTED_SHA256="$DEFAULT_REPO_ZIP_SHA256"
FORCE_DOWNLOAD=0
KEEP_TEMP=0
typeset -a SETUP_ARGS
SETUP_ARGS=()

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_GREEN=$'\033[1;32m'
  readonly C_YELLOW=$'\033[1;33m'
  readonly C_RED=$'\033[1;31m'
  readonly C_CYAN=$'\033[1;36m'
else
  readonly C_RESET=""
  readonly C_BOLD=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_RED=""
  readonly C_CYAN=""
fi

show_help() {
  cat <<EOF
Usage: ./bootstrap.zsh [BOOTSTRAP_OPTIONS] [SETUP_OPTIONS]

macOS First-Run Bootstrap Launcher (works without Git or Homebrew).

Bootstrap Options:
  --zip-url <URL>       Download repository ZIP from the specified HTTPS URL
  --local-zip <FILE>    Extract and run from a locally downloaded .zip archive
  --sha256 <HASH>       Expected 64-char SHA-256 checksum for the ZIP archive
  --force-download      Download/extract ZIP even if ./setup.zsh is in current folder
  --keep-temp           Keep extracted temporary directory after completion
  --help, -h            Display this help message and exit

Forwarded Setup Options:
  --check-only          Run setup.zsh in read-only verification mode
  --dry-run             Alias for --check-only
EOF
}

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
while (( $# > 0 )); do
  case "$1" in
    --zip-url)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --zip-url requires a URL argument.${C_RESET}" >&2
        exit 2
      fi
      ZIP_URL="$2"
      shift 2
      ;;
    --local-zip)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --local-zip requires a file path argument.${C_RESET}" >&2
        exit 2
      fi
      LOCAL_ZIP="$2"
      shift 2
      ;;
    --sha256)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --sha256 requires a 64-character hex digest.${C_RESET}" >&2
        exit 2
      fi
      EXPECTED_SHA256="$2"
      shift 2
      ;;
    --force-download)
      FORCE_DOWNLOAD=1
      shift
      ;;
    --keep-temp)
      KEEP_TEMP=1
      shift
      ;;
    --check-only|--dry-run)
      SETUP_ARGS+=("$1")
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    --)
      shift
      SETUP_ARGS+=("$@")
      break
      ;;
    *)
      print "${C_RED}[ERROR] Unknown option: $1${C_RESET}" >&2
      show_help
      exit 2
      ;;
  esac
done

print ""
print "${C_CYAN}=============================================================================${C_RESET}"
print "${C_BOLD}  AI Development Event — macOS First-Run Bootstrap Launcher${C_RESET}"
print "${C_CYAN}=============================================================================${C_RESET}"
print "  - Works without Git or Homebrew installed."
print "  - Verifies archive integrity before extracting and launching setup.zsh."
print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

# -----------------------------------------------------------------------------
# Route 1: Co-located setup.zsh (Already extracted or cloned)
# -----------------------------------------------------------------------------
if [[ "$FORCE_DOWNLOAD" == "0" ]] && [[ -z "$LOCAL_ZIP" ]] && [[ -f "${SCRIPT_DIR}/setup.zsh" ]]; then
  if [[ "$ZIP_URL" == "$DEFAULT_REPO_ZIP_URL" ]]; then
    print "    [INFO] Found co-located setup script at: ${SCRIPT_DIR}/setup.zsh"
    print "    [INFO] Launching setup.zsh directly..."
    chmod +x "${SCRIPT_DIR}/setup.zsh" 2>/dev/null || true
    /bin/zsh "${SCRIPT_DIR}/setup.zsh" "${SETUP_ARGS[@]}"
    exit $?
  fi
fi

# -----------------------------------------------------------------------------
# Helper: Verify ZIP File Integrity (Header, Optional SHA-256, and unzip -tq)
# -----------------------------------------------------------------------------
verify_zip_archive() {
  local zip_path="$1"

  if [[ ! -s "$zip_path" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} Archive file is missing or empty: ${zip_path}" >&2
    return 1
  fi

  # Verify ZIP magic bytes (PK\x03\x04 -> 504b0304 in hex)
  local magic_hex=""
  magic_hex="$(head -c 4 "$zip_path" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$magic_hex" != "504b0304" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} File is not a valid ZIP archive (magic header: '${magic_hex:-none}', expected '504b0304')." >&2
    print "    [INFO] Ensure the URL points directly to a GitHub .zip archive, not an HTML web page." >&2
    return 1
  fi

  # Optional SHA-256 verification
  if [[ -n "$EXPECTED_SHA256" ]]; then
    local actual_sha256=""
    actual_sha256="$(shasum -a 256 "$zip_path" 2>/dev/null | awk '{print tolower($1)}' || true)"
    local expected_clean="${EXPECTED_SHA256:l}"
    if [[ "$actual_sha256" != "$expected_clean" ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} SHA-256 checksum mismatch for ${zip_path}!" >&2
      print "           Expected: ${expected_clean}" >&2
      print "           Actual  : ${actual_sha256:-unknown}" >&2
      return 1
    fi
    print "    ${C_GREEN}[PASS]${C_RESET} SHA-256 checksum verified (${actual_sha256})."
  fi

  # Test archive structure with unzip -tq
  if ! command -v unzip >/dev/null 2>&1; then
    print "    ${C_RED}[FAIL]${C_RESET} macOS 'unzip' utility is not available on PATH." >&2
    return 1
  fi

  if ! unzip -tq "$zip_path" >/dev/null 2>&1; then
    print "    ${C_RED}[FAIL]${C_RESET} ZIP archive integrity test ('unzip -tq') failed for: ${zip_path}" >&2
    return 1
  fi

  print "    ${C_GREEN}[PASS]${C_RESET} ZIP archive structure and integrity verified."
  return 0
}

# -----------------------------------------------------------------------------
# Prepare Temporary Workspace
# -----------------------------------------------------------------------------
TEMP_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/event-onboard-bootstrap.XXXXXX")"
cleanup_temp() {
  if [[ "$KEEP_TEMP" == "1" ]]; then
    print "    [INFO] Preserving temporary bootstrap directory (--keep-temp): ${TEMP_WORKDIR}"
  elif [[ -n "${TEMP_WORKDIR:-}" ]] && [[ -d "$TEMP_WORKDIR" ]]; then
    rm -rf "$TEMP_WORKDIR"
  fi
}
trap cleanup_temp EXIT

ARCHIVE_FILE="${TEMP_WORKDIR}/repo-bootstrap.zip"

# -----------------------------------------------------------------------------
# Route 2: Bootstrap from Local ZIP File (--local-zip)
# -----------------------------------------------------------------------------
if [[ -n "$LOCAL_ZIP" ]]; then
  print "    [INFO] Bootstrapping from local ZIP archive: ${LOCAL_ZIP}"
  if [[ ! -f "$LOCAL_ZIP" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} Local ZIP file not found: ${LOCAL_ZIP}" >&2
    exit 1
  fi
  cp "$LOCAL_ZIP" "$ARCHIVE_FILE"
else
  # ---------------------------------------------------------------------------
  # Route 3: Download Repository ZIP from Configured GitHub URL
  # ---------------------------------------------------------------------------
  if [[ -z "$ZIP_URL" ]] || [[ "$ZIP_URL" == "<REPOSITORY_ZIP_URL>" ]] || [[ "$ZIP_URL" == *"<"* ]]; then
    print "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} Repository ZIP URL placeholder has not been configured yet."
    print ""
    print "    For Event Organizers:"
    print "      Replace '<REPOSITORY_ZIP_URL>' in bootstrap.zsh (line 45) with your"
    print "      official GitHub ZIP URL, for example:"
    print "      https://github.com/<ORG>/<REPO>/archive/refs/heads/main.zip"
    print ""
    print "    For Event Participants (No Git Required):"
    print "      1. Open the event repository in your browser (${REPO_WEB_URL})."
    print "      2. Click 'Code' -> 'Download ZIP'."
    print "      3. Double-click the downloaded .zip file in Finder to extract it,"
    print "         or run: ./bootstrap.zsh --local-zip ~/Downloads/<downloaded-file>.zip"
    exit 1
  fi

  if [[ "$ZIP_URL" != https://* ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} Refusing insecure or non-HTTPS ZIP URL: ${ZIP_URL}" >&2
    print "    [INFO] Only official 'https://' archive URLs are permitted." >&2
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    print "    ${C_RED}[FAIL]${C_RESET} 'curl' is required to download the repository archive." >&2
    exit 1
  fi

  print "    [INFO] Downloading repository ZIP archive from:"
  print "           ${ZIP_URL}"
  if ! curl -fL --retry 2 --connect-timeout 10 -o "$ARCHIVE_FILE" "$ZIP_URL"; then
    print "    ${C_RED}[FAIL]${C_RESET} Failed to download repository ZIP from ${ZIP_URL}" >&2
    print "    [INFO] Please download the ZIP manually in your browser and run:" >&2
    print "           ./bootstrap.zsh --local-zip ~/Downloads/<repo>.zip" >&2
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Verify, Extract, and Launch setup.zsh
# -----------------------------------------------------------------------------
if ! verify_zip_archive "$ARCHIVE_FILE"; then
  exit 1
fi

EXTRACT_DIR="${TEMP_WORKDIR}/extracted"
mkdir -p "$EXTRACT_DIR"

print "    [INFO] Extracting verified archive into temporary workspace..."
if ! unzip -q "$ARCHIVE_FILE" -d "$EXTRACT_DIR"; then
  print "    ${C_RED}[FAIL]${C_RESET} Failed to extract ZIP archive." >&2
  exit 1
fi

FOUND_SETUP_SCRIPT="$(find "$EXTRACT_DIR" -maxdepth 3 -type f -name "setup.zsh" 2>/dev/null | head -n 1 || true)"
if [[ -z "$FOUND_SETUP_SCRIPT" ]] || [[ ! -s "$FOUND_SETUP_SCRIPT" ]]; then
  print "    ${C_RED}[FAIL]${C_RESET} Could not find a valid 'setup.zsh' inside the extracted archive." >&2
  exit 1
fi

chmod +x "$FOUND_SETUP_SCRIPT" 2>/dev/null || true
print "    ${C_GREEN}[PASS]${C_RESET} Verified and extracted setup script: ${FOUND_SETUP_SCRIPT}"
print "    [INFO] Launching setup.zsh..."
print ""

/bin/zsh "$FOUND_SETUP_SCRIPT" "${SETUP_ARGS[@]}"
exit $?
