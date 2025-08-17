# Network Configuration and Deployment Scripts

This directory contains scripts for deploying the Identity System to different networks with automatic network detection and contract deployment.

## Files

- `HelperConfig.s.sol` - Network configuration helper for different chains with automatic contract deployment
- `Deploy.s.sol` - Main deployment script that automatically detects network and deploys contracts

## Network Configuration

### Supported Networks

1. **Anvil (Local)** - Chain ID: 31337
   - Uses `getOrCreateNetworkConfig()` function
   - Automatically deploys new contracts for testing
   - Uses default Anvil private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

2. **Sepolia Testnet** - Chain ID: 11155111
   - Uses `getSepoliaEthConfig()` function for existing contracts
   - Uses `deploySepoliaContracts()` function for new deployments
   - Requires `SEPOLIA_PRIVATE_KEY` environment variable

### Environment Variables

Create a `.env` file in your project root with the following variables:

```env
# For Sepolia deployment
SEPOLIA_PRIVATE_KEY=your_sepolia_private_key_here
SEPOLIA_RPC_URL=your_sepolia_rpc_url_here

# For QTSP keystore (required for all networks)
# Add this key to your Foundry keystore first:
# forge keystore set QTSP_PRIVATE_KEY
```

## Usage

### Deploy to Sepolia

1. Set up your environment variables:
```bash
export SEPOLIA_PRIVATE_KEY=your_private_key
export SEPOLIA_RPC_URL=your_rpc_url
```

2. Deploy using the main script:
```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### Deploy to Anvil (Local)

```bash
# Start anvil
anvil

# Deploy in another terminal
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Using HelperConfig

The `HelperConfig` contract automatically detects the network and provides the appropriate configuration:

```solidity
HelperConfig config = new HelperConfig();
NetworkConfig networkConfig = config.activeNetworkConfig();
```

## Contract Architecture

The deployment script deploys the complete Identity System:

1. **QTSPRightsManager** - Manages trusted QTSP contracts and their permissions
2. **ClaimsRegistryContract** - Registry for claim types and their token contracts
3. **TrustSmartContract** - Handles signature verification and authorization
4. **QTSPContract** - Issues and revokes claim tokens using keystore private key
5. **ClaimToken** (OVER_18) - Custom token for age verification claims
6. **ClaimToken** (EU_CITIZEN) - Custom token for EU citizenship claims
7. **RestrictedSmartContract** - Example service that verifies claims

## Configuration Options

### For Sepolia Network

You have two options when using `getSepoliaEthConfig()`:

1. **Use Existing Deployed Contracts** (Recommended for production):
   - Replace the `address(0)` values with actual deployed contract addresses
   - Example:
   ```solidity
   return NetworkConfig({
       rightsManager: QTSPRightsManager(0x1234...),
       claimsRegistry: ClaimsRegistryContract(0x5678...),
       trustContract: TrustSmartContract(0x9abc...),
       // ... other contracts
       deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY"),
       qtspKeyAlias: "QTSP_PRIVATE_KEY"
   });
   ```

2. **Deploy New Contracts**:
   - Use the `deploySepoliaContracts()` function
   - This will deploy fresh contracts on Sepolia

### For Anvil Network

The `getOrCreateNetworkConfig()` function automatically:
- Deploys new contracts if none exist
- Returns existing contracts if already deployed
- Uses default test accounts and keystore

## QTSP Keystore Setup

Before deployment, you must set up the QTSP private key in Foundry's keystore:

```bash
# Add QTSP private key to keystore
forge keystore set QTSP_PRIVATE_KEY

# When prompted, enter your QTSP private key
# This key will be used by QTSPContract to sign claim tokens
```

## Automatic Permission Setup

The deployment script automatically:
- Registers claim tokens with the Claims Registry
- Adds QTSP Contract to the trusted list
- Grants permissions for OVER_18 and EU_CITIZEN claims
- Sets up the complete authorization chain

## Testing the System

After deployment, you can test the system by:

1. **Issuing Claims**: Call `QTSPContract.issueToken(user, claim)` to issue claim tokens
2. **Verifying Claims**: Use `TrustSmartContract.verifyStoredSignature()` to verify stored signatures
3. **Accessing Services**: Call `RestrictedSmartContract.accessAgeRestrictedService(user)` to test access control

## Network Detection

The system automatically detects the current network:
- **Chain ID 11155111**: Sepolia testnet
- **Chain ID 31337**: Anvil local network
- **Other**: Unsupported network (reverts)

This allows you to use the same deployment script for different networks without modification. 