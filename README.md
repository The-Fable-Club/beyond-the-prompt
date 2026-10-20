# AI Development Event — Participant Environment Onboarding

Welcome! This repository prepares your laptop for our hands-on AI development event. Whether you are a first-time attendee on a brand-new laptop (with **no Git** and **no package managers** installed) or an experienced developer, these scripts will inspect your environment, install missing tools safely, and give you a clear readiness report.

---

## Supported Operating Systems

| Operating System | Supported Architectures | Setup Script | First-Run Bootstrap Launcher | Terminal to Use |
| :--- | :--- | :--- | :--- | :--- |
| **macOS** (macOS 13 Ventura or newer recommended) | Apple Silicon (`arm64`) & Intel (`x86_64`) | `setup.zsh` | `bootstrap.zsh` | **Terminal** (Zsh) |
| **Windows** (Windows 10 / Windows 11) | 64-bit (`x64` / `ARM64`) | `setup.bat` | `bootstrap.bat` | **Command Prompt** (`cmd.exe`) |

---

## Repository Configuration

| Resource | Official Location |
| :--- | :--- |
| **Repository URL** | [https://github.com/The-Fable-Club/beyond-the-prompt](https://github.com/The-Fable-Club/beyond-the-prompt) |
| **Clone URL** | `https://github.com/The-Fable-Club/beyond-the-prompt.git` |
| **Direct ZIP Archive Download** | [https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip](https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip) |

*(If you ever fork or mirror this repository under a different organization, you can update `REPO_WEB_URL` and `DEFAULT_REPO_ZIP_URL` at the top of [`bootstrap.zsh`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/bootstrap.zsh), [`bootstrap.bat`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/bootstrap.bat), [`setup.zsh`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/setup.zsh), and [`setup.bat`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/setup.bat).)*

---

## Prerequisites

1. **A reliable internet connection** (to download tools and npm packages).
2. **A personal laptop** with at least **2 GB of free disk space**.
3. **No pre-installed Git, Homebrew, or `winget` required**:
   - The initial bootstrap and setup scripts work even when Git, Homebrew (macOS), and `winget` (Windows) are completely absent.
4. **Your own accounts and credentials**:
   > **Important Account & Security Notice:** This repository and its scripts **never** request, collect, print, store, or transmit your passwords, API keys, or access tokens. You must sign in to any AI tools or services during the event using **your own personal accounts and credentials**.

---

## What Gets Installed & Verified

Each component is detected independently:

| Component | Plain-English Description | Package / Binary |
| :--- | :--- | :--- |
| **1. Git CLI** | Version control tool used to clone repositories, manage branches, and create isolated Git worktrees for AI coding agents. | `git` |
| **2. Node.js & npm** | The JavaScript runtime (**Node.js v18+ LTS**, installs v22 LTS when needed) and package manager (**npm**) required to run modern AI CLI tools. | `node`, `npm` |
| **3. Zepher CLI** | **Zepher** ([`zepher-cli`](https://www.npmjs.com/package/zepher-cli)) — a persistent context, memory, and universal agent environment manager that synchronizes rules and skills across AI coding agents. *(Specifically `zepher-cli`, never `zephyr-cli`.)* | `zepher` |
| **4. Orca Desktop App** | **Orca** ([onorca.dev](https://www.onorca.dev)) — an Agent Development Environment (ADE) desktop application for running and coordinating AI coding agents in isolated Git worktrees. | `Orca.app` (macOS) / `Orca.exe` (Windows) |
| **5. Orca CLI** | The command-line interface bundled with the Orca desktop app for scripting worktrees, agent terminals, and the built-in browser from your shell. | `orca` |

---

## Quick Start Instructions

Choose **Option A** or **Option B** if you **do not** have Git installed yet, or **Option C** if you already have Git installed.

### Option A: No Git Installed — GitHub Browser ZIP Download (Recommended for Beginners)

1. Open the event repository page in your web browser: [https://github.com/The-Fable-Club/beyond-the-prompt](https://github.com/The-Fable-Club/beyond-the-prompt)
   *(Or download the ZIP directly from [https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip](https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip))*
2. Click the green **Code** button and select **Download ZIP**.
3. **Extract the downloaded `.zip` file**:
   - **On macOS**: Open your **Downloads** folder in Finder and **double-click** the `.zip` file to extract the folder. Open **Terminal**, type `cd ` (with a space), drag the extracted folder into the Terminal window, and press **Return**.
   - **On Windows**: Open your **Downloads** folder in File Explorer, **right-click** the `.zip` file, click **Extract All...**, and click **Extract**. Open **Command Prompt** (`cmd.exe`) and `cd` into the extracted folder:
     ```bat
     cd "%USERPROFILE%\Downloads\beyond-the-prompt-main"
     ```
4. **Run the setup script for your operating system** (see Step 2A or Step 2B below).

---

### Option B: No Git Installed — First-Run Bootstrap Launcher (`bootstrap.zsh` / `bootstrap.bat`)

If you only downloaded `bootstrap.zsh` (macOS) or `bootstrap.bat` (Windows)—or downloaded the `.zip` archive without extracting it—the bootstrap launcher will download/verify the repository ZIP archive (checking the ZIP magic header, archive structure, and optional SHA-256 hash), extract it to a temporary folder, and launch the setup script automatically:

**macOS (Terminal / Zsh):**
```zsh
chmod +x bootstrap.zsh
./bootstrap.zsh
```
*(Or using a browser-downloaded `.zip` file without extracting manually:)*
```zsh
chmod +x bootstrap.zsh
./bootstrap.zsh --local-zip ~/Downloads/beyond-the-prompt-main.zip
```

**Windows (Command Prompt / `cmd.exe`):**
```bat
bootstrap.bat
```
*(Or using a browser-downloaded `.zip` file without extracting manually:)*
```bat
bootstrap.bat --local-zip "%USERPROFILE%\Downloads\beyond-the-prompt-main.zip"
```

---

### Option C: Git Already Installed — Clone the Repository

```bash
git clone https://github.com/The-Fable-Club/beyond-the-prompt.git
cd beyond-the-prompt
```

---

### Step 2A: Run the Setup Script on macOS

Inside the repository folder in **Terminal**, run:

```zsh
chmod +x setup.zsh
./setup.zsh
```

*To inspect your machine without installing anything (read-only check):*
```zsh
./setup.zsh --check-only
```

---

### Step 2B: Run the Setup Script on Windows

Inside the repository folder in **Command Prompt** (`cmd.exe`), run:

```bat
setup.bat
```

*To inspect your machine without installing anything (read-only check):*
```bat
setup.bat --check-only
```

---

## How the Scripts Work Without Homebrew or `winget`

Neither script assumes a package manager is installed, and neither script ever installs an unofficial package manager or pipes remote scripts into your shell.

### macOS Behavior (With and Without Homebrew)

| Component | When Homebrew is Installed | When Homebrew is Absent (Standalone Fallback) |
| :--- | :--- | :--- |
| **Git CLI** | Uses Apple's official `xcode-select --install` (or `brew install git` fallback). | Uses Apple's built-in `xcode-select --install` (Command Line Developer Tools) — no Homebrew needed. |
| **Node.js & npm** | Installs `node@22` via `brew install node@22`. | Downloads the official **Node.js v22 LTS** standalone archive (`node-v22.x.x-darwin-arm64.tar.gz` or `darwin-x64.tar.gz`) from `https://nodejs.org/dist/latest-v22.x/`, verifies its **SHA-256 checksum** against the official `SHASUMS256.txt` manifest, and installs it **per-user** into `~/.local/node-lts` with symlinks in `~/.local/bin` (**zero `sudo` / admin rights required**). |
| **Zepher CLI** | Installs globally via `npm install -g zepher-cli` (uses per-user `~/.npm-global` if `/usr/local` requires `sudo`). | Installs per-user into `~/.local/node-lts` or `~/.npm-global` via `npm install -g zepher-cli` (**zero `sudo` required**). |
| **Orca Desktop App** | Installs via `brew install --cask stablyai/orca/orca`. | Downloads the official `orca-macos-arm64.dmg` or `orca-macos-x64.dmg` from GitHub Releases, verifies its **SHA-256 digest** against the official GitHub Release API and its **Apple code signature** via `codesign --verify --deep --strict`, mounts the `.dmg` read-only, and copies `Orca.app` into `/Applications` (if writable) or per-user `~/Applications/Orca.app`. |

> **Why Homebrew Is Never Installed Automatically:** Installing Homebrew modifies system directories (`/opt/homebrew` on Apple Silicon or `/usr/local` on Intel), installs system-wide build tools, and requires administrator (`sudo`) access. Because all event tools can be installed using Apple's built-in tools and official standalone distributions, `setup.zsh` never forces a Homebrew installation.

### Windows Behavior (With and Without `winget`)

| Component | When `winget` is Installed | When `winget` is Absent (Standalone Fallback) |
| :--- | :--- | :--- |
| **Git CLI** | Runs `winget install --id Git.Git --scope user -e --source winget` (falling back to standard scope if needed). | Opens the official Git for Windows download page (`https://git-scm.com/download/win`), guides you through the official standalone installer (supporting per-user installation without admin rights), pauses, refreshes `PATH`, and re-verifies `git --version`. |
| **Node.js & npm** | Runs `winget install --id OpenJS.NodeJS.LTS -e --source winget`. | Downloads the official **Node.js v22 LTS** standalone Windows archive (`node-v22.x.x-win-x64.zip` or `win-arm64.zip`) from `https://nodejs.org/dist/latest-v22.x/`, verifies its **SHA-256 checksum** via `certutil -hashfile` against `SHASUMS256.txt`, and extracts it **per-user** into `%LocalAppData%\Programs\nodejs` (**zero Administrator rights required**). |
| **Zepher CLI** | Verifies package metadata on npm and runs `npm install -g zepher-cli`. | Verifies package metadata on npm and runs `npm install -g zepher-cli` into per-user `%AppData%\npm`. |
| **Orca Desktop App** | Opens `https://www.onorca.dev/docs/install` (Orca does not publish an official `winget` package ID), pauses for the official installer (`orca-windows-setup.exe`), and verifies `Orca.exe`. | Same official standalone installer flow (`%LocalAppData%\Programs\Orca\Orca.exe` per-user installation). |

---

## Understanding Your Setup Summary, Permissions & Partial Readiness

At the end of every run, the script prints a summary table with a status for each component:

- **`PASS`**: Installed and verified during this run.
- **`SKIPPED`**: Already installed and verified—nothing needed to be reinstalled.
- **`ACTION REQUIRED`**: Automated checks succeeded, but a manual step is needed from you (for example, completing the macOS Command Line Tools dialog, finishing the Orca Windows installer, or enabling the Orca CLI inside Orca Settings).
- **`FAIL`**: A required check or installation step failed. Follow the numbered recovery step printed below the table.

### Final Readiness Banner
- **`FULLY READY`**: All 5 components show `PASS` or `SKIPPED`. You are 100% ready for the event!
- **`PARTIALLY READY`**: Core tools are in place and zero errors occurred, but one or more items show `ACTION REQUIRED`. Complete the listed manual instructions, **open a new terminal window**, and re-run the setup script to reach `FULLY READY`.
- **`NOT READY`**: One or more required components reported `FAIL`. Follow the recovery instructions in the terminal output or the Troubleshooting section below, then re-run the script.

### Permissions & Limitations
- **Per-User First**: Both scripts prefer per-user directories (`~/.local`, `~/Applications` on macOS; `%LocalAppData%\Programs`, `%AppData%\npm` on Windows) so administrator privileges are avoided whenever possible.
- **When OS Prompts Appear**:
  - macOS may display a GUI prompt when `xcode-select --install` installs Apple Command Line Tools, or ask for your password if Homebrew Cask moves `Orca.app` into `/Applications`.
  - Windows User Account Control (UAC) may prompt for permission if `winget` installs a system-wide MSI package.
- **Resumable & Idempotent**: You can interrupt or re-run `./setup.zsh` and `setup.bat` as many times as needed. Any component completed in an earlier run or installed manually will be detected and marked `SKIPPED`.

---

## Troubleshooting Guide

### 1. macOS Permissions: `"permission denied"` or Gatekeeper Quarantine
If macOS blocks `setup.zsh` or `bootstrap.zsh` from running after downloading a ZIP:
```zsh
chmod +x setup.zsh bootstrap.zsh
xattr -d com.apple.quarantine setup.zsh bootstrap.zsh 2>/dev/null || true
./setup.zsh
```

### 2. Newly Installed Tools Are Not Found (`PATH` Refresh Needed)
When an installer finishes, your currently open terminal window may not yet include the new binary directory on its `PATH`.
- **Fix**: Close your current Terminal or Command Prompt window, open a **brand-new** terminal window, `cd` back into this repository, and re-run `./setup.zsh` (macOS) or `setup.bat` (Windows).
- **Per-User PATH on macOS** (if standalone Node.js or npm packages were installed into `~/.local/bin`):
  ```zsh
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
  ```
- **Per-User PATH on Windows** (if standalone Node.js was extracted into `%LocalAppData%\Programs\nodejs`):
  ```bat
  set "PATH=%LocalAppData%\Programs\nodejs;%AppData%\npm;%PATH%"
  ```

### 3. Git Installation Issues
- **macOS**: Wait for the `Install Command Line Developer Tools` progress bar to finish completely, then re-run `./setup.zsh`. If the popup does not appear, download Git from [https://git-scm.com/download/mac](https://git-scm.com/download/mac).
- **Windows**: Download and run the official **64-bit Git for Windows Setup** from [https://git-scm.com/download/win](https://git-scm.com/download/win) using the default options, open a new Command Prompt, and re-run `setup.bat`.

### 4. Node.js or npm Version / Version Manager Issues
`zepher-cli` requires **Node.js v18.0.0 or newer** (v22 LTS recommended).
- If you use a Node version manager (**nvm**, **nvm-windows**, **fnm**, **Volta**, or **asdf**), the setup script intentionally avoids overwriting it. Switch to an LTS version using your version manager:
  ```bash
  # macOS (nvm)
  nvm install --lts && nvm use --lts

  # Windows Command Prompt (nvm-windows)
  nvm install lts
  nvm use lts
  ```
- Otherwise, download the official **Node.js LTS** installer (`.pkg` for macOS or `.msi` for Windows) from [https://nodejs.org/en/download](https://nodejs.org/en/download).

### 5. `zepher-cli` Package Installation Failures
- Make sure you install **`zepher-cli`** (with an **`e`**), **not** `zephyr-cli`:
  ```bash
  npm install -g zepher-cli
  zepher --version
  ```

### 6. Orca CLI (`orca`) Registration & Verification Issues
Installing the Orca desktop app does not automatically place `orca` on your `PATH`.
1. Open the **Orca** desktop application.
2. Open **Settings → General → Orca CLI**.
3. Click to register/enable the `orca` command on your `PATH`.
4. **Open a new terminal window** (macOS Terminal or Windows Command Prompt).
5. Keep the **Orca desktop application open and running**, then verify:
   ```bash
   orca status --json
   ```

---

## Official Tool Documentation

- **Git CLI**: [https://git-scm.com/doc](https://git-scm.com/doc)
  - macOS Downloads: [https://git-scm.com/download/mac](https://git-scm.com/download/mac)
  - Windows Downloads: [https://git-scm.com/download/win](https://git-scm.com/download/win)
- **Node.js & npm**: [https://nodejs.org/en/download](https://nodejs.org/en/download)
  - Official v22 LTS Distribution & Checksums: [https://nodejs.org/dist/latest-v22.x/](https://nodejs.org/dist/latest-v22.x/)
- **Zepher CLI (`zepher-cli`)**: [https://www.npmjs.com/package/zepher-cli](https://www.npmjs.com/package/zepher-cli)
- **Orca Website**: [https://www.onorca.dev](https://www.onorca.dev)
- **Orca Installation Guide**: [https://www.onorca.dev/docs/install](https://www.onorca.dev/docs/install)
- **Orca CLI Overview**: [https://www.onorca.dev/docs/cli/overview](https://www.onorca.dev/docs/cli/overview)
