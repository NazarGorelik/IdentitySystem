// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/TrustSmartContract.sol";
import "../../script/HelperConfig.s.sol";

contract ClaimTokenTest is Test {
    HelperConfig.NetworkConfig public config;
    ClaimToken public claimToken;
    QTSPRightsManager public rightsManager;
    QTSPContract public qtspContract;
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
        trustContract = TrustSmartContract(config.trustContract);
        rightsManager = QTSPRightsManager(config.rightsManager);
        claimToken = ClaimToken(config.over18Token);
        qtspContract = QTSPContract(config.qtspContract1);
        claimsRegistry = ClaimsRegistryContract(config.claimsRegistry);
        
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
        assertEq(qtspContract.owner(), DEFAULT_ANVIL_ADDRESS1, "QTSP contract owner should be set correctly");
        assertEq(address(qtspContract.claimsRegistryContract()), address(claimsRegistry), "Claims registry should be set correctly");
    }
    
    function testConstructor_InvalidClaimType() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        new ClaimToken(INVALID_CLAIM, address(rightsManager));
        
        vm.stopPrank();
    }
    
    function testConstructor_InvalidRightsManager() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid rights manager address");
        new ClaimToken(OVER_18, address(0));
        
        vm.stopPrank();
    }
    
    function testIssueToken_ValidSignature() public {
        // First, register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Now issue token from QTSP contract
        vm.prank(DEFAULT_ANVIL_ADDRESS1); // QTSP owner calls issueToken
        
        vm.expectEmit(true, true, false, false);
        emit TokenIssued(testUserWithOver18Token, OVER_18, validSignature);
        
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Verify token was issued
        assertTrue(claimToken.hasToken(testUserWithOver18Token), "User should have token");
        
        // Verify signature retrieval
        bytes memory retrievedSignature = claimToken.getUserSignature(testUserWithOver18Token);
        assertEq(retrievedSignature.length, validSignature.length, "Retrieved signature length should match");
        
        // Verify claim type retrieval
        bytes32 retrievedClaimType = claimToken.getClaimType();
        assertEq(retrievedClaimType, OVER_18, "Retrieved claim type should match");
    }
    
    function testIssueToken_UnauthorizedQTSP() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            vm.prank(DEFAULT_ANVIL_ADDRESS1);
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to issue token from unauthorized QTSP contract
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        // remove qtsp from claim
        rightsManager.removeQTSPContractFromClaim(address(qtspContract), OVER_18);
        vm.expectRevert("Only authorized QTSP Contract can call this function");
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        vm.stopPrank();
    }

    function testIssueToken_UntrustedQTSP() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to issue token from untrusted QTSP contract
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        // remove qtsp contract from trusted list
        rightsManager.removeTrustedQTSPContract(address(qtspContract));
        vm.expectRevert("Only authorized QTSP Contract can call this function");
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        vm.stopPrank();
    }
    
    function testIssueToken_InvalidUserAddress() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to issue token to zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract.issueToken(address(0), OVER_18, validSignature);
    }

    function testIssueToken_InvalidClaimType() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to issue token with invalid claim type
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract.issueToken(testUserWithOver18Token, INVALID_CLAIM, validSignature);
    }
    
    function testIssueToken_ClaimTokenNotRegistered() public {
        // Remove the claim token if it's already registered
        if (claimsRegistry.hasClaimToken(OVER_18)) {
            vm.prank(DEFAULT_ANVIL_ADDRESS1);
            claimsRegistry.removeClaimToken(OVER_18);
        }
        
        // Try to issue token for unregistered claim
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Claim token not registered");
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, validSignature);
    }

    function testIssueToken_InvalidSignatureLength() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to issue token with invalid signature length
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid signature length");
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, invalidSignature);
    }
    
    function testRevokeToken() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Issue token first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithoutAnyTokens), "User should have token initially");
        
        // Now revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectEmit(true, true, false, false);
        emit TokenRevoked(testUserWithoutAnyTokens);
        
        qtspContract.revokeToken(testUserWithoutAnyTokens, OVER_18);
        
        // Verify token was revoked
        assertFalse(claimToken.hasToken(testUserWithoutAnyTokens), "User should not have token after revocation");
        
        // Verify token data is cleared by checking hasToken returns false
        assertFalse(claimToken.hasToken(testUserWithoutAnyTokens), "Token should not exist after revocation");
    }
    
    function testRevokeToken_UnauthorizedQTSP() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Issue token first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Try to revoke from unauthorized QTSP
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        rightsManager.removeQTSPContractFromClaim(address(qtspContract), OVER_18);
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Only authorized QTSP Contract can call this function");
        qtspContract.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }

    function testRevokeToken_InvalidUserAddress() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to revoke token from zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract.revokeToken(address(0), OVER_18);
    }
    
    function testRevokeToken_InvalidClaimType() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to revoke token with invalid claim type
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract.revokeToken(testUserWithoutAnyTokens, INVALID_CLAIM);
    }

    function testRevokeToken_ClaimTokenNotRegistered() public {
        // Remove the claim token if it's already registered
        if (claimsRegistry.hasClaimToken(OVER_18)) {
            vm.prank(DEFAULT_ANVIL_ADDRESS1);
            claimsRegistry.removeClaimToken(OVER_18);
        }
        
        // Try to revoke token for unregistered claim
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Claim token not registered");
        qtspContract.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }
    
    function testRevokeToken_UserHasNoToken() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Try to revoke token from user who doesn't have one
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("User does not have a token");
        qtspContract.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }
    
    function testHasToken() public view {
        // Initially user has no token
        assertFalse(claimToken.hasToken(testUserWithoutAnyTokens), "User should not have token initially");
    }
    
    function testGetTokenData_UserHasNoToken() public view{
        // Try to get token data for user without token
        assertFalse(claimToken.hasToken(testUserWithoutAnyTokens), "User should not have token");
    }
    
    function testGetUserSignature_UserHasNoToken() public {
        // Try to get signature for user without token
        vm.expectRevert("User does not have a token");
        claimToken.getUserSignature(testUserWithoutAnyTokens);
    }
    
    function testGetClaimType() public view {
        bytes32 claimType = claimToken.getClaimType();
        assertEq(claimType, OVER_18, "Should return correct claim type");
    }
    
    function testGetClaimName() public view {
        string memory claimName = claimToken.getClaimName();
        assertEq(claimName, "OVER_18", "Should return correct claim name");
    }
    
    function testGetRightsManager() public view {
        address rightsManagerAddress = claimToken.getRightsManager();
        assertEq(rightsManagerAddress, address(rightsManager), "Should return correct rights manager address");
    }
    
    function testTransferOwnership() public {
        address newOwner = address(0x456);
        
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        claimToken.transferOwnership(newOwner);
        assertEq(claimToken.owner(), newOwner, "Ownership should be transferred");
        vm.stopPrank();
    }
    
    function testTransferOwnership_OnlyOwner() public {
        address newOwner = address(0x456);
        
        vm.startPrank(DEFAULT_ANVIL_ADDRESS2);
        vm.expectRevert("Only owner can call this function");
        claimToken.transferOwnership(newOwner);
        vm.stopPrank();
    }
    
    function testTransferOwnership_InvalidAddress() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid new owner address");
        claimToken.transferOwnership(address(0));
        vm.stopPrank();
    }
    
    function testMultipleTokenOperations() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithoutAnyTokens), "User should have token");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.revokeToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(claimToken.hasToken(testUserWithoutAnyTokens), "User should not have token");
        
        // Issue token again
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(claimToken.hasToken(testUserWithoutAnyTokens), "User should have token again");
    }
    
    function testTokenDataIntegrity() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Verify all token data is correct
        assertTrue(claimToken.hasToken(testUserWithoutAnyTokens), "User should have token");
        
        // Verify individual getters return correct data
        bytes memory retrievedSignature = claimToken.getUserSignature(testUserWithoutAnyTokens);
        bytes32 retrievedClaimType = claimToken.getClaimType();
        
        assertEq(retrievedSignature.length, validSignature.length, "Signature lengths should match");
        assertEq(retrievedClaimType, OVER_18, "Claim types should match");
    }
    
    function testQTSPContractViewFunctions() public {
        // Register the claim token in the claims registry (if not already registered)
        if (!claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.registerClaimToken(OVER_18, address(claimToken));
        }
        
        // Test hasToken function
        bool hasToken = qtspContract.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(hasToken, "User should not have token initially");
        
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Test hasToken function again
        hasToken = qtspContract.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertTrue(hasToken, "User should have token after issuance");
        
        // Test that the token exists by checking hasToken
        assertTrue(qtspContract.hasToken(testUserWithoutAnyTokens, OVER_18), "Token should exist after issuance");
    }
}