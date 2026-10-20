@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===========================================================================
REM Cross-Platform Event Onboarding — Windows First-Run Bootstrap Launcher
REM File: bootstrap.bat
REM ===========================================================================
REM Purpose:
REM   Provides a lightweight first-run bootstrap route on Windows when Git and
REM   winget are NOT installed and the repository has not been cloned yet.
REM
REM   It can:
REM     1. Download the repository ZIP archive from a configured official GitHub
REM        URL (using Windows built-in 'curl.exe'),
REM     2. Verify the downloaded ZIP archive (non-empty, optional SHA-256 via
REM        'certutil -hashfile', and archive structure check via 'tar.exe -tf'),
REM     3. Extract the archive to an isolated temporary directory, and
REM     4. Launch 'setup.bat' with any forwarded arguments.
REM
REM   It also supports bootstrapping from a browser-downloaded local .zip file
REM   ('bootstrap.bat --local-zip C:\path\to\repo.zip') or launching a
REM   co-located 'setup.bat'.
REM
REM Usage:
REM   bootstrap.bat [OPTIONS]
REM ===========================================================================

REM ---------------------------------------------------------------------------
REM ORGANIZER CONFIGURATION (Configured for The-Fable-Club/beyond-the-prompt)
REM ---------------------------------------------------------------------------
set "REPO_WEB_URL=https://github.com/The-Fable-Club/beyond-the-prompt"
if defined ONBOARD_REPO_WEB_URL set "REPO_WEB_URL=%ONBOARD_REPO_WEB_URL%"

set "DEFAULT_REPO_ZIP_URL=https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip"
if defined ONBOARD_REPO_ZIP_URL set "DEFAULT_REPO_ZIP_URL=%ONBOARD_REPO_ZIP_URL%"

REM Optional: Set a 64-character hex SHA-256 checksum if pinning a fixed release ZIP
set "DEFAULT_REPO_ZIP_SHA256="
if defined ONBOARD_REPO_ZIP_SHA256 set "DEFAULT_REPO_ZIP_SHA256=%ONBOARD_REPO_ZIP_SHA256%"

REM ---------------------------------------------------------------------------
REM Runtime State
REM ---------------------------------------------------------------------------
set "ZIP_URL=%DEFAULT_REPO_ZIP_URL%"
set "LOCAL_ZIP="
if defined ONBOARD_LOCAL_ZIP set "LOCAL_ZIP=%ONBOARD_LOCAL_ZIP%"
set "EXPECTED_SHA256=%DEFAULT_REPO_ZIP_SHA256%"
set "FORCE_DOWNLOAD=0"
set "KEEP_TEMP=0"
set "SETUP_ARGS="
set "SCRIPT_DIR=%~dp0"

REM ---------------------------------------------------------------------------
REM Parse Command-Line Arguments
REM ---------------------------------------------------------------------------
:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--zip-url" goto :arg_zip_url
if /I "%~1"=="--local-zip" goto :arg_local_zip
if /I "%~1"=="--sha256" goto :arg_sha256
if /I "%~1"=="--force-download" set "FORCE_DOWNLOAD=1" & shift & goto :parse_args
if /I "%~1"=="--keep-temp" set "KEEP_TEMP=1" & shift & goto :parse_args
if /I "%~1"=="--check-only" set "SETUP_ARGS=!SETUP_ARGS! --check-only" & shift & goto :parse_args
if /I "%~1"=="--dry-run" set "SETUP_ARGS=!SETUP_ARGS! --dry-run" & shift & goto :parse_args
if /I "%~1"=="--no-prompt" set "SETUP_ARGS=!SETUP_ARGS! --no-prompt" & shift & goto :parse_args
if /I "%~1"=="--non-interactive" set "SETUP_ARGS=!SETUP_ARGS! --non-interactive" & shift & goto :parse_args
if /I "%~1"=="--help" goto :show_help
if /I "%~1"=="-h" goto :show_help
if /I "%~1"=="/?" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help_error

:arg_zip_url
if "%~2"=="" echo [ERROR] --zip-url requires a URL argument. & goto :show_help_error
set "ZIP_URL=%~2"
shift
shift
goto :parse_args

:arg_local_zip
if "%~2"=="" echo [ERROR] --local-zip requires a file path argument. & goto :show_help_error
set "LOCAL_ZIP=%~2"
shift
shift
goto :parse_args

:arg_sha256
if "%~2"=="" echo [ERROR] --sha256 requires a 64-character hex digest. & goto :show_help_error
set "EXPECTED_SHA256=%~2"
shift
shift
goto :parse_args

:show_help
echo.
echo Usage: bootstrap.bat [BOOTSTRAP_OPTIONS] [SETUP_OPTIONS]
echo.
echo Windows First-Run Bootstrap Launcher (works without Git or winget).
echo.
echo Bootstrap Options:
echo   --zip-url ^<URL^>        Download repository ZIP from the specified HTTPS URL
echo   --local-zip ^<FILE^>     Extract and run from a locally downloaded .zip archive
echo   --sha256 ^<HASH^>        Expected 64-char SHA-256 checksum for the ZIP archive
echo   --force-download       Download/extract ZIP even if setup.bat is in current folder
echo   --keep-temp            Keep extracted temporary directory after completion
echo   --help, -h, /?         Show this help message and exit
echo.
echo Forwarded Setup Options:
echo   --check-only, --dry-run        Verify installed tools without making changes
echo   --no-prompt, --non-interactive Do not pause for interactive browser prompts
echo.
exit /b 0

:show_help_error
echo Run "bootstrap.bat --help" for usage instructions.
exit /b 2

:args_done

echo.
echo =============================================================================
echo   AI Development Event — Windows First-Run Bootstrap Launcher
echo =============================================================================
echo   - Works without Git or winget installed.
echo   - Verifies archive integrity before extracting and launching setup.bat.
echo -----------------------------------------------------------------------------

REM ---------------------------------------------------------------------------
REM Route 1: Co-located setup.bat (Already extracted or cloned)
REM ---------------------------------------------------------------------------
if not "%FORCE_DOWNLOAD%"=="0" goto :prepare_temp
if defined LOCAL_ZIP goto :prepare_temp
if not "%ZIP_URL%"=="%DEFAULT_REPO_ZIP_URL%" goto :prepare_temp
if not exist "%SCRIPT_DIR%setup.bat" goto :prepare_temp

echo     [INFO] Found co-located setup script at: %SCRIPT_DIR%setup.bat
echo     [INFO] Launching setup.bat directly...
call "%SCRIPT_DIR%setup.bat" %SETUP_ARGS%
set "DIRECT_RC=%ERRORLEVEL%"
endlocal & exit /b %DIRECT_RC%

REM ---------------------------------------------------------------------------
REM Prepare Temporary Workspace
REM ---------------------------------------------------------------------------
:prepare_temp
set "TEMP_WORKDIR=%TEMP%\event-onboard-bootstrap-%RANDOM%-%RANDOM%"
mkdir "%TEMP_WORKDIR%" >nul 2>nul
if errorlevel 1 goto :temp_mkdir_failed

set "ARCHIVE_FILE=%TEMP_WORKDIR%\repo-bootstrap.zip"
set "EXTRACT_DIR=%TEMP_WORKDIR%\extracted"

if defined LOCAL_ZIP goto :route_local_zip
goto :route_remote_zip

:temp_mkdir_failed
echo     [FAIL] Could not create temporary directory: %TEMP_WORKDIR%
exit /b 1

REM ---------------------------------------------------------------------------
REM Route 2: Bootstrap from Local ZIP File (--local-zip)
REM ---------------------------------------------------------------------------
:route_local_zip
echo     [INFO] Bootstrapping from local ZIP archive: %LOCAL_ZIP%
if not exist "%LOCAL_ZIP%" goto :local_zip_missing
copy /Y "%LOCAL_ZIP%" "%ARCHIVE_FILE%" >nul 2>nul
if errorlevel 1 goto :local_zip_copy_failed
goto :verify_and_extract

:local_zip_missing
echo     [FAIL] Local ZIP file not found: %LOCAL_ZIP%
call :cleanup_temp
exit /b 1

:local_zip_copy_failed
echo     [FAIL] Could not copy local ZIP file to temporary workspace.
call :cleanup_temp
exit /b 1

REM ---------------------------------------------------------------------------
REM Route 3: Download Repository ZIP from Configured GitHub URL
REM ---------------------------------------------------------------------------
:route_remote_zip
if "%ZIP_URL%"=="" goto :placeholder_not_configured
if /I "%ZIP_URL%"=="<REPOSITORY_ZIP_URL>" goto :placeholder_not_configured
echo "%ZIP_URL%" | find "<" >nul 2>nul
if not errorlevel 1 goto :placeholder_not_configured

if /I not "!ZIP_URL:~0,8!"=="https://" goto :insecure_url

where curl >nul 2>nul
if errorlevel 1 goto :no_curl

echo     [INFO] Downloading repository ZIP archive from:
echo            %ZIP_URL%
curl -fL --retry 2 --connect-timeout 10 -o "%ARCHIVE_FILE%" "%ZIP_URL%"
if errorlevel 1 goto :download_failed
goto :verify_and_extract

:placeholder_not_configured
echo     [ACTION REQUIRED] Repository ZIP URL placeholder has not been configured yet.
echo.
echo     For Event Organizers:
echo       Replace '<REPOSITORY_ZIP_URL>' in bootstrap.bat (line 36) with your
echo       official GitHub ZIP URL, for example:
echo       https://github.com/^<ORG^>/^<REPO^>/archive/refs/heads/main.zip
echo.
echo     For Event Participants (No Git Required):
echo       1. Open the event repository in your browser (%REPO_WEB_URL%).
echo       2. Click 'Code' -^> 'Download ZIP'.
echo       3. Right-click the downloaded .zip file and click 'Extract All...',
echo          or run: bootstrap.bat --local-zip "%%USERPROFILE%%\Downloads\<downloaded-file>.zip"
call :cleanup_temp
exit /b 1

:insecure_url
echo     [FAIL] Refusing insecure or non-HTTPS ZIP URL: %ZIP_URL%
echo     [INFO] Only official 'https://' archive URLs are permitted.
call :cleanup_temp
exit /b 1

:no_curl
echo     [FAIL] 'curl.exe' was not found on PATH to download the repository archive.
echo     [INFO] Please download the ZIP in your browser and run:
echo            bootstrap.bat --local-zip "C:\path\to\repo.zip"
call :cleanup_temp
exit /b 1

:download_failed
echo     [FAIL] Failed to download repository ZIP from %ZIP_URL%
echo     [INFO] Please download the ZIP manually in your browser and run:
echo            bootstrap.bat --local-zip "%%USERPROFILE%%\Downloads\<repo>.zip"
call :cleanup_temp
exit /b 1

REM ---------------------------------------------------------------------------
REM Verify, Extract, and Launch setup.bat
REM ---------------------------------------------------------------------------
:verify_and_extract
if not exist "%ARCHIVE_FILE%" goto :archive_empty
set "ARCHIVE_SIZE=0"
for %%A in ("%ARCHIVE_FILE%") do set "ARCHIVE_SIZE=%%~zA"
if "!ARCHIVE_SIZE!"=="0" goto :archive_empty

if not defined EXPECTED_SHA256 goto :verify_zip_structure

set "ACTUAL_SHA256="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%ARCHIVE_FILE%" SHA256 2^>nul') do (
    if not defined ACTUAL_SHA256 set "ACTUAL_SHA256=%%H"
)
if /I not "!ACTUAL_SHA256!"=="%EXPECTED_SHA256%" goto :sha256_mismatch
echo     [PASS] SHA-256 checksum verified (!ACTUAL_SHA256!).

:verify_zip_structure
where tar >nul 2>nul
if errorlevel 1 goto :extract_with_powershell

tar -tf "%ARCHIVE_FILE%" >nul 2>nul
if errorlevel 1 goto :invalid_zip_archive
echo     [PASS] ZIP archive structure and integrity verified.

mkdir "%EXTRACT_DIR%" >nul 2>nul
echo     [INFO] Extracting verified archive into temporary workspace...
tar -xf "%ARCHIVE_FILE%" -C "%EXTRACT_DIR%"
if errorlevel 1 goto :extract_failed
goto :find_and_run_setup

:extract_with_powershell
mkdir "%EXTRACT_DIR%" >nul 2>nul
echo     [INFO] Extracting archive using local Expand-Archive...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ARCHIVE_FILE%' -DestinationPath '%EXTRACT_DIR%' -Force" >nul 2>nul
if errorlevel 1 goto :invalid_zip_archive
echo     [PASS] ZIP archive extracted and verified.

:find_and_run_setup
set "FOUND_SETUP_BAT="
for /f "delims=" %%F in ('dir /b /s "%EXTRACT_DIR%\setup.bat" 2^>nul') do (
    if not defined FOUND_SETUP_BAT set "FOUND_SETUP_BAT=%%F"
)
if not defined FOUND_SETUP_BAT goto :setup_bat_not_in_zip

echo     [PASS] Verified and extracted setup script: !FOUND_SETUP_BAT!
echo     [INFO] Launching setup.bat...
echo.
call "!FOUND_SETUP_BAT!" %SETUP_ARGS%
set "LAUNCH_RC=%ERRORLEVEL%"
call :cleanup_temp
endlocal & exit /b %LAUNCH_RC%

:archive_empty
echo     [FAIL] Downloaded archive file is missing or empty.
call :cleanup_temp
exit /b 1

:sha256_mismatch
echo     [FAIL] SHA-256 checksum mismatch for %ARCHIVE_FILE%!
echo            Expected: %EXPECTED_SHA256%
echo            Actual  : !ACTUAL_SHA256!
call :cleanup_temp
exit /b 1

:invalid_zip_archive
echo     [FAIL] File is not a valid ZIP archive or failed integrity check.
echo     [INFO] Ensure the URL points directly to a GitHub .zip archive, not an HTML web page.
call :cleanup_temp
exit /b 1

:extract_failed
echo     [FAIL] Failed to extract ZIP archive.
call :cleanup_temp
exit /b 1

:setup_bat_not_in_zip
echo     [FAIL] Could not find 'setup.bat' inside the extracted archive.
call :cleanup_temp
exit /b 1

:cleanup_temp
if "%KEEP_TEMP%"=="1" (
    echo     [INFO] Preserving temporary bootstrap directory (--keep-temp): %TEMP_WORKDIR%
    exit /b 0
)
if exist "%TEMP_WORKDIR%" rmdir /s /q "%TEMP_WORKDIR%" >nul 2>nul
exit /b 0
