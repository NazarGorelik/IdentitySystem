# Token-Based Identity System with Granular QTSP Permissions

## Overview

This implementation creates a token-based identity system where each claim type (OVER_18, EU_CITIZEN, etc.) has its own separate ERC20 token contract. The system includes a **QTSP Rights Manager** that provides granular permission control, allowing specific QTSPs to manage only certain claim types.

## Architecture

### Core Components

1. **ClaimToken** (`ClaimToken.sol`)
   - ERC20 token representing a specific claim (e.g., "OVER_18", "EU_CITIZEN")
   - Non-transferable tokens (transfers are disabled)
   - Only authorized QTSPs can issue/revoke tokens
   - Each claim type gets its own token contract

2. **QTSPRightsManager** (`QTSPRightsManager.sol`)
   - **NEW**: Manages granular permissions for QTSPs
   - Allows specific QTSPs to manage only certain claim types
   - Handles signature verification with permission checks
   - Issues and revokes tokens based on verified signatures and permissions
   - Maps claim types to their respective token contracts

3. **RestrictedSmartContract** (`RestrictedSmartContract.sol`)
   - Example contract showing access control
   - Checks if users have required claim tokens
   - Verifies signatures before granting access
   - Updated to work with QTSP Rights Manager

4. **ClaimsRegistry** (`ClaimsRegistry.sol`)
   - Standardized claim definitions
   - Validation and naming functions

## Granular Permission System

### Permission Structure
The QTSP Rights Manager implements a two-tier permission system:

1. **Basic Trust**: QTSPs must first be added to the trusted list
2. **Claim-Specific Permissions**: Each QTSP can be granted permissions for specific claim types

### Example Permission Setup
```solidity
// Add QTSPs to trusted list
rightsManager.addTrustedQTSP(qtsp1);
rightsManager.addTrustedQTSP(qtsp2);
rightsManager.addTrustedQTSP(qtsp3);

// Grant specific permissions
// QTSP1 can manage OVER_18 and EU_CITIZEN claims
rightsManager.grantClaimPermission(qtsp1, ClaimsRegistry.OVER_18);
rightsManager.grantClaimPermission(qtsp1, ClaimsRegistry.EU_CITIZEN);

// QTSP2 can manage STUDENT and BUSINESS claims
rightsManager.grantClaimPermission(qtsp2, ClaimsRegistry.STUDENT);
rightsManager.grantClaimPermission(qtsp2, ClaimsRegistry.BUSINESS);

// QTSP3 can manage PROFESSIONAL claims only
rightsManager.grantClaimPermission(qtsp3, ClaimsRegistry.PROFESSIONAL);
```

## Token System Design

### Token Structure
Each claim type has its own token contract:
- **OVER_18 Token**: Represents age verification (18+)
- **EU_CITIZEN Token**: Represents EU citizenship
- **STUDENT Token**: Represents student status
- **BUSINESS Token**: Represents business verification
- **PROFESSIONAL Token**: Represents professional status

### Token Properties
- **Non-transferable**: Users cannot transfer tokens to others
- **QTSP-controlled**: Only authorized QTSPs can issue/revoke
- **ERC20 compliant**: Standard token interface
- **Claim-specific**: Each token represents one specific claim

## Workflow

### 1. System Setup
```solidity
// Deploy QTSP Rights Manager
QTSPRightsManager rightsManager = new QTSPRightsManager();

// Deploy claim tokens
ClaimToken over18Token = new ClaimToken("OVER_18");
ClaimToken euCitizenToken = new ClaimToken("EU_CITIZEN");

// Register tokens with restricted contract
restrictedContract.registerClaimToken(ClaimsRegistry.OVER_18, address(over18Token));
restrictedContract.registerClaimToken(ClaimsRegistry.EU_CITIZEN, address(euCitizenToken));

// Add trusted QTSPs
rightsManager.addTrustedQTSP(qtspAddress);

// Grant specific permissions
rightsManager.grantClaimPermission(qtspAddress, ClaimsRegistry.OVER_18);

// Authorize QTSPs in token contracts
over18Token.authorizeQTSP(qtspAddress);
```

### 2. Token Issuance with Permissions
```solidity
// QTSP issues tokens based on verified signature and permissions
bytes memory signature = createSignature(user, claim, qtspPrivateKey);
rightsManager.issueTokens(user, claim, signature, 1, tokenContractAddress);
```

### 3. Access Control
```solidity
// Check if user has required claim
bool hasClaim = rightsManager.hasClaim(user, claim, tokenContract);

// Verify signature and grant access
restrictedContract.accessAgeRestrictedService(user, signature);
```

## Key Features

### 1. Granular QTSP Permissions
- Each QTSP can be granted permissions for specific claim types
- QTSPs can only issue/revoke tokens for claims they're authorized for
- Flexible permission management with easy grant/revoke

### 2. Separate Token Contracts
- Each claim type has its own isolated token contract
- Independent token issuance and revocation
- Clear separation of concerns

### 3. Non-transferable Tokens
- Tokens cannot be transferred between users
- Prevents claim trading and fraud
- Maintains integrity of the identity system

### 4. Permission-Based Token Management
- Only authorized QTSPs can issue/revoke tokens
- Centralized trust management with granular control
- Signature verification with permission checks

## Usage Examples

### Granting Permissions
```solidity
// Grant single permission
rightsManager.grantClaimPermission(qtsp, ClaimsRegistry.OVER_18);

// Grant multiple permissions at once
bytes32[] memory claims = [ClaimsRegistry.OVER_18, ClaimsRegistry.EU_CITIZEN];
rightsManager.grantMultipleClaimPermissions(qtsp, claims);
```

### Checking Permissions
```solidity
// Check if QTSP has permission for specific claim
bool hasPermission = rightsManager.hasClaimPermission(qtsp, ClaimsRegistry.OVER_18);

// Get all claims a QTSP can manage
bytes32[] memory claims = rightsManager.getQTSPManagedClaims(qtsp);

// Get all QTSPs that can manage a specific claim
address[] memory qtspList = rightsManager.getClaimAuthorizedQTSPs(ClaimsRegistry.OVER_18);
```

### Issuing Tokens with Permissions
```solidity
// QTSP issues tokens (only works if they have permission)
bytes32 claim = ClaimsRegistry.OVER_18;
bytes memory signature = createSignature(user, claim, qtspPrivateKey);
rightsManager.issueTokens(user, claim, signature, 1, tokenContractAddress);
```

### Revoking Permissions
```solidity
// Revoke single permission
rightsManager.revokeClaimPermission(qtsp, ClaimsRegistry.OVER_18);

// Revoke multiple permissions
bytes32[] memory claims = [ClaimsRegistry.OVER_18, ClaimsRegistry.EU_CITIZEN];
rightsManager.revokeMultipleClaimPermissions(qtsp, claims);

// Remove QTSP entirely (revokes all permissions)
rightsManager.removeTrustedQTSP(qtsp);
```

## Deployment

### 1. Install Dependencies
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

### 2. Deploy System
```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy the token system with granular permissions
forge script script/DeployTokenSystem.s.sol --rpc-url your_rpc_url --broadcast
```

### 3. Setup QTSPs with Granular Permissions
```solidity
// Add trusted QTSPs
rightsManager.addTrustedQTSP(qtsp1);
rightsManager.addTrustedQTSP(qtsp2);

// Grant specific permissions
rightsManager.grantClaimPermission(qtsp1, ClaimsRegistry.OVER_18);
rightsManager.grantClaimPermission(qtsp2, ClaimsRegistry.STUDENT);

// Authorize QTSPs in token contracts
over18Token.authorizeQTSP(qtsp1);
studentToken.authorizeQTSP(qtsp2);
```

## Testing

### Run Tests
```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testQTSPPermissions

# Run with verbose output
forge test -vvv
```

### Test Coverage
The test suite covers:
- Granular QTSP permissions
- Token issuance with permission checks
- Token revocation with permission checks
- Permission granting and revoking
- Access control with permissions
- Multi-claim scenarios
- QTSP removal and permission cleanup

## Security Considerations

### 1. Granular Permission Control
- QTSPs can only manage claims they're authorized for
- Prevents unauthorized token issuance
- Centralized permission management

### 2. Token Transfer Prevention
- All transfer functions are overridden to revert
- Prevents claim trading and fraud
- Maintains system integrity

### 3. Signature Verification with Permissions
- ECDSA signature verification
- Permission checks before token operations
- Ensures claim authenticity and authorization

### 4. Access Control
- Claims-based access control
- Signature verification for service access
- Granular permission system

## Advantages of Granular Permission System

### 1. Security
- Fine-grained access control
- Reduced attack surface
- Principle of least privilege

### 2. Flexibility
- Different QTSPs can specialize in different claims
- Easy to add/remove permissions
- Scalable permission management

### 3. Compliance
- Clear audit trail of permissions
- Regulatory compliance support
- Transparent permission management

### 4. Operational Efficiency
- Specialized QTSPs for different claim types
- Reduced complexity for individual QTSPs
- Better resource allocation

## Permission Management Examples

### Example 1: Age Verification Specialist
```solidity
// QTSP specializing in age verification
rightsManager.grantClaimPermission(ageVerificationQTSP, ClaimsRegistry.OVER_18);
```

### Example 2: Educational Institution
```solidity
// University QTSP for student verification
rightsManager.grantClaimPermission(universityQTSP, ClaimsRegistry.STUDENT);
```

### Example 3: Government Agency
```solidity
// Government agency for citizenship verification
rightsManager.grantClaimPermission(governmentQTSP, ClaimsRegistry.EU_CITIZEN);
rightsManager.grantClaimPermission(governmentQTSP, ClaimsRegistry.OVER_18);
```

### Example 4: Business Verification Service
```solidity
// Business verification service
rightsManager.grantClaimPermission(businessVerifierQTSP, ClaimsRegistry.BUSINESS);
rightsManager.grantClaimPermission(businessVerifierQTSP, ClaimsRegistry.PROFESSIONAL);
```

## Comparison with Previous System

| Feature          | Previous System | Granular Permission System |
| ---------------- | --------------- | -------------------------- |
| Permission Model | All-or-nothing  | Granular claim-specific    |
| Security         | Basic trust     | Fine-grained control       |
| Scalability      | Limited         | Highly scalable            |
| Specialization   | Not supported   | QTSP specialization        |
| Compliance       | Basic           | Advanced audit trail       |

## Future Enhancements

### 1. Role-Based Permissions
```solidity
enum QTSPRole { VERIFIER, ISSUER, REVOKER }
mapping(address => mapping(bytes32 => QTSPRole)) public qtspRoles;
```

### 2. Time-Based Permissions
```solidity
mapping(address => mapping(bytes32 => uint256)) public permissionExpiry;
function grantTemporaryPermission(address qtsp, bytes32 claim, uint256 duration) external;
```

### 3. Hierarchical Permissions
```solidity
mapping(address => address) public qtspSupervisor;
function grantSupervisorPermission(address supervisor, address qtsp) external;
```

### 4. Permission Delegation
```solidity
mapping(address => mapping(address => bytes32[])) public delegatedPermissions;
function delegatePermission(address delegatee, bytes32 claim) external;
```

## Conclusion

This granular permission system provides a secure, flexible, and scalable approach to on-chain identity management. Each QTSP can specialize in specific claim types, reducing complexity and improving security. The system maintains the benefits of token-based identity while adding sophisticated permission controls that support real-world operational requirements. 