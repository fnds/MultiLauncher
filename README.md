# 🚀 Multi App Launcher

A lightweight Windows GUI tool to launch multiple applications with optional delays, admin control, and profile management.

---

## ✨ Features

### 🧩 Multi-App Launching
- Launch multiple applications with a single click
- Supports both **Run All** and **Run Selected**

---

### ⏱️ Smart Launch Control
- **Per-app delay** before launch
- Optional **wait until app window appears**
- Prevents race conditions and improves startup sequencing

---

### 🔐 Admin Control (Opt-In)
- Run apps as administrator **only when explicitly selected**
- No forced elevation for the launcher itself
- Avoids unnecessary UAC prompts

---

### 📦 Profile Management
- Save groups of apps as named profiles
- Load profiles instantly
- Delete profiles with confirmation
- Profiles stored locally as JSON

---

### 📝 Logging
- Real-time execution log
- Shows:
  - Start events
  - Failures
  - Delays
  - Window detection status
  - Process IDs

---

### 🖱️ User-Friendly GUI
- Built with Windows Forms
- Simple and intuitive interface
- Browse for executables easily
- Edit entries inline

---

### 🛑 Process Control
- Track launched processes
- Stop all launched apps with one click

---

### ⚙️ Robust Execution
- Handles:
  - Missing files
  - Empty arguments
  - Invalid delays
- Timeout fallback for apps without windows

---

## 📁 Configuration

Profiles are saved to:

%USERPROFILE%\multi_launcher_profiles.json

---

## 🛠️ Build Instructions

Convert to `.exe` using PS2EXE:

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-PS2EXE .\MultiLauncher.ps1 .\MultiLauncher.exe -noConsole -title "Multi Launcher"

