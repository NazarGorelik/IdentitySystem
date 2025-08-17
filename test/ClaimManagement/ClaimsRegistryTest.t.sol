// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";

contract ClaimsRegistryTest is Test {
    // Test constants that match the library
    bytes32 public constant OVER_18 = keccak256("claim:age:over18");
    bytes32 public constant EU_CITIZEN = keccak256("claim:nationality:eu");
    bytes32 public constant INVALID_CLAIM = keccak256("invalid:claim");
    
    function testConstants_Over18() public pure {
        // Test that OVER_18 constant is correctly defined
        bytes32 expectedOver18 = keccak256("claim:age:over18");
        assertEq(ClaimsRegistry.OVER_18, expectedOver18, "OVER_18 constant should match expected hash");
    }
    
    function testConstants_EuCitizen() public pure {
        // Test that EU_CITIZEN constant is correctly defined
        bytes32 expectedEuCitizen = keccak256("claim:nationality:eu");
        assertEq(ClaimsRegistry.EU_CITIZEN, expectedEuCitizen, "EU_CITIZEN constant should match expected hash");
    }
    
    function testGetClaimName_Over18() public pure {
        // Test getClaimName for OVER_18 claim
        string memory claimName = ClaimsRegistry.getClaimName(OVER_18);
        assertEq(claimName, "OVER_18", "OVER_18 claim should return correct name");
    }
    
    function testGetClaimName_EuCitizen() public pure {
        // Test getClaimName for EU_CITIZEN claim
        string memory claimName = ClaimsRegistry.getClaimName(EU_CITIZEN);
        assertEq(claimName, "EU_CITIZEN", "EU_CITIZEN claim should return correct name");
    }
    
    function testGetClaimName_InvalidClaim() public pure {
        // Test getClaimName for invalid claim
        string memory claimName = ClaimsRegistry.getClaimName(INVALID_CLAIM);
        assertEq(claimName, "UNKNOWN_CLAIM", "Invalid claim should return UNKNOWN_CLAIM");
    }
    
    function testGetClaimName_ZeroHash() public pure {
        // Test getClaimName for zero hash
        string memory claimName = ClaimsRegistry.getClaimName(bytes32(0));
        assertEq(claimName, "UNKNOWN_CLAIM", "Zero hash should return UNKNOWN_CLAIM");
    }
    
    function testGetClaimName_ArbitraryHash() public pure {
        // Test getClaimName for arbitrary hash
        bytes32 arbitraryHash = keccak256("arbitrary:claim");
        string memory claimName = ClaimsRegistry.getClaimName(arbitraryHash);
        assertEq(claimName, "UNKNOWN_CLAIM", "Arbitrary hash should return UNKNOWN_CLAIM");
    }
    
    function testIsValidClaim_Over18() public pure {
        // Test isValidClaim for OVER_18 claim
        bool isValid = ClaimsRegistry.isValidClaim(OVER_18);
        assertTrue(isValid, "OVER_18 claim should be valid");
    }
    
    function testIsValidClaim_EuCitizen() public pure {
        // Test isValidClaim for EU_CITIZEN claim
        bool isValid = ClaimsRegistry.isValidClaim(EU_CITIZEN);
        assertTrue(isValid, "EU_CITIZEN claim should be valid");
    }
    
    function testIsValidClaim_InvalidClaim() public pure {
        // Test isValidClaim for invalid claim
        bool isValid = ClaimsRegistry.isValidClaim(INVALID_CLAIM);
        assertFalse(isValid, "Invalid claim should not be valid");
    }
    
    function testIsValidClaim_ZeroHash() public pure {
        // Test isValidClaim for zero hash
        bool isValid = ClaimsRegistry.isValidClaim(bytes32(0));
        assertFalse(isValid, "Zero hash should not be valid");
    }
    
    function testIsValidClaim_ArbitraryHash() public pure {
        // Test isValidClaim for arbitrary hash
        bytes32 arbitraryHash = keccak256("arbitrary:claim");
        bool isValid = ClaimsRegistry.isValidClaim(arbitraryHash);
        assertFalse(isValid, "Arbitrary hash should not be valid");
    }
    
    function testConstantsConsistency() public pure {
        // Test that constants are consistent with their string representations
        bytes32 over18FromString = keccak256("claim:age:over18");
        bytes32 euCitizenFromString = keccak256("claim:nationality:eu");
        
        assertEq(ClaimsRegistry.OVER_18, over18FromString, "OVER_18 constant should be consistent");
        assertEq(ClaimsRegistry.EU_CITIZEN, euCitizenFromString, "EU_CITIZEN constant should be consistent");
    }
    
    function testGetClaimNameConsistency() public pure {
        // Test that getClaimName returns consistent results for the same input
        string memory name1 = ClaimsRegistry.getClaimName(OVER_18);
        string memory name2 = ClaimsRegistry.getClaimName(OVER_18);
        assertEq(name1, name2, "getClaimName should return consistent results");
        
        name1 = ClaimsRegistry.getClaimName(EU_CITIZEN);
        name2 = ClaimsRegistry.getClaimName(EU_CITIZEN);
        assertEq(name1, name2, "getClaimName should return consistent results for EU_CITIZEN");
    }
    
    function testIsValidClaimConsistency() public pure {
        // Test that isValidClaim returns consistent results for the same input
        bool valid1 = ClaimsRegistry.isValidClaim(OVER_18);
        bool valid2 = ClaimsRegistry.isValidClaim(OVER_18);
        assertEq(valid1, valid2, "isValidClaim should return consistent results");
        
        valid1 = ClaimsRegistry.isValidClaim(INVALID_CLAIM);
        valid2 = ClaimsRegistry.isValidClaim(INVALID_CLAIM);
        assertEq(valid1, valid2, "isValidClaim should return consistent results for invalid claims");
    }
    
    function testAllValidClaims() public pure {
        // Test that all predefined claims are marked as valid
        assertTrue(ClaimsRegistry.isValidClaim(ClaimsRegistry.OVER_18), "OVER_18 should be valid");
        assertTrue(ClaimsRegistry.isValidClaim(ClaimsRegistry.EU_CITIZEN), "EU_CITIZEN should be valid");
    }
    
    function testGetClaimNameForAllValidClaims() public pure {
        // Test getClaimName for all valid claims
        string memory over18Name = ClaimsRegistry.getClaimName(ClaimsRegistry.OVER_18);
        string memory euCitizenName = ClaimsRegistry.getClaimName(ClaimsRegistry.EU_CITIZEN);
        
        assertEq(over18Name, "OVER_18", "OVER_18 should have correct name");
        assertEq(euCitizenName, "EU_CITIZEN", "EU_CITIZEN should have correct name");
    }
    
    function testHashCollisionResistance() public pure {
        // Test that different claim strings produce different hashes
        bytes32 over18Hash = keccak256("claim:age:over18");
        bytes32 euCitizenHash = keccak256("claim:nationality:eu");
        
        assertTrue(over18Hash != euCitizenHash, "Different claim strings should produce different hashes");
        assertTrue(over18Hash != bytes32(0), "OVER_18 hash should not be zero");
        assertTrue(euCitizenHash != bytes32(0), "EU_CITIZEN hash should not be zero");
    }
    
    function testLibraryFunctionsArePure() public pure {
        // Test that library functions are pure (don't modify state)
        // This is implicit in the view modifier, but we can verify the behavior
        
        // Call functions multiple times to ensure they're pure
        string memory name1 = ClaimsRegistry.getClaimName(OVER_18);
        string memory name2 = ClaimsRegistry.getClaimName(OVER_18);
        assertEq(name1, name2, "Pure function should return same result");
        
        bool valid1 = ClaimsRegistry.isValidClaim(OVER_18);
        bool valid2 = ClaimsRegistry.isValidClaim(OVER_18);
        assertEq(valid1, valid2, "Pure function should return same result");
    }
    
    function testEdgeCases() public pure {
        // Test edge cases and boundary conditions
        
        // Test with maximum bytes32 value
        bytes32 maxBytes32 = bytes32(type(uint256).max);
        string memory maxName = ClaimsRegistry.getClaimName(maxBytes32);
        bool maxValid = ClaimsRegistry.isValidClaim(maxBytes32);
        
        assertEq(maxName, "UNKNOWN_CLAIM", "Maximum bytes32 should return UNKNOWN_CLAIM");
        assertFalse(maxValid, "Maximum bytes32 should not be valid");
        
        // Test with minimum bytes32 value
        bytes32 minBytes32 = bytes32(0);
        string memory minName = ClaimsRegistry.getClaimName(minBytes32);
        bool minValid = ClaimsRegistry.isValidClaim(minBytes32);
        
        assertEq(minName, "UNKNOWN_CLAIM", "Minimum bytes32 should return UNKNOWN_CLAIM");
        assertFalse(minValid, "Minimum bytes32 should not be valid");
    }
}
