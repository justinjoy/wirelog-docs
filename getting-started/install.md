---
title: Installation
parent: Getting Started
nav_order: 1
---

# Build and Install Guide

wirelog is designed to be lightweight and portable, but building the current version requires a few standard tools as it binds a C11 frontend to a Rust execution backend. 

## Prerequisites

Before building wirelog, you need the following tools installed on your system:
- **C11 Compiler**: `gcc` or `clang`
- **Rust Toolchain**: `cargo` and `rustc`
- **Build System**: `meson` (>= 0.60.0) and `ninja`

Depending on your operating system, follow the specific commands below.

### Ubuntu / Debian

```bash
# Update package list
sudo apt-get update

# Install build tools
sudo apt-get install -y build-essential python3-pip ninja-build

# Install Meson via pip (to get a recent version)
pip3 install --user meson

# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### macOS

Using [Homebrew](https://brew.sh/):

```bash
# Install Meson, Ninja
brew install meson ninja

# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
*Note: macOS typically comes with clang pre-installed via Xcode Command Line Tools. If not, run `xcode-select --install`.*

### Windows

The easiest way to build on Windows is using MSYS2 or the Windows Subsystem for Linux (WSL).

#### WSL (Ubuntu)
Follow the [Ubuntu / Debian](#ubuntu--debian) instructions inside your WSL terminal.

#### MSYS2 (MinGW64)
Open the **MSYS2 MinGW 64-bit** terminal:

```bash
# Install GCC, Ninja, and Python
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja python3-pip

# Install Meson
pip3 install meson

# Install Rust toolchain (choose the x86_64-pc-windows-gnu toolchain)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

---

## Building

Once your prerequisites are satisfied, building wirelog is straightforward. 
Clone the repository and initialize the Meson build directory:

```bash
# Clone the repository
git clone https://github.com/justinjoy/wirelog.git
cd wirelog

# Setup the build directory with the Differential Dataflow backend enabled
meson setup builddir -Ddd=true

# Compile the project
meson compile -C builddir
```

## Running wirelog

After a successful build, the `wirelog-cli` binary will be located in the `builddir` folder. 
You can run a Datalog program by passing the file to the CLI:

```bash
./builddir/wirelog-cli your_program.dl
```

For more details on CLI options, see the [CLI Usage](../user-guide/cli).
