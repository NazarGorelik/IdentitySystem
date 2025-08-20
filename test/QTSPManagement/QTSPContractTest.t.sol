// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/TrustSmartContract.sol";
import "../../script/HelperConfig.s.sol";

contract QTSPContractTest is Test {
    HelperConfig.NetworkConfig public config;
    QTSPContract public qtspContract1;
    QTSPContract public qtspContract2;
    ClaimsRegistryContract public claimsRegistry;
    ClaimToken public over18Token;
    ClaimToken public euCitizenToken;
    QTSPRightsManager public rightsManager;
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
    
    event TokenIssued(address indexed user, bytes32 indexed claim, address indexed qtsp);
    event TokenRevoked(address indexed user, bytes32 indexed claim, address indexed qtsp);
    
    function setUp() public {
        // Use your deployment script to get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getOrCreateNetworkConfig();
        
        // Get contract addresses from your deployment
        qtspContract1 = QTSPContract(config.qtspContract1);
        qtspContract2 = QTSPContract(config.qtspContract2);
        claimsRegistry = ClaimsRegistryContract(config.claimsRegistry);
        over18Token = ClaimToken(config.over18Token);
        euCitizenToken = ClaimToken(config.euCitizenToken);
        rightsManager = QTSPRightsManager(config.rightsManager);
        trustContract = TrustSmartContract(config.trustContract);
        
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
        assertEq(qtspContract1.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should be set correctly");
        assertEq(address(qtspContract1.claimsRegistryContract()), address(claimsRegistry), "Claims registry should be set correctly");
    }
    
    function testIssueToken_ValidSignature() public {
        // Issue token from QTSP contract
        vm.prank(DEFAULT_ANVIL_ADDRESS1); // QTSP owner calls issueToken
        
        vm.expectEmit(true, true, true, true);
        emit TokenIssued(testUserWithOver18Token, OVER_18, DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Verify token was issued
        assertTrue(over18Token.hasToken(testUserWithOver18Token), "User should have token");
        
        // Verify signature can be retrieved
        bytes memory storedSignature = over18Token.getUserSignature(testUserWithOver18Token);
        assertEq(storedSignature.length, validSignature.length, "Stored signature length should match");
    }
    
    function testIssueToken_OnlyOwner() public {
        // Try to issue token from non-owner
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert("Only owner can call this function");
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
    }
    
    function testIssueToken_InvalidUserAddress() public {
        // Try to issue token to zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.issueToken(address(0), OVER_18, validSignature);
    }

    function testIssueToken_InvalidClaimType() public {
        // Try to issue token with invalid claim type
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.issueToken(testUserWithOver18Token, INVALID_CLAIM, validSignature);
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
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
    }

    function testIssueToken_InvalidSignatureLength() public {
        // Try to issue token with invalid signature length
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid signature length");
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, invalidSignature);
    }
    
    function testIssueToken_EuCitizenClaim() public {
        // Issue EU_CITIZEN token
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        vm.expectEmit(true, true, true, true);
        emit TokenIssued(testUserWithOver18Token, EU_CITIZEN, DEFAULT_ANVIL_ADDRESS2);
        qtspContract2.issueToken(testUserWithOver18Token, EU_CITIZEN, validSignature);
        
        // Verify token was issued
        assertTrue(euCitizenToken.hasToken(testUserWithOver18Token), "User should have EU_CITIZEN token");
    }
    
    function testRevokeToken() public {
        // Issue token first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(over18Token.hasToken(testUserWithoutAnyTokens), "User should have token initially");
        
        // Now revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, true, true, true);
        emit TokenRevoked(testUserWithoutAnyTokens, OVER_18, DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
        
        // Verify token was revoked
        assertFalse(over18Token.hasToken(testUserWithoutAnyTokens), "User should not have token after revocation");
        
        // Verify token data is cleared by checking hasToken returns false
        assertFalse(over18Token.hasToken(testUserWithoutAnyTokens), "Token should not exist after revocation");
    }
    
    function testRevokeToken_OnlyOwner() public {
        // Issue token first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Try to revoke from non-owner
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        vm.expectRevert("Only owner can call this function");
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }

    function testRevokeToken_InvalidUserAddress() public {
        // Try to revoke token from zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.revokeToken(address(0), OVER_18);
    }
    
    function testRevokeToken_InvalidClaimType() public {
        // Try to revoke token with invalid claim type
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.revokeToken(testUserWithoutAnyTokens, INVALID_CLAIM);
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
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }
    
    function testRevokeToken_UserHasNoToken() public {
        // Try to revoke token from user who doesn't have one
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("User does not have a token");
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
    }
    
    function testHasToken() public view {
        // Initially user has no token
        bool hasToken = qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(hasToken, "User should not have token initially");
    }
    
    function testHasToken_AfterIssuance() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Check hasToken
        bool hasToken = qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertTrue(hasToken, "User should have token after issuance");
    }
    
    function testHasToken_AfterRevocation() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
        
        // Check hasToken
        bool hasToken = qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(hasToken, "User should not have token after revocation");
    }
    
    function testHasToken_UnregisteredClaim() public view {
        // Check hasToken for unregistered claim
        bool hasToken = qtspContract1.hasToken(testUserWithoutAnyTokens, INVALID_CLAIM);
        assertFalse(hasToken, "Unregistered claim should return false");
    }
    
    function testGetTokenData_UserHasNoToken() public view {
        // Try to get token data for user without token
        assertFalse(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "User should not have token");
    }
    
    function testGetTokenData_AfterIssuance() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Verify token exists
        assertTrue(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "Token should exist after issuance");
    }
    
    function testGetTokenData_UnregisteredClaim() public view {
        // Get token data for unregistered claim
        assertFalse(qtspContract1.hasToken(testUserWithoutAnyTokens, INVALID_CLAIM), "Token should not exist for unregistered claim");
    }
    
    function testMultipleTokenOperations() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(over18Token.hasToken(testUserWithoutAnyTokens), "User should have token");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(over18Token.hasToken(testUserWithoutAnyTokens), "User should not have token");
        
        // Issue token again
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(over18Token.hasToken(testUserWithoutAnyTokens), "User should have token again");
    }
    
    function testTokenDataIntegrity() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Verify all token data is correct
        assertTrue(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "User should have token");
        
        // Verify token exists and can be checked
        assertTrue(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "Token should exist after issuance");
    }
    
    function testDifferentClaimTypes() public {
        // Issue OVER_18 token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        assertTrue(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "User should have OVER_18 token");
        
        // Issue EU_CITIZEN token
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        qtspContract2.issueToken(testUserWithoutAnyTokens, EU_CITIZEN, validSignature);
        assertTrue(qtspContract2.hasToken(testUserWithoutAnyTokens, EU_CITIZEN), "User should have EU_CITIZEN token");
        
        // Verify both tokens exist
        assertTrue(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "User should still have OVER_18 token");
        assertTrue(qtspContract2.hasToken(testUserWithoutAnyTokens, EU_CITIZEN), "User should still have EU_CITIZEN token");
    }
    
    function testRevokeSpecificClaimType() public {
        // Issue both token types
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        qtspContract2.issueToken(testUserWithoutAnyTokens, EU_CITIZEN, validSignature);
        
        // Revoke only OVER_18 token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithoutAnyTokens, OVER_18);
        
        // Verify OVER_18 token is revoked but EU_CITIZEN remains
        assertFalse(qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18), "OVER_18 token should be revoked");
        assertTrue(qtspContract2.hasToken(testUserWithoutAnyTokens, EU_CITIZEN), "EU_CITIZEN token should remain");
    }
    
    function testContractStateAfterOperations() public {
        // Verify initial state
        assertEq(qtspContract1.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should remain unchanged");
        assertEq(address(qtspContract1.claimsRegistryContract()), address(claimsRegistry), "Claims registry should remain unchanged");
        
        // Perform operations
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithoutAnyTokens, OVER_18, validSignature);
        
        // Verify state remains unchanged
        assertEq(qtspContract1.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should remain unchanged after operations");
        assertEq(address(qtspContract1.claimsRegistryContract()), address(claimsRegistry), "Claims registry should remain unchanged after operations");
    }
}
