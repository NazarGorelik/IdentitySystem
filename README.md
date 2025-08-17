# On-Chain Identity System

A decentralized identity system built on Ethereum that enables on-chain verification of off-chain claims through Qualified Trust Service Providers (QTSPs).

## Overview

This system implements the architecture described in the [Excalidraw diagram](https://excalidraw.com/#json=BzP-MTTZSl3p876VAX8_Q,3V8hi22jXmOLz7d7yRuiTA) and provides:

- **Claims Registry**: Standardized claim definitions
- **SoulBound Tokens (SBT)**: Non-transferable tokens storing user claims
- **Trust Smart Contract**: Verifies QTSP signatures using ECDSA
- **Restricted Smart Contracts**: Access control based on verified claims

## Architecture

### Core Components

1. **Claims Registry Library** (`ClaimsRegistry.sol`)
   - Defines standardized claim types (OVER_18, EU_CITIZEN, STUDENT, etc.)
   - Provides validation and naming functions

2. **SoulBound Token Contract** (`SoulBoundToken.sol`)
   - Stores user claims as non-transferable tokens
   - Each token contains claim type, QTSP signature, and validity status
   - Supports token issuance and revocation

3. **Trust Smart Contract** (`TrustSmartContract.sol`)
   - Maintains registry of trusted QTSP addresses
   - Verifies signatures using ECDSA
   - Ensures only trusted QTSPs can issue valid claims

4. **Restricted Smart Contract** (`RestrictedSmartContract.sol`)
   - Example implementation showing access control
   - Requires specific claims for service access
   - Demonstrates the complete verification flow

## Workflow

1. **QTSP Registration**: Trusted QTSPs are added to the Trust Smart Contract
2. **Claim Issuance**: QTSP issues a signed claim to a user's wallet
3. **Token Storage**: The claim is stored as a SoulBound Token
4. **Service Access**: User provides claim and signature to access restricted services
5. **Verification**: Restricted contract verifies signature with Trust contract

## Key Features

### Signature Verification
- Uses ECDSA for cryptographic signature verification
- Supports Ethereum's personal message signing standard
- Prevents signature malleability attacks

### Access Control
- Claims-based access control for smart contracts
- Support for multiple claim types per user
- Revocable claims by issuing QTSP

### Security
- Only trusted QTSPs can issue valid claims
- Non-transferable tokens prevent claim trading
- Cryptographic verification ensures authenticity

## Usage

### Deployment

```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url your_rpc_url --broadcast
```

### Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testCompleteFlow

# Run with verbose output
forge test -vvv
```

### Adding a QTSP

```solidity
// After deployment, add trusted QTSPs
trustContract.addTrustedQTSP(qtspAddress);
```

### Issuing a Claim

```solidity
// QTSP issues a claim to a user
bytes32 claim = ClaimsRegistry.OVER_18;
bytes memory signature = createSignature(userAddress, claim, qtspPrivateKey);
sbtContract.issueToken(userAddress, claim, signature, qtspAddress);
```

### Accessing Restricted Services

```solidity
// User accesses age-restricted service
restrictedContract.accessAgeRestrictedService(userAddress, signature);
```

## Claim Types

The system supports the following predefined claims:

- `OVER_18`: Age verification (18+ years old)
- `EU_CITIZEN`: European Union citizenship
- `STUDENT`: Verified student status
- `BUSINESS`: Verified business entity
- `PROFESSIONAL`: Verified professional status

## Security Considerations

1. **Private Key Management**: QTSPs must securely manage their private keys
2. **Signature Verification**: All signatures are verified on-chain using ECDSA
3. **Access Control**: Only trusted QTSPs can issue valid claims
4. **Token Revocation**: QTSPs can revoke issued claims if necessary

## Development

### Prerequisites

- Foundry (latest version)
- Node.js (for additional tooling)

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd IdentitySystem

# Install dependencies
forge install

# Build contracts
forge build
```

### Project Structure

```
src/
├── ClaimsRegistry.sol      # Claim definitions library
├── SoulBoundToken.sol      # SBT implementation
├── TrustSmartContract.sol  # Signature verification
└── RestrictedSmartContract.sol # Access control example

test/
└── IdentitySystem.t.sol    # Comprehensive tests

script/
└── Deploy.s.sol           # Deployment script
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Thesis Context

This implementation serves as the foundation for a bachelor thesis on on-chain identity systems. The system demonstrates:

- Cryptographic signature verification
- Decentralized identity management
- Access control mechanisms
- Integration with Ethereum smart contracts

The architecture follows the design outlined in the provided Excalidraw diagram and implements all core components described in the system overview.
