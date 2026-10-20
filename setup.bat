@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===========================================================================
REM Cross-Platform Event Onboarding — Windows Setup Script (setup.bat)
REM ===========================================================================
REM Purpose:
REM   Automates and verifies the local development environment for event
REM   participants on Windows (Command Prompt compatible):
REM     1. Git CLI (Git for Windows)
REM     2. Node.js (LTS >= 18) & npm
REM     3. Zepher CLI (zepher-cli -> zepher)
REM     4. Orca Desktop Application (Orca.exe)
REM     5. Orca CLI (orca)
REM
REM   Works both when cloned via Git and when run from an extracted GitHub ZIP
REM   archive (or via 'bootstrap.bat') on a clean Windows PC without Git or
REM   winget.
REM
REM Usage:
REM   setup.bat
REM   setup.bat --check-only
REM   setup.bat --no-prompt
REM   setup.bat --help
REM
REM Security & Safety Principles:
REM   - Compatible with standard Windows Command Prompt (cmd.exe).
REM   - Avoids nested parentheses to prevent expansion bugs with 'Program Files (x86)'.
REM   - Verifies SHA-256 checksums on standalone downloads via 'certutil -hashfile'.
REM   - Prefers per-user install paths (%LocalAppData%\Programs) to avoid admin prompts.
REM   - Never installs unofficial package managers (Chocolatey/Scoop) as workarounds.
REM   - Never pipes remote scripts into a shell or weakens security policies.
REM   - Never requests, collects, prints, or transmits API keys or passwords.
REM   - Safe, resumable, and idempotent to run repeatedly.
REM ===========================================================================

REM ---------------------------------------------------------------------------
REM Organizer Configuration Section (Isolated for easy maintenance)
REM ---------------------------------------------------------------------------
set "REPO_WEB_URL=https://github.com/The-Fable-Club/beyond-the-prompt"
if defined ONBOARD_REPO_WEB_URL set "REPO_WEB_URL=%ONBOARD_REPO_WEB_URL%"
set "REPO_ZIP_URL=https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip"
if defined ONBOARD_REPO_ZIP_URL set "REPO_ZIP_URL=%ONBOARD_REPO_ZIP_URL%"

set "ZEPHER_NPM_PACKAGE=zepher-cli"
set "ZEPHER_BIN_NAME=zepher"
set "ZEPHER_NPM_URL=https://www.npmjs.com/package/zepher-cli"
set "ZEPHER_GITHUB_URL=https://github.com/YUVARAJ-R-ai/zepher"
set "MIN_NODE_MAJOR=18"
set "NODE_DIST_BASE_URL=https://nodejs.org/dist/latest-v22.x"
if defined ONBOARD_NODE_DIST_BASE_URL set "NODE_DIST_BASE_URL=%ONBOARD_NODE_DIST_BASE_URL%"

set "WINGET_GIT_ID=Git.Git"
set "WINGET_NODE_ID=OpenJS.NodeJS.LTS"

set "ORCA_WEBSITE_URL=https://www.onorca.dev"
set "ORCA_INSTALL_DOCS_URL=https://www.onorca.dev/docs/install"
set "ORCA_CLI_DOCS_URL=https://www.onorca.dev/docs/cli/overview"
set "ORCA_WINDOWS_INSTALLER_URL=https://github.com/stablyai/orca/releases/latest/download/orca-windows-setup.exe"
set "ORCA_RELEASES_URL=https://github.com/stablyai/orca/releases"

set "GIT_WINDOWS_URL=https://git-scm.com/download/win"
set "NODE_DOWNLOAD_URL=https://nodejs.org/en/download"

REM ---------------------------------------------------------------------------
REM Runtime State & Result Tracking
REM ---------------------------------------------------------------------------
set "CHECK_ONLY=0"
if defined ONBOARD_CHECK_ONLY set "CHECK_ONLY=%ONBOARD_CHECK_ONLY%"
set "NO_PROMPT=0"
if defined ONBOARD_NO_PROMPT set "NO_PROMPT=%ONBOARD_NO_PROMPT%"
set "NETWORK_AVAILABLE=0"
set "HAS_WINGET=0"
set "IS_ADMIN=0"
set "NEW_TERMINAL_ADVISED=0"

set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Not checked"

set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Not checked"

set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Not checked"

set "STATUS_ORCA_APP=FAIL"
set "DETAIL_ORCA_APP=Not checked"

set "STATUS_ORCA_CLI=FAIL"
set "DETAIL_ORCA_CLI=Not checked"

set "RECOVERY_COUNT=0"

REM ---------------------------------------------------------------------------
REM Parse Command-Line Arguments
REM ---------------------------------------------------------------------------
:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--check-only" set "CHECK_ONLY=1" & shift & goto :parse_args
if /I "%~1"=="--dry-run" set "CHECK_ONLY=1" & shift & goto :parse_args
if /I "%~1"=="--no-prompt" set "NO_PROMPT=1" & shift & goto :parse_args
if /I "%~1"=="--non-interactive" set "NO_PROMPT=1" & shift & goto :parse_args
if /I "%~1"=="--help" goto :show_help
if /I "%~1"=="-h" goto :show_help
if /I "%~1"=="/?" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help_error

:show_help
echo.
echo Usage: setup.bat [OPTIONS]
echo.
echo Windows onboarding script for the AI Development Event.
echo.
echo Options:
echo   --check-only, --dry-run        Verify installed tools without making changes
echo   --no-prompt, --non-interactive Do not pause for interactive browser prompts
echo   --help, -h, /?                 Show this help message and exit
echo.
exit /b 0

:show_help_error
echo Run "setup.bat --help" for usage instructions.
exit /b 2

:args_done

REM ---------------------------------------------------------------------------
REM Main Execution Flow
REM ---------------------------------------------------------------------------
call :print_banner
call :detect_environment
call :check_network
call :setup_git
call :setup_node
call :setup_zepher
call :setup_orca_app
call :setup_orca_cli
call :print_summary
set "FINAL_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %FINAL_EXIT_CODE%

REM ===========================================================================
REM Subroutines
REM ===========================================================================

:print_banner
echo.
echo =============================================================================
echo   AI Development Event — Windows Environment Onboarding (setup.bat)
echo =============================================================================
echo This script independently detects and prepares your required event tools:
echo   1. Git CLI                 (Git for Windows)
echo   2. Node.js ^& npm           (JavaScript runtime ^>= v%MIN_NODE_MAJOR% LTS ^& package manager)
echo   3. Zepher CLI              (npm package: %ZEPHER_NPM_PACKAGE% -^> '%ZEPHER_BIN_NAME%')
echo   4. Orca Desktop App        (Agent Development Environment)
echo   5. Orca CLI                ('orca' command registered via Orca Settings)
echo.
echo Privacy ^& Security:
echo   - Works even if Git and winget are not pre-installed.
echo   - Existing working installations are preserved and never overwritten.
echo   - Standalone downloads are verified with SHA-256 checksums via certutil.
echo   - Prefers per-user install paths (%LocalAppData%\Programs) to avoid admin prompts.
echo   - No API keys, tokens, or personal credentials are requested or collected.
if "%CHECK_ONLY%"=="1" echo. & echo [MODE] Running in --check-only mode (no installations will be performed).
echo -----------------------------------------------------------------------------
exit /b 0

:add_recovery
set /a RECOVERY_COUNT+=1
set "RECOVERY_%RECOVERY_COUNT%=%~1"
exit /b 0

:add_path_if_exists
REM %~1 = directory to add, %~2 = optional required file inside directory
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0
if not "%~2"=="" if not exist "%~1\%~2" exit /b 0
echo ";!PATH!;" | find /I ";%~1;" >nul 2>nul
if errorlevel 1 set "PATH=!PATH!;%~1"
exit /b 0

:refresh_path
REM Refresh current session PATH with standard per-user & system Windows locations
REM (In-memory only; never overwrites system/user Registry PATH directly)
if "%ONBOARD_DISABLE_PATH_REFRESH%"=="1" exit /b 0
call :add_path_if_exists "%LocalAppData%\Programs\Git\cmd" "git.exe"
call :add_path_if_exists "%ProgramFiles%\Git\cmd" "git.exe"
call :add_path_if_exists "%ProgramFiles(x86)%\Git\cmd" "git.exe"
call :add_path_if_exists "%LocalAppData%\Programs\nodejs" "node.exe"
call :add_path_if_exists "%ProgramFiles%\nodejs" "node.exe"
call :add_path_if_exists "%ProgramFiles(x86)%\nodejs" "node.exe"
call :add_path_if_exists "%AppData%\npm" ""
call :add_path_if_exists "%LocalAppData%\Volta\bin" "volta.exe"
call :add_path_if_exists "%LocalAppData%\Programs\Orca" ""
exit /b 0

:detect_environment
echo.
echo ==^> Step 0: Detecting Operating System ^& Independent Tool States
echo     [INFO] Running script    : setup.bat (Windows Command Prompt)
echo     [INFO] Architecture      : %PROCESSOR_ARCHITECTURE%
for /f "tokens=*" %%V in ('ver 2^>nul') do if not "%%V"=="" echo     [INFO] Windows Version   : %%V

net session >nul 2>nul
if errorlevel 1 goto :not_admin
set "IS_ADMIN=1"
echo     [INFO] Privilege Level   : Administrator Command Prompt
goto :check_winget

:not_admin
set "IS_ADMIN=0"
echo     [INFO] Privilege Level   : Standard User (per-user installs preferred; UAC only if needed)

:check_winget
call :refresh_path
if "%ONBOARD_FORCE_NO_WINGET%"=="1" goto :no_winget_found
where winget >nul 2>nul
if errorlevel 1 goto :no_winget_found
set "HAS_WINGET=1"
set "WINGET_VER="
for /f "tokens=*" %%W in ('winget --version 2^>nul') do set "WINGET_VER=%%W"
echo     [INFO] Detect winget     : Found (winget !WINGET_VER!)
goto :detect_other_tools

:no_winget_found
set "HAS_WINGET=0"
echo     [INFO] Detect winget     : Not installed (will use official standalone installers / steps)

:detect_other_tools
where git >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Git CLI    : Not found
if not errorlevel 1 echo     [INFO] Detect Git CLI    : Found on PATH

where node >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Node.js    : Not found
if not errorlevel 1 echo     [INFO] Detect Node.js    : Found on PATH

where npm >nul 2>nul
if errorlevel 1 echo     [INFO] Detect npm        : Not found
if not errorlevel 1 echo     [INFO] Detect npm        : Found on PATH

where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Zepher CLI : Not found
if not errorlevel 1 echo     [INFO] Detect Zepher CLI : Found on PATH

call :find_orca_windows
if errorlevel 1 echo     [INFO] Detect Orca App   : Not found
if not errorlevel 1 echo     [INFO] Detect Orca App   : Found (!FOUND_ORCA_PATH!)

where orca >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Orca CLI   : Not found
if not errorlevel 1 echo     [INFO] Detect Orca CLI   : Found on PATH
exit /b 0

:check_network
echo.
echo ==^> Step 1: Checking Network Connectivity
if "%ONBOARD_SIMULATE_OFFLINE%"=="1" goto :network_simulated_offline

where curl >nul 2>nul
if errorlevel 1 goto :network_try_ping

curl -fsSI --max-time 8 "https://registry.npmjs.org" >nul 2>nul
if not errorlevel 1 goto :network_ok

curl -fsSI --max-time 8 "%ORCA_WEBSITE_URL%" >nul 2>nul
if not errorlevel 1 goto :network_ok

:network_try_ping
ping -n 1 -w 4000 registry.npmjs.org >nul 2>nul
if not errorlevel 1 goto :network_ok

set "NETWORK_AVAILABLE=0"
echo     [ACTION REQUIRED] Unable to reach external package servers (https://registry.npmjs.org).
echo     [INFO] Already-installed tools will still be checked, but downloads require internet access.
exit /b 0

:network_simulated_offline
set "NETWORK_AVAILABLE=0"
echo     [ACTION REQUIRED] Network check simulated as OFFLINE (ONBOARD_SIMULATE_OFFLINE=1).
exit /b 0

:network_ok
set "NETWORK_AVAILABLE=1"
echo     [PASS] Internet connection verified.
exit /b 0

REM ---------------------------------------------------------------------------
REM 1. Git CLI
REM ---------------------------------------------------------------------------
:setup_git
echo.
echo ==^> Step 2: Checking Git CLI
call :refresh_path

where git >nul 2>nul
if errorlevel 1 goto :git_missing

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_missing

set "STATUS_GIT=SKIPPED"
set "DETAIL_GIT=Already installed (!GIT_VER!)"
echo     [SKIPPED] Git is already installed and available on PATH: !GIT_VER!
exit /b 0

:git_missing
echo     [INFO] Git CLI was not found on PATH.
echo     [INFO] Bootstrap Note: If you haven't cloned the repo yet, use 'bootstrap.bat' or GitHub's 'Download ZIP'.

if "%CHECK_ONLY%"=="1" goto :git_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :git_fail_offline
if not "%HAS_WINGET%"=="1" goto :git_no_winget

echo     [INFO] Installing Git for Windows via winget ('winget install --id %WINGET_GIT_ID% --scope user -e --source winget')...
echo     [INFO] Attempting per-user scope first; if unsupported, standard winget install will run.
winget install --id "%WINGET_GIT_ID%" --scope user -e --source winget >nul 2>nul
if errorlevel 1 winget install --id "%WINGET_GIT_ID%" -e --source winget
set "WINGET_GIT_RC=%ERRORLEVEL%"

call :refresh_path
where git >nul 2>nul
if errorlevel 1 goto :git_install_failed

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_install_failed

set "STATUS_GIT=PASS"
set "DETAIL_GIT=Installed via winget (!GIT_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Git installed and verified: !GIT_VER!
exit /b 0

:git_install_failed
if "%WINGET_GIT_RC%"=="0" goto :git_needs_new_terminal
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=winget installation failed (exit code !WINGET_GIT_RC!)"
echo     [FAIL] Could not verify Git on PATH after winget installation attempt.
echo     [INFO] Official Git for Windows download: %GIT_WINDOWS_URL%
call :add_recovery "Git CLI: Open a new Command Prompt window and re-run setup.bat, or install Git manually from %GIT_WINDOWS_URL%."
exit /b 0

:git_needs_new_terminal
set "STATUS_GIT=ACTION REQUIRED"
set "DETAIL_GIT=Installer completed; open a new Command Prompt to refresh PATH"
set "NEW_TERMINAL_ADVISED=1"
echo     [ACTION REQUIRED] Git installer completed, but this Command Prompt session needs a PATH refresh.
echo     [INFO] Open a NEW Command Prompt window and re-run setup.bat to verify 'git --version'.
call :add_recovery "Git CLI: Open a new Command Prompt window so the updated PATH takes effect, then re-run setup.bat."
exit /b 0

:git_fail_check_only
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Missing (not installed; ran with --check-only)"
echo     [FAIL] Git is not installed.
call :add_recovery "Git CLI: Re-run 'setup.bat' without --check-only, or download Git for Windows from %GIT_WINDOWS_URL%."
exit /b 0

:git_fail_offline
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Missing and cannot install while offline"
echo     [FAIL] Git is missing and network connectivity is unavailable.
call :add_recovery "Git CLI: Connect to the internet and install Git from %GIT_WINDOWS_URL%."
exit /b 0

:git_no_winget
echo     [INFO] Windows Package Manager (winget) is not available on this system.
echo     [INFO] This script will NOT install an unofficial package manager.
echo     [INFO] Official Git for Windows standalone installer page: %GIT_WINDOWS_URL%

if "%NO_PROMPT%"=="1" goto :git_no_winget_manual

echo     [INFO] Opening official Git for Windows download page in your default browser...
start "" "%GIT_WINDOWS_URL%" >nul 2>nul
echo     [INFO] 1. Download and run the official Git for Windows Setup (.exe).
echo     [INFO] 2. Tip: Select 'Only show new options' or default settings (per-user install works without admin).
echo     [INFO] 3. Once the Git installer finishes, press any key here to re-check...
pause >nul

call :refresh_path
where git >nul 2>nul
if errorlevel 1 goto :git_no_winget_manual

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_no_winget_manual

set "STATUS_GIT=PASS"
set "DETAIL_GIT=Installed via official standalone installer (!GIT_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Git installed and verified: !GIT_VER!
exit /b 0

:git_no_winget_manual
set "STATUS_GIT=ACTION REQUIRED"
set "DETAIL_GIT=winget unavailable; install official standalone Git from %GIT_WINDOWS_URL%"
echo     [ACTION REQUIRED] Please install Git using the official standalone installer at:
echo     [INFO]   %GIT_WINDOWS_URL%
echo     [INFO] After installation finishes, open a NEW Command Prompt and re-run setup.bat.
call :add_recovery "Git CLI: Download and run the official Git for Windows standalone installer from %GIT_WINDOWS_URL%, open a new Command Prompt, and re-run setup.bat."
exit /b 0

REM ---------------------------------------------------------------------------
REM 2. Node.js and npm (winget or Official Verified Standalone Per-User Archive)
REM ---------------------------------------------------------------------------
:install_node_standalone_windows
set "WIN_NODE_ARCH=x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "WIN_NODE_ARCH=arm64"

echo     [INFO] Using official Node.js v22 LTS standalone per-user distribution (win-!WIN_NODE_ARCH!)...
echo     [INFO] Fetching official SHA-256 checksum manifest: %NODE_DIST_BASE_URL%/SHASUMS256.txt

where curl >nul 2>nul
if errorlevel 1 exit /b 1
where tar >nul 2>nul
if errorlevel 1 exit /b 1
where certutil >nul 2>nul
if errorlevel 1 exit /b 1

set "NODE_TMP_DIR=%TEMP%\node-standalone-%RANDOM%-%RANDOM%"
mkdir "%NODE_TMP_DIR%" >nul 2>nul
if errorlevel 1 exit /b 1

set "SHASUMS_FILE=%NODE_TMP_DIR%\SHASUMS256.txt"
curl -fsSL --retry 2 --connect-timeout 10 -o "%SHASUMS_FILE%" "%NODE_DIST_BASE_URL%/SHASUMS256.txt"
if errorlevel 1 goto :node_std_cleanup_fail

set "EXPECTED_NODE_SHA="
set "NODE_ZIP_NAME="
for /f "tokens=1,2" %%A in ('findstr /R /C:"node-v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-win-!WIN_NODE_ARCH!\.zip$" "%SHASUMS_FILE%" 2^>nul') do (
    if not defined NODE_ZIP_NAME (
        set "EXPECTED_NODE_SHA=%%A"
        set "NODE_ZIP_NAME=%%B"
    )
)
if not defined NODE_ZIP_NAME goto :node_std_cleanup_fail
if not defined EXPECTED_NODE_SHA goto :node_std_cleanup_fail

set "NODE_ZIP_PATH=%NODE_TMP_DIR%\!NODE_ZIP_NAME!"
echo     [INFO] Downloading official standalone archive: %NODE_DIST_BASE_URL%/!NODE_ZIP_NAME!
curl -fL --retry 2 --connect-timeout 15 -o "%NODE_ZIP_PATH%" "%NODE_DIST_BASE_URL%/!NODE_ZIP_NAME!"
if errorlevel 1 goto :node_std_cleanup_fail

echo     [INFO] Verifying SHA-256 checksum via certutil against official Node.js manifest...
set "ACTUAL_NODE_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%NODE_ZIP_PATH%" SHA256 2^>nul') do (
    if not defined ACTUAL_NODE_SHA set "ACTUAL_NODE_SHA=%%H"
)
if /I not "!ACTUAL_NODE_SHA!"=="!EXPECTED_NODE_SHA!" goto :node_std_sha_mismatch
echo     [PASS] Verified official SHA-256 checksum (!ACTUAL_NODE_SHA!).

set "USER_NODE_ROOT=%LocalAppData%\Programs\nodejs"
if defined ONBOARD_USER_NODE_DIR set "USER_NODE_ROOT=%ONBOARD_USER_NODE_DIR%"
echo     [INFO] Extracting Node.js per-user into '!USER_NODE_ROOT!' (no Administrator rights required)...

tar -xf "%NODE_ZIP_PATH%" -C "%NODE_TMP_DIR%"
if errorlevel 1 goto :node_std_cleanup_fail

set "EXTRACTED_SUBFOLDER=!NODE_ZIP_NAME:.zip=!"
if not exist "%NODE_TMP_DIR%\!EXTRACTED_SUBFOLDER!\node.exe" goto :node_std_cleanup_fail

mkdir "!USER_NODE_ROOT!" >nul 2>nul
xcopy /E /I /Y /Q "%NODE_TMP_DIR%\!EXTRACTED_SUBFOLDER!\*" "!USER_NODE_ROOT!\" >nul 2>nul
if errorlevel 1 goto :node_std_cleanup_fail

rmdir /s /q "%NODE_TMP_DIR%" >nul 2>nul
call :add_path_if_exists "!USER_NODE_ROOT!" "node.exe"
set "NEW_TERMINAL_ADVISED=1"
echo     [INFO] Note for future Command Prompt windows: Add '!USER_NODE_ROOT!' to your User PATH environment variable.
exit /b 0

:node_std_sha_mismatch
echo     [FAIL] SHA-256 checksum mismatch for !NODE_ZIP_NAME!! Aborting installation.
echo     [INFO] Expected: !EXPECTED_NODE_SHA!
echo     [INFO] Actual  : !ACTUAL_NODE_SHA!

:node_std_cleanup_fail
if exist "%NODE_TMP_DIR%" rmdir /s /q "%NODE_TMP_DIR%" >nul 2>nul
exit /b 1

:setup_node
echo.
echo ==^> Step 3: Checking Node.js (^>= v%MIN_NODE_MAJOR% LTS) and npm
call :refresh_path

set "DETECTED_NVM="
if defined NVM_HOME set "DETECTED_NVM=nvm-windows"
if exist "%AppData%\nvm\nvm.exe" set "DETECTED_NVM=nvm-windows"
if defined VOLTA_HOME set "DETECTED_NVM=Volta"
if exist "%LocalAppData%\Volta\bin\volta.exe" set "DETECTED_NVM=Volta"
if defined FNM_DIR set "DETECTED_NVM=fnm"

if defined DETECTED_NVM echo     [INFO] Detected Node version manager footprint: !DETECTED_NVM!

where node >nul 2>nul
if errorlevel 1 goto :node_missing

where npm >nul 2>nul
if errorlevel 1 goto :npm_missing_only

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_missing
if not defined NPM_VER goto :npm_missing_only

REM Parse Node major version (strip leading 'v' and take first token before '.')
set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! GEQ %MIN_NODE_MAJOR% goto :node_already_ok

echo     [ACTION REQUIRED] Detected Node.js !NODE_VER! (npm v!NPM_VER!), but %ZEPHER_NPM_PACKAGE% requires Node.js ^>= v%MIN_NODE_MAJOR%.0.0.
echo     [INFO] To avoid breaking your existing Node setup, this script will NOT overwrite it automatically.
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Installed Node !NODE_VER! is older than required v%MIN_NODE_MAJOR%+"
call :add_recovery "Node.js & npm: Upgrade Node.js to v%MIN_NODE_MAJOR%+ LTS using your version manager or the official installer at %NODE_DOWNLOAD_URL%."
exit /b 0

:node_already_ok
set "STATUS_NODE=SKIPPED"
set "DETAIL_NODE=Already installed (Node !NODE_VER!, npm v!NPM_VER!)"
echo     [SKIPPED] Compatible Node.js (!NODE_VER!) and npm (v!NPM_VER!) are already installed.
exit /b 0

:npm_missing_only
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Node.js is present, but 'npm' was not found on PATH"
echo     [FAIL] Node.js is installed, but 'npm' is missing from PATH.
call :add_recovery "Node.js & npm: Reinstall Node.js LTS (which includes npm) from %NODE_DOWNLOAD_URL% and open a new Command Prompt."
exit /b 0

:node_missing
echo     [INFO] Node.js and npm were not found on PATH.

if defined DETECTED_NVM goto :node_nvm_inactive
if "%CHECK_ONLY%"=="1" goto :node_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :node_fail_offline
if not "%HAS_WINGET%"=="1" goto :node_try_standalone

echo     [INFO] Installing Node.js LTS via winget ('winget install --id %WINGET_NODE_ID% -e --source winget')...
echo     [INFO] Note: Windows User Account Control (UAC) may prompt you for permission to install Node.js.
winget install --id "%WINGET_NODE_ID%" -e --source winget
set "WINGET_NODE_RC=%ERRORLEVEL%"

call :refresh_path
where node >nul 2>nul
if errorlevel 1 goto :node_try_standalone
where npm >nul 2>nul
if errorlevel 1 goto :node_try_standalone

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_try_standalone
if not defined NPM_VER goto :node_try_standalone

set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! LSS %MIN_NODE_MAJOR% goto :node_try_standalone

set "STATUS_NODE=PASS"
set "DETAIL_NODE=Installed via winget (Node !NODE_VER!, npm v!NPM_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Installed and verified Node.js (!NODE_VER!) and npm (v!NPM_VER!).
exit /b 0

:node_try_standalone
call :install_node_standalone_windows
if errorlevel 1 goto :node_install_failed

call :refresh_path
where node >nul 2>nul
if errorlevel 1 goto :node_install_failed
where npm >nul 2>nul
if errorlevel 1 goto :node_install_failed

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_install_failed
if not defined NPM_VER goto :node_install_failed

set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! LSS %MIN_NODE_MAJOR% goto :node_install_failed

set "STATUS_NODE=PASS"
set "DETAIL_NODE=Installed per-user standalone LTS (Node !NODE_VER!, npm v!NPM_VER!)"
echo     [PASS] Installed and verified standalone Node.js (!NODE_VER!) and npm (v!NPM_VER!).
exit /b 0

:node_install_failed
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Automatic installation failed; install official .msi from %NODE_DOWNLOAD_URL%"
echo     [FAIL] Could not automatically install and verify Node.js and npm.
echo     [INFO] Official Node.js LTS download: %NODE_DOWNLOAD_URL%
call :add_recovery "Node.js & npm: Download and run the official Node.js LTS Windows Installer (.msi) from %NODE_DOWNLOAD_URL%, open a new Command Prompt, and re-run setup.bat."
exit /b 0

:node_nvm_inactive
set "STATUS_NODE=ACTION REQUIRED"
set "DETAIL_NODE=Version manager (!DETECTED_NVM!) detected, but Node/npm not active on PATH"
echo     [ACTION REQUIRED] Detected !DETECTED_NVM!, but 'node' is not active on PATH.
echo     [INFO] Skipping system-wide Node installation to avoid conflicting with !DETECTED_NVM!.
call :add_recovery "Node.js & npm: Use !DETECTED_NVM! to install and activate Node.js LTS (e.g., 'nvm install lts' and 'nvm use lts'), or install from %NODE_DOWNLOAD_URL%."
exit /b 0

:node_fail_check_only
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Missing (not installed; ran with --check-only)"
echo     [FAIL] Node.js and npm are not installed.
call :add_recovery "Node.js & npm: Re-run 'setup.bat' without --check-only, or install Node.js LTS from %NODE_DOWNLOAD_URL%."
exit /b 0

:node_fail_offline
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Missing and cannot install while offline"
echo     [FAIL] Cannot install Node.js because network connectivity is unavailable.
call :add_recovery "Node.js & npm: Connect to the internet and install Node.js LTS from %NODE_DOWNLOAD_URL%."
exit /b 0

REM ---------------------------------------------------------------------------
REM 3. Zepher CLI (zepher-cli -> zepher)
REM ---------------------------------------------------------------------------
:setup_zepher
echo.
echo ==^> Step 4: Checking Zepher CLI (%ZEPHER_NPM_PACKAGE%)
call :refresh_path

REM Guard against accidental confusion with 'zephyr-cli'
if /I "%ZEPHER_NPM_PACKAGE%"=="zephyr-cli" goto :zepher_bad_pkg
if /I not "%ZEPHER_NPM_PACKAGE%"=="zepher-cli" goto :zepher_bad_pkg
goto :zepher_pkg_ok

:zepher_bad_pkg
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Package identity mismatch (%ZEPHER_NPM_PACKAGE% != zepher-cli)"
echo     [FAIL] Refusing to install '%ZEPHER_NPM_PACKAGE%'. Only verified package 'zepher-cli' is allowed (do not confuse with 'zephyr-cli').
call :add_recovery "Zepher CLI: Ensure ZEPHER_NPM_PACKAGE is set to 'zepher-cli' (%ZEPHER_NPM_URL%)."
exit /b 0

:zepher_pkg_ok
where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 goto :zepher_missing

set "ZEPHER_VER="
for /f "tokens=*" %%Z in ('call "%ZEPHER_BIN_NAME%" --version 2^>nul') do set "ZEPHER_VER=%%Z"
if not defined ZEPHER_VER goto :zepher_missing

call "%ZEPHER_BIN_NAME%" --help >nul 2>nul
if errorlevel 1 goto :zepher_missing

set "STATUS_ZEPHER=SKIPPED"
set "DETAIL_ZEPHER=Already installed (%ZEPHER_BIN_NAME% v!ZEPHER_VER!)"
echo     [SKIPPED] Zepher CLI is already installed and verified: %ZEPHER_BIN_NAME% v!ZEPHER_VER!
exit /b 0

:zepher_missing
echo     [INFO] Zepher CLI ('%ZEPHER_BIN_NAME%') is not currently installed.

if "%STATUS_NODE%"=="PASS" goto :zepher_node_ready
if "%STATUS_NODE%"=="SKIPPED" goto :zepher_node_ready

set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Blocked because Node.js (^>= v%MIN_NODE_MAJOR%) ^& npm are not ready"
echo     [FAIL] Cannot install %ZEPHER_NPM_PACKAGE% because a compatible Node.js (^>= v%MIN_NODE_MAJOR%) and npm environment is not available.
call :add_recovery "Zepher CLI: First install Node.js LTS from %NODE_DOWNLOAD_URL%, then run 'npm install -g %ZEPHER_NPM_PACKAGE%'."
exit /b 0

:zepher_node_ready
if "%CHECK_ONLY%"=="1" goto :zepher_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :zepher_fail_offline

echo     [INFO] Verifying package identity for '%ZEPHER_NPM_PACKAGE%' against %ZEPHER_NPM_URL%...
set "REMOTE_PKG_NAME="
for /f "tokens=*" %%P in ('call npm view "%ZEPHER_NPM_PACKAGE%" name 2^>nul') do set "REMOTE_PKG_NAME=%%P"
set "REMOTE_PKG_BIN="
for /f "tokens=*" %%B in ('call npm view "%ZEPHER_NPM_PACKAGE%" "bin.%ZEPHER_BIN_NAME%" 2^>nul') do set "REMOTE_PKG_BIN=%%B"

if /I not "!REMOTE_PKG_NAME!"=="%ZEPHER_NPM_PACKAGE%" goto :zepher_verify_failed
if not defined REMOTE_PKG_BIN goto :zepher_verify_failed

echo     [INFO] Verified package '!REMOTE_PKG_NAME!' (executable '%ZEPHER_BIN_NAME%' -^> '!REMOTE_PKG_BIN!').
echo     [INFO] Running: npm install -g %ZEPHER_NPM_PACKAGE%
call npm install -g "%ZEPHER_NPM_PACKAGE%"
set "NPM_INSTALL_RC=%ERRORLEVEL%"

call :refresh_path
if not "!NPM_INSTALL_RC!"=="0" goto :zepher_install_failed

where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 goto :zepher_install_failed

set "ZEPHER_VER="
for /f "tokens=*" %%Z in ('call "%ZEPHER_BIN_NAME%" --version 2^>nul') do set "ZEPHER_VER=%%Z"
if not defined ZEPHER_VER goto :zepher_install_failed

call "%ZEPHER_BIN_NAME%" --help >nul 2>nul
if errorlevel 1 goto :zepher_install_failed

set "STATUS_ZEPHER=PASS"
set "DETAIL_ZEPHER=Installed (%ZEPHER_BIN_NAME% v!ZEPHER_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Zepher CLI installed and verified: %ZEPHER_BIN_NAME% v!ZEPHER_VER!
exit /b 0

:zepher_fail_check_only
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Missing (not installed; ran with --check-only)"
echo     [FAIL] Zepher CLI (%ZEPHER_NPM_PACKAGE%) is not installed.
call :add_recovery "Zepher CLI: Run 'npm install -g %ZEPHER_NPM_PACKAGE%' and verify with '%ZEPHER_BIN_NAME% --version'."
exit /b 0

:zepher_fail_offline
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Missing and cannot verify/install while offline"
echo     [FAIL] Cannot verify or install %ZEPHER_NPM_PACKAGE% without internet access.
call :add_recovery "Zepher CLI: Connect to the internet and run 'npm install -g %ZEPHER_NPM_PACKAGE%'."
exit /b 0

:zepher_verify_failed
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Could not verify '%ZEPHER_NPM_PACKAGE%' metadata on npm registry"
echo     [FAIL] Could not verify package identity or '%ZEPHER_BIN_NAME%' executable for '%ZEPHER_NPM_PACKAGE%' on npm.
echo     [INFO] Stopping installation step to avoid installing an unverified package. Official URL: %ZEPHER_NPM_URL%
call :add_recovery "Zepher CLI: Check your internet/npm connection and inspect %ZEPHER_NPM_URL%, then run 'npm install -g %ZEPHER_NPM_PACKAGE%'."
exit /b 0

:zepher_install_failed
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Installation or post-install verification failed"
echo     [FAIL] Failed to install or verify '%ZEPHER_NPM_PACKAGE%'.
echo     [INFO] Official package page: %ZEPHER_NPM_URL%
call :add_recovery "Zepher CLI: Open a new Command Prompt and run 'npm install -g %ZEPHER_NPM_PACKAGE%', then verify with '%ZEPHER_BIN_NAME% --version'."
exit /b 0

REM ---------------------------------------------------------------------------
REM 4. Orca Desktop Application (Orca.exe)
REM ---------------------------------------------------------------------------
:check_single_orca_path
if "%~1"=="" exit /b 1
if exist "%~1" set "FOUND_ORCA_PATH=%~1" & exit /b 0
exit /b 1

:find_orca_windows
set "FOUND_ORCA_PATH="
if defined ONBOARD_ORCA_EXE_PATH call :check_single_orca_path "%ONBOARD_ORCA_EXE_PATH%"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\Programs\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\Programs\orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%ProgramFiles%\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%ProgramFiles(x86)%\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

where orca >nul 2>nul
if errorlevel 1 exit /b 1

for /f "tokens=*" %%O in ('where orca 2^>nul') do if not defined FOUND_ORCA_PATH set "FOUND_ORCA_PATH=%%O"
if defined FOUND_ORCA_PATH exit /b 0
exit /b 1

:setup_orca_app
echo.
echo ==^> Step 5: Checking Orca Desktop Application
call :find_orca_windows
if errorlevel 1 goto :orca_app_not_found

set "STATUS_ORCA_APP=SKIPPED"
set "DETAIL_ORCA_APP=Already installed (!FOUND_ORCA_PATH!)"
echo     [SKIPPED] Orca desktop application is already installed at: !FOUND_ORCA_PATH!
exit /b 0

:orca_app_not_found
echo     [INFO] Orca desktop application was not detected in standard Windows installation directories.
echo     [INFO] Orca distributes its official Windows installer via:
echo     [INFO]   Official Install Docs     : %ORCA_INSTALL_DOCS_URL%
echo     [INFO]   Official Windows Installer: %ORCA_WINDOWS_INSTALLER_URL%
echo     [INFO]   (Note: Orca does not publish an official winget package ID; unattended silent install is not used for security.)

if "%CHECK_ONLY%"=="1" goto :orca_app_action_needed
if "%NO_PROMPT%"=="1" goto :orca_app_action_needed

echo.
echo     [ACTION REQUIRED] Please install the Orca desktop application using the official installer.
echo     [INFO] Opening the official Orca installation page in your default web browser...
start "" "%ORCA_INSTALL_DOCS_URL%" >nul 2>nul
echo     [INFO] 1. Download and run the Windows installer from %ORCA_INSTALL_DOCS_URL%
echo     [INFO] 2. Complete the Orca setup wizard.
echo     [INFO] 3. Once installation finishes, press any key here to re-check...
pause >nul

call :find_orca_windows
if errorlevel 1 goto :orca_app_action_needed

set "STATUS_ORCA_APP=PASS"
set "DETAIL_ORCA_APP=Installed (!FOUND_ORCA_PATH!)"
echo     [PASS] Orca desktop application detected at: !FOUND_ORCA_PATH!
exit /b 0

:orca_app_action_needed
set "STATUS_ORCA_APP=ACTION REQUIRED"
set "DETAIL_ORCA_APP=Manual installation required from %ORCA_INSTALL_DOCS_URL%"
echo     [ACTION REQUIRED] Orca desktop application is not yet installed.
call :add_recovery "Orca Desktop App: Download and run the official Windows installer from %ORCA_INSTALL_DOCS_URL% (%ORCA_WINDOWS_INSTALLER_URL%), then re-run setup.bat."
exit /b 0

REM ---------------------------------------------------------------------------
REM 5. Orca CLI (orca)
REM ---------------------------------------------------------------------------
:print_orca_cli_guide
echo     [INFO] How to enable and register the Orca CLI on Windows:
echo     [INFO]   1. Open the Orca desktop application.
echo     [INFO]   2. Navigate to: Settings -^> General -^> Orca CLI
echo     [INFO]   3. Click to register/enable the 'orca' command on your PATH.
echo     [INFO]   4. Open a NEW Command Prompt or PowerShell window so the updated PATH loads.
echo     [INFO]   5. Verify with: where orca ^&^& orca status --json
echo     [INFO]   Official CLI documentation: %ORCA_CLI_DOCS_URL%
exit /b 0

:setup_orca_cli
echo.
echo ==^> Step 6: Checking Orca CLI ('orca')
call :refresh_path
REM Never assume installing the desktop app automatically registers the CLI.
where orca >nul 2>nul
if errorlevel 1 goto :orca_cli_missing

set "ORCA_CLI_PATH="
for /f "tokens=*" %%C in ('where orca 2^>nul') do if not defined ORCA_CLI_PATH set "ORCA_CLI_PATH=%%C"
echo     [INFO] Found 'orca' executable on PATH: !ORCA_CLI_PATH!
echo     [INFO] Verifying with documented command: orca status --json

call orca status --json >nul 2>nul
if not errorlevel 1 goto :orca_cli_verified

call orca --help >nul 2>nul
if not errorlevel 1 goto :orca_cli_needs_running_app
call orca --version >nul 2>nul
if not errorlevel 1 goto :orca_cli_needs_running_app

set "STATUS_ORCA_CLI=FAIL"
set "DETAIL_ORCA_CLI=Found '!ORCA_CLI_PATH!', but execution failed"
echo     [FAIL] 'orca' was found at !ORCA_CLI_PATH!, but failed verification.
call :print_orca_cli_guide
call :add_recovery "Orca CLI: Re-register the CLI inside Orca under Settings -> General -> Orca CLI (see %ORCA_CLI_DOCS_URL%)."
exit /b 0

:orca_cli_verified
set "STATUS_ORCA_CLI=SKIPPED"
set "DETAIL_ORCA_CLI=Registered on PATH and verified ('orca status --json' succeeded)"
echo     [SKIPPED] Orca CLI is registered and verified via 'orca status --json'.
exit /b 0

:orca_cli_needs_running_app
set "STATUS_ORCA_CLI=ACTION REQUIRED"
set "DETAIL_ORCA_CLI=CLI is on PATH (!ORCA_CLI_PATH!), but 'orca status --json' requires Orca app to be running"
echo     [ACTION REQUIRED] 'orca' CLI is registered on PATH (!ORCA_CLI_PATH!), but 'orca status --json' could not reach a running Orca session.
echo     [INFO] Please launch the Orca desktop app and run 'orca status --json' to confirm full connectivity.
call :add_recovery "Orca CLI: Launch the Orca desktop application so 'orca status --json' can connect to the active Orca instance."
exit /b 0

:orca_cli_missing
set "STATUS_ORCA_CLI=ACTION REQUIRED"
if "%STATUS_ORCA_APP%"=="PASS" goto :orca_cli_app_present
if "%STATUS_ORCA_APP%"=="SKIPPED" goto :orca_cli_app_present

set "DETAIL_ORCA_CLI=Install Orca desktop app first, then register CLI in Settings -^> General -^> Orca CLI"
echo     [ACTION REQUIRED] The 'orca' CLI is not available on PATH (install Orca desktop app first).
goto :orca_cli_missing_finish

:orca_cli_app_present
set "DETAIL_ORCA_CLI=Orca app is installed, but 'orca' CLI is not yet registered on PATH"
echo     [ACTION REQUIRED] Orca desktop app is installed, but the 'orca' CLI is not yet registered on your PATH.

:orca_cli_missing_finish
call :print_orca_cli_guide
call :add_recovery "Orca CLI: Open the Orca app -> Settings -> General -> Orca CLI to register 'orca' on your PATH, open a new Command Prompt, and run 'orca status --json' (see %ORCA_CLI_DOCS_URL%)."
exit /b 0

REM ---------------------------------------------------------------------------
REM Final Summary & Readiness Report
REM ---------------------------------------------------------------------------
:pad_status
set "PAD_IN=%~1               "
set "PAD_OUT=!PAD_IN:~0,15!"
exit /b 0

:print_summary
echo.
echo =============================================================================
echo   Onboarding Setup Summary (Windows — %PROCESSOR_ARCHITECTURE%)
echo =============================================================================
echo   Component            Status          Details
echo   -------------------- --------------- --------------------------------------
call :pad_status "%STATUS_GIT%"
echo   1. Git CLI           !PAD_OUT! !DETAIL_GIT!
call :pad_status "%STATUS_NODE%"
echo   2. Node.js ^& npm     !PAD_OUT! !DETAIL_NODE!
call :pad_status "%STATUS_ZEPHER%"
echo   3. Zepher CLI        !PAD_OUT! !DETAIL_ZEPHER!
call :pad_status "%STATUS_ORCA_APP%"
echo   4. Orca Desktop App  !PAD_OUT! !DETAIL_ORCA_APP!
call :pad_status "%STATUS_ORCA_CLI%"
echo   5. Orca CLI          !PAD_OUT! !DETAIL_ORCA_CLI!
echo -----------------------------------------------------------------------------
echo   Status Legend:
echo     PASS            = Installed and verified during this run.
echo     SKIPPED         = Already installed and verified (no reinstall needed).
echo     ACTION REQUIRED = Manual user action required (see next steps below).
echo     FAIL            = Required check or installation failed.
echo -----------------------------------------------------------------------------

if "%NEW_TERMINAL_ADVISED%"=="1" (
    echo.
    echo   [PATH Notice] New binaries were installed during this session.
    echo   Please open a NEW Command Prompt window after this script finishes so your
    echo   updated PATH is active in future terminal sessions.
)

set "FAIL_COUNT=0"
set "ACTION_COUNT=0"

for %%S in ("%STATUS_GIT%" "%STATUS_NODE%" "%STATUS_ZEPHER%" "%STATUS_ORCA_APP%" "%STATUS_ORCA_CLI%") do (
    if /I "%%~S"=="FAIL" set /a FAIL_COUNT+=1
    if /I "%%~S"=="ACTION REQUIRED" set /a ACTION_COUNT+=1
)

if !RECOVERY_COUNT! LEQ 0 goto :check_final_counts

echo.
echo Recommended Next Steps / Manual Actions:
for /L %%I in (1,1,!RECOVERY_COUNT!) do echo   %%I. !RECOVERY_%%I!
echo.
echo Official Documentation ^& Download Links:
echo   - Git CLI        : %GIT_WINDOWS_URL%
echo   - Node.js LTS    : %NODE_DOWNLOAD_URL%
echo   - Zepher CLI     : %ZEPHER_NPM_URL%
echo   - Orca Website   : %ORCA_WEBSITE_URL%
echo   - Orca Install   : %ORCA_INSTALL_DOCS_URL%
echo   - Orca CLI Docs  : %ORCA_CLI_DOCS_URL%

:check_final_counts
echo.
if !FAIL_COUNT! GTR 0 goto :summary_not_ready
if !ACTION_COUNT! GTR 0 goto :summary_partially_ready

echo =============================================================================
echo   FINAL READINESS STATUS: FULLY READY
echo   All required tools and CLIs are installed, verified, and ready for the event!
echo =============================================================================
exit /b 0

:summary_partially_ready
echo =============================================================================
echo   FINAL READINESS STATUS: PARTIALLY READY (!ACTION_COUNT! manual action(s) required)
echo   Automated steps succeeded, but please complete the manual steps listed above
echo   and re-run "setup.bat" in a new Command Prompt window to confirm readiness.
echo =============================================================================
exit /b 0

:summary_not_ready
echo =============================================================================
echo   FINAL READINESS STATUS: NOT READY (!FAIL_COUNT! failure(s), !ACTION_COUNT! manual action(s))
echo   One or more required components could not be verified. Follow the recovery
echo   steps above and re-run "setup.bat".
echo =============================================================================
exit /b 1
