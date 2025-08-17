# Foundry Installation Guide for Windows

## Prerequisites

1. **Git for Windows**: Download and install from https://git-scm.com/download/win
2. **Windows Subsystem for Linux (WSL)** or **Git Bash**

## Installation Methods

### Method 1: Using WSL (Recommended)

1. **Install WSL**:
   ```powershell
   wsl --install
   ```

2. **Open WSL terminal** and install Foundry:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   source ~/.bashrc
   foundryup
   ```

3. **Access Foundry from Windows**:
   ```powershell
   wsl forge --version
   ```

### Method 2: Using Git Bash

1. **Download Git Bash** from https://git-scm.com/download/win
2. **Open Git Bash** and run:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   source ~/.bashrc
   foundryup
   ```

### Method 3: Manual Installation

1. **Download Foundry binaries** from https://github.com/foundry-rs/foundry/releases
2. **Extract to a directory** (e.g., `C:\foundry`)
3. **Add to PATH**:
   - Open System Properties → Environment Variables
   - Add `C:\foundry` to PATH

## Verification

After installation, verify Foundry is working:

```bash
forge --version
cast --version
anvil --version
```

## Project Setup

Once Foundry is installed:

```bash
# Build contracts
forge build

# Run tests
forge test

# Start local node
anvil

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Troubleshooting

### Common Issues

1. **"forge not found"**: Ensure Foundry is in your PATH
2. **Permission errors**: Run as administrator or use WSL
3. **Git not found**: Install Git for Windows

### Alternative: Use Remix IDE

If you prefer not to install Foundry locally, you can use Remix IDE:

1. Go to https://remix.ethereum.org/
2. Upload the `.sol` files from the `src/` directory
3. Compile and test in the browser

## Next Steps

After installing Foundry:

1. **Build the project**: `forge build`
2. **Run tests**: `forge test`
3. **Deploy contracts**: Use the deployment script
4. **Start development**: Use `anvil` for local testing 