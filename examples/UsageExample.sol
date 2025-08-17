// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../src/ClaimManagement/ClaimsRegistry.sol";
import "../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../src/ClaimManagement/ClaimToken.sol";
import "../src/TrustSmartContract.sol";

/**
 * @title Usage Example
 * @dev Demonstrates how to use the on-chain identity system
 * @notice This is an example contract showing practical usage
 */
contract UsageExample {
    using ClaimsRegistry for bytes32;
    
    TrustSmartContract public trustContract;
    ClaimsRegistryContract public claimsRegistry;
    
    // Events
    event UserVerified(address indexed user, bytes32 indexed claim);
    event ServiceAccessed(address indexed user, string serviceName);
    
    constructor(address _trustContract, address _claimsRegistry) {
        trustContract = TrustSmartContract(_trustContract);
        claimsRegistry = ClaimsRegistryContract(_claimsRegistry);
    }
    
    /**
     * @dev Example: Verify a user's age and grant access to age-restricted content
     * @param user The user's address
     */
    function accessAgeRestrictedContent(address user) external {
        // 1. Get the token contract for OVER_18 claim
        address tokenContract = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.OVER_18);
        require(tokenContract != address(0), "Claim token not registered");
        
        // 2. Check if user has the required claim
        ClaimToken token = ClaimToken(tokenContract);
        require(token.hasValidClaim(user), "User must be over 18");
        
        // 3. Verify the stored signature is from a trusted QTSP
        require(
            trustContract.verifyStoredSignature(user, ClaimsRegistry.OVER_18, tokenContract),
            "Invalid signature from QTSP"
        );
        
        // 4. Grant access to the service
        emit UserVerified(user, ClaimsRegistry.OVER_18);
        emit ServiceAccessed(user, "Age Restricted Content");
        
        // 5. Perform the actual service logic here
        // ... (your service implementation)
    }
    
    /**
     * @dev Example: Access EU-only services
     * @param user The user's address
     */
    function accessEUService(address user) external {
        // 1. Get the token contract for EU_CITIZEN claim
        address tokenContract = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.EU_CITIZEN);
        require(tokenContract != address(0), "Claim token not registered");
        
        // 2. Check if user has the required claim
        ClaimToken token = ClaimToken(tokenContract);
        require(token.hasValidClaim(user), "User must be EU citizen");
        
        // 3. Verify the stored signature is from a trusted QTSP
        require(
            trustContract.verifyStoredSignature(user, ClaimsRegistry.EU_CITIZEN, tokenContract),
            "Invalid signature from QTSP"
        );
        
        emit UserVerified(user, ClaimsRegistry.EU_CITIZEN);
        emit ServiceAccessed(user, "EU Service");
    }
    
    /**
     * @dev Example: Multi-claim verification
     * @param user The user's address
     */
    function accessPremiumService(address user) external {
        // 1. Get token contracts for both claims
        address over18Token = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.OVER_18);
        address euCitizenToken = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.EU_CITIZEN);
        
        require(over18Token != address(0), "OVER_18 claim token not registered");
        require(euCitizenToken != address(0), "EU_CITIZEN claim token not registered");
        
        // 2. Check if user has both required claims
        ClaimToken over18 = ClaimToken(over18Token);
        ClaimToken euCitizen = ClaimToken(euCitizenToken);
        
        require(over18.hasValidClaim(user), "User must be over 18");
        require(euCitizen.hasValidClaim(user), "User must be EU citizen");
        
        // 3. Verify stored signatures
        require(
            trustContract.verifyStoredSignature(user, ClaimsRegistry.OVER_18, over18Token),
            "Invalid age verification signature"
        );
        
        require(
            trustContract.verifyStoredSignature(user, ClaimsRegistry.EU_CITIZEN, euCitizenToken),
            "Invalid EU citizenship signature"
        );
        
        emit UserVerified(user, ClaimsRegistry.OVER_18);
        emit UserVerified(user, ClaimsRegistry.EU_CITIZEN);
        emit ServiceAccessed(user, "Premium Service");
    }
    
    /**
     * @dev Get user's verification status for all claims
     * @param user The user's address
     * @return Array of boolean values indicating claim status
     */
    function getUserVerificationStatus(address user) external view returns (bool[2] memory) {
        address over18Token = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.OVER_18);
        address euCitizenToken = claimsRegistry.getClaimTokenAddress(ClaimsRegistry.EU_CITIZEN);
        
        bool over18Status = false;
        bool euCitizenStatus = false;
        
        if (over18Token != address(0)) {
            ClaimToken token = ClaimToken(over18Token);
            over18Status = token.hasValidClaim(user);
        }
        
        if (euCitizenToken != address(0)) {
            ClaimToken token = ClaimToken(euCitizenToken);
            euCitizenStatus = token.hasValidClaim(user);
        }
        
        return [over18Status, euCitizenStatus];
    }
    
    /**
     * @dev Check if a user can access a specific service
     * @param user The user's address
     * @param claim The required claim
     * @return True if user can access the service
     */
    function canAccessService(address user, bytes32 claim) external view returns (bool) {
        address tokenContract = claimsRegistry.getClaimTokenAddress(claim);
        if (tokenContract == address(0)) {
            return false;
        }
        
        ClaimToken token = ClaimToken(tokenContract);
        if (!token.hasValidClaim(user)) {
            return false;
        }
        
        // Also verify the stored signature
        return trustContract.verifyStoredSignature(user, claim, tokenContract);
    }
} 