# 🚀 Identity System Setup Guide

This guide will help you set up and deploy your Identity System on both local (Anvil) and testnet (Sepolia) networks.

## 📋 Prerequisites

- Windows 10/11 with PowerShell
- Git installed
- Python 3.7+ installed

## 🔧 Step 1: Install Foundry

### Option A: Using Git Bash (Recommended for Windows)
```bash
# Open Git Bash and run:
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

### Option B: Manual Installation
1. Download the latest Foundry release from: https://github.com/foundry-rs/foundry/releases
2. Extract and add to your PATH
3. Run `foundryup` to get the latest version

### Option C: Using WSL (Windows Subsystem for Linux)
```bash
# Install WSL first, then:
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

## 🔑 Step 2: Set Up QTSP Private Key

After installing Foundry, set up your QTSP private key in the keystore:

```bash
# Add QTSP private key to keystore
forge keystore set QTSP_PRIVATE_KEY

# When prompted, enter your QTSP private key
# This key will be used by QTSPContract to sign claim tokens
```

## 🌍 Step 3: Environment Configuration

1. Copy the example environment file:
```bash
copy env.example .env
```

2. Edit `.env` and add your Sepolia configuration:
```env
# Sepolia Testnet Configuration
SEPOLIA_PRIVATE_KEY=your_actual_sepolia_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_project_id
```

### Getting Sepolia Configuration:

#### RPC URL Options:
- **Infura**: https://infura.io/ (free tier available)
- **Alchemy**: https://www.alchemy.com/ (free tier available)
- **QuickNode**: https://www.quicknode.com/ (free tier available)

#### Private Key:
- Use MetaMask or another wallet to export your Sepolia private key
- **⚠️ Never share or commit your private key!**

## 🧪 Step 4: Test Local Deployment (Anvil)

1. **Start Anvil** (in a new terminal):
```bash
anvil
```

2. **Deploy to Anvil** (in another terminal):
```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 🚀 Step 5: Deploy to Sepolia

1. **Verify your setup**:
```bash
python script/verify_deployment.py
```

2. **Deploy to Sepolia**:
```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## 📊 Verification

Run the verification script to check your setup:
```bash
python script/verify_deployment.py
```

This will check:
- ✅ Foundry installation
- ✅ QTSP keystore setup
- ✅ Environment variables
- ✅ Contract files
- ✅ Deployment scripts
- ✅ Contract compilation

## 🔍 Troubleshooting

### Foundry Not Found
```bash
# Make sure Foundry is in your PATH
# Try restarting your terminal after installation
# Check if forge --version works
```

### Keystore Issues
```bash
# List existing keys
forge keystore list

# Remove and re-add if needed
forge keystore remove QTSP_PRIVATE_KEY
forge keystore set QTSP_PRIVATE_KEY
```

### Compilation Errors
```bash
# Clean and rebuild
forge clean
forge build

# Check for syntax errors in contracts
forge build --force
```

### Network Issues
```bash
# Check current network
forge chain list

# Verify RPC URL is accessible
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $SEPOLIA_RPC_URL
```

## 📁 Project Structure

```
IdentitySystem/
├── src/
│   ├── ClaimManagement/
│   │   ├── ClaimsRegistry.sol          # Claim type definitions
│   │   ├── ClaimsRegistryContract.sol  # Claim registry contract
│   │   └── ClaimToken.sol              # Custom claim tokens
│   ├── QTSPManagement/
│   │   ├── QTSPContract.sol            # QTSP operations
│   │   └── QTSPRightsManager.sol       # QTSP permissions
│   ├── TrustSmartContract.sol          # Signature verification
│   └── RestrictedSmartContract.sol     # Example service
├── script/
│   ├── HelperConfig.s.sol              # Network configuration
│   ├── Deploy.s.sol                    # Main deployment script
│   └── verify_deployment.py            # Setup verification
├── test/                               # Test files
├── foundry.toml                        # Foundry configuration
└── .env                                # Environment variables
```

## 🎯 What Gets Deployed

The deployment script automatically deploys and configures:

1. **QTSPRightsManager** - Manages trusted QTSP contracts
2. **ClaimsRegistryContract** - Registry for claim types
3. **TrustSmartContract** - Handles signature verification
4. **QTSPContract** - Issues/revokes claim tokens
5. **ClaimToken (OVER_18)** - Age verification token
6. **ClaimToken (EU_CITIZEN)** - EU citizenship token
7. **RestrictedSmartContract** - Example access control service

## 🔐 Security Features

- **Foundry Keystore**: Secure private key management
- **No Hardcoded Keys**: Private keys accessed via environment variables
- **Centralized Authorization**: Single source of truth for permissions
- **Signature Storage**: Signatures stored in ClaimToken contracts
- **Verification Chain**: Complete signature verification pipeline

## 🚀 Next Steps

After successful deployment:

1. **Test the System**:
   - Issue claims using `QTSPContract.issueToken()`
   - Verify signatures using `TrustSmartContract.verifyStoredSignature()`
   - Test access control with `RestrictedSmartContract`

2. **Monitor**:
   - Check contract addresses in deployment logs
   - Verify permissions are set correctly
   - Test with different user addresses

3. **Extend**:
   - Add new claim types in `ClaimsRegistry.sol`
   - Create new `ClaimToken` contracts
   - Implement additional restricted services

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify all prerequisites are met
3. Run the verification script to identify problems
4. Check Foundry documentation: https://book.getfoundry.sh/

---

**Happy Deploying! 🎉**
