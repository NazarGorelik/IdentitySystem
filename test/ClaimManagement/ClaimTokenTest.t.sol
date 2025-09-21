// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/TrustSmartContract.sol";
import "../../script/helpers/HelperConfig.s.sol";
import "../../script/helpers/SharedStructs.s.sol";

contract ClaimTokenTest is Test {
    SharedStructs.NetworkConfig public config;
    ClaimToken public claimToken;
    QTSPRightsManager public rightsManager;
    QTSPContract public qtspContract1;
    QTSPContract public qtspContract2;
    ClaimsRegistryContract public claimsRegistry;
    TrustSmartContract public trustContract;
    
    // owner of all contracts (except qtsp2)
    address public DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    // owner of qtsp2
    address public DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    // Add private keys for Anvil addresses
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address public testUserWithOver18Token = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    address public testUserWithoutAnyTokens = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    
    bytes32 public constant OVER_18 = ClaimsRegistry.OVER_18;
    bytes32 public constant EU_CITIZEN = ClaimsRegistry.EU_CITIZEN;
    bytes32 public constant INVALID_CLAIM = keccak256("invalid:claim");
    
    bytes public validSignature = new bytes(65);
    bytes public invalidSignature = new bytes(64);
    
    event TokenIssued(address indexed user, bytes32 claimType, bytes signature);
    event TokenRevoked(address indexed user);
    
    function setUp() public {
        // Use your deployment script to get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getOrCreateNetworkConfig();
        
        // Get contract addresses from your deployment
        trustContract = TrustSmartContract(config.proxies.trustContract);
        rightsManager = QTSPRightsManager(config.proxies.rightsManager);
        claimToken = ClaimToken(config.proxies.over18Token);
        qtspContract1 = QTSPContract(config.proxies.qtspContract1);
        qtspContract2 = QTSPContract(config.proxies.qtspContract2);
        claimsRegistry = ClaimsRegistryContract(config.proxies.claimsRegistry);
        
        // Setup valid signature (65 bytes)
        for (uint256 i = 0; i < 65; i++) {
            validSignature[i] = bytes1(uint8(i));
        }
        
        // Setup invalid signature (64 bytes)
        for (uint256 i = 0; i < 64; i++) {
            invalidSignature[i] = bytes1(uint8(i));
        }
    }
    
    function testConstructor() public view {
        assertEq(claimToken.claimType(), OVER_18, "Claim type should be set correctly");
        assertEq(claimToken.getRightsManager(), address(rightsManager), "Rights manager should be set correctly");
        assertEq(claimToken.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should be set correctly");
    }
    
    function testQTSPContractConstructor() public view {
        assertEq(qtspContract1.owner(), DEFAULT_ANVIL_ADDRESS1, "QTSP contract owner should be set correctly");
        assertEq(address(qtspContract1.claimsRegistryContract()), address(claimsRegistry), "Claims registry should be set correctly");
    }
    
    function testIssueToken_ValidSignature() public {
        // Issue token through the QTSP Contract (which is authorized)
        vm.prank(DEFAULT_ANVIL_ADDRESS1); // Use the owner of QTSP Contract
        
        vm.expectEmit(true, true, true, true);
        emit TokenIssued(testUserWithOver18Token, OVER_18, validSignature);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Verify token was issued
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token");
        
        // Verify signature can be retrieved
        bytes memory storedSignature = claimToken.getUserSignature(testUserWithOver18Token);
        assertEq(storedSignature.length, validSignature.length, "Stored signature length should match");
    }
    
    function testIssueToken_OnlyAuthorizedQTSP() public {
        // Try to issue token from unauthorized address (not the QTSP owner)
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert(); // Should revert because DEFAULT_ANVIL_ADDRESS2 is not the owner of QTSP Contract 1
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
    }
    
    function testIssueToken_InvalidUserAddress() public {
        // Try to issue token to zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.issueToken(address(0), OVER_18, validSignature);
    }
    
    function testIssueToken_InvalidSignatureLength() public {
        // Try to issue token with invalid signature length
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid signature length");
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, invalidSignature);
    }
    
    function testRevokeToken_ValidToken() public {
        // First issue a token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Now revoke it
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, true, false, false);
        emit TokenRevoked(testUserWithOver18Token);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        
        // Verify token was revoked
        assertFalse(claimToken.hasToken(testUserWithOver18Token), "User should not have token anymore");
    }
    
    function testRevokeToken_OnlyAuthorizedQTSP() public {
        // Try to revoke token from unauthorized contract
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert(); // Should revert because DEFAULT_ANVIL_ADDRESS2 is not the owner of QTSP Contract 1
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
    }
    
    function testRevokeToken_InvalidUserAddress() public {
        // Try to revoke token from zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.revokeToken(address(0), OVER_18);
    }
    
    function testRevokeToken_UserHasNoToken() public {
        // Try to revoke token from user who doesn't have one
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("User does not have a token");
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }
    
    function testHasToken_ValidToken() public {
        // First issue a token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Check if user has token
        bool hasToken = claimToken.hasToken(testUserWithOver18Token);
        assertTrue(hasToken, "User should have token");
    }
    
    function testHasToken_NoToken() public view{
        // Check if user without token has token
        bool hasToken = claimToken.hasToken(testUserWithoutAnyTokens);
        assertFalse(hasToken, "User should not have token");
    }
    
    function testGetUserSignature_ValidToken() public {
        // First issue a token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Get the stored signature
        bytes memory storedSignature = claimToken.getUserSignature(testUserWithOver18Token);
        assertEq(storedSignature.length, validSignature.length, "Stored signature length should match");
        
        // Verify signature content matches
        for (uint256 i = 0; i < validSignature.length; i++) {
            assertEq(storedSignature[i], validSignature[i], "Signature content should match");
        }
    }
    
    function testGetUserSignature_NoToken() public {
        // Try to get signature for user without token
        // This should revert since the user doesn't have a token
        vm.expectRevert("User does not have a token");
        claimToken.getUserSignature(testUserWithoutAnyTokens);
    }
    
    function testContractInitialization() public view {
        // Test that contracts are properly initialized
        assertEq(claimToken.claimType(), OVER_18, "Claim type should be set correctly");
        assertEq(claimToken.getRightsManager(), address(rightsManager), "Rights manager should be set correctly");
        assertEq(claimToken.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should be set correctly");
    }
    
    function testQTSPAuthorization() public view {
        // Test that QTSP contracts are properly authorized
        assertTrue(rightsManager.isQTSPContractAuthorizedForClaim(address(qtspContract1), OVER_18), "QTSP should be authorized for OVER_18");
        assertTrue(rightsManager.isQTSPContractAuthorizedForClaim(address(qtspContract2), EU_CITIZEN), "QTSP should be authorized for EU_CITIZEN");
    }
    
    function testClaimTokenRegistration() public view {
        // Test that claim tokens are properly registered
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "OVER_18 claim should be registered");
        assertTrue(claimsRegistry.hasClaimToken(EU_CITIZEN), "EU_CITIZEN claim should be registered");
        assertEq(claimsRegistry.getClaimTokenAddress(OVER_18), address(config.proxies.over18Token), "OVER_18 token address should match");
        assertEq(claimsRegistry.getClaimTokenAddress(EU_CITIZEN), address(config.proxies.euCitizenToken), "EU_CITIZEN token address should match");
    }
    
    function testMultipleTokenOperations() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        assertFalse(claimToken.hasToken(testUserWithOver18Token), "User should not have token");
        
        // Issue token again
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token again");
    }
    
    function testTokenDataIntegrity() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Verify all token data is correct
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token");
        assertEq(claimToken.claimType(), OVER_18, "Claim type should be correct");
        assertEq(claimToken.getRightsManager(), address(rightsManager), "Rights manager should be correct");
        
        // Verify signature can be retrieved and matches
        bytes memory storedSignature = claimToken.getUserSignature(testUserWithOver18Token);
        assertEq(storedSignature.length, validSignature.length, "Signature length should match");
    }
    
    function testDifferentClaimTypes() public view{
        // Test OVER_18 token
        assertEq(config.proxies.over18Token.claimType(), OVER_18, "OVER_18 token should have correct claim type");
        
        // Test EU_CITIZEN token
        assertEq(config.proxies.euCitizenToken.claimType(), EU_CITIZEN, "EU_CITIZEN token should have correct claim type");
    }
    
    function testTokenRevocationAndReissuance() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        assertFalse(claimToken.hasToken(testUserWithOver18Token), "User should not have token");
        
        // Reissue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token again");
    }
    
    function testIssueTokenPreventsDuplicateTokens() public {
        // Issue token first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Try to issue token again - should fail
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("User already has a token");
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // User should still have token
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should still have token");
    }
    
    function testCustomTokenIntegrationWithExistingFunctionality() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // All existing functionality should still work
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "hasToken should work");
        
        // Signature should still be retrievable
        bytes memory signature = claimToken.getUserSignature(testUserWithOver18Token);
        assertEq(signature.length, 65, "Signature should be retrievable");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        
        // All checks should reflect revocation
        assertFalse(claimToken.hasToken(testUserWithOver18Token), "hasToken should return false");
    }
}