// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title Claims Registry Library
 * @dev Standardized claim definitions for the on-chain identity system
 * @notice This library contains predefined claim types that can be used across the system
 */
library ClaimsRegistry {
    /**
     * @dev Claim for being over 18 years old
     * @notice This claim is used for age verification
     */
    bytes32 public constant OVER_18 = keccak256("claim:age:over18");
    
    /**
     * @dev Claim for being an EU citizen
     * @notice This claim is used for nationality verification
     */
    bytes32 public constant EU_CITIZEN = keccak256("claim:nationality:eu");
    
    /**
     * @dev Get claim name as string for a given claim hash
     * @param claimHash The hash of the claim
     * @return The name of the claim as a string
     */
    function getClaimName(bytes32 claimHash) public pure returns (string memory) {
        if (claimHash == OVER_18) return "OVER_18";
        if (claimHash == EU_CITIZEN) return "EU_CITIZEN";
        return "UNKNOWN_CLAIM";
    }
    
    /**
     * @dev Check if a claim hash is a valid predefined claim
     * @param claimHash The hash of the claim to check
     * @return True if the claim is valid, false otherwise
     */
    function isValidClaim(bytes32 claimHash) public pure returns (bool) {
        return claimHash == OVER_18 ||
               claimHash == EU_CITIZEN;
    }
}