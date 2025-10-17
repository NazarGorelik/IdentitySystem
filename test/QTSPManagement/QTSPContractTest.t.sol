// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/TrustSmartContract.sol";
import "../../script/helpers/HelperConfig.s.sol";
import "../../script/helpers/SharedStructs.s.sol";

contract QTSPContractTest is Test {
    SharedStructs.NetworkConfig public config;
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
        config = helperConfig.getOrCreateAnvilNetworkConfig();
        
        // Get contract addresses from your deployment
        qtspContract1 = QTSPContract(config.proxies.qtspContract1);
        qtspContract2 = QTSPContract(config.proxies.qtspContract2);
        claimsRegistry = ClaimsRegistryContract(config.proxies.claimsRegistry);
        over18Token = ClaimToken(config.proxies.over18Token);
        euCitizenToken = ClaimToken(config.proxies.euCitizenToken);
        rightsManager = QTSPRightsManager(config.proxies.rightsManager);
        trustContract = TrustSmartContract(config.proxies.trustContract);
        
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
        
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableUnauthorizedAccount
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
    }
    
    function testIssueToken_InvalidUserAddress() public {
        // Try to issue token to zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.issueToken(address(0), OVER_18, validSignature);
    }
    
    function testIssueToken_InvalidClaim() public {
        // Try to issue token with invalid claim
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.issueToken(testUserWithOver18Token, INVALID_CLAIM, validSignature);
    }
    
    function testIssueToken_UnregisteredClaim() public {
        // Try to issue token for unregistered claim
        bytes32 unregisteredClaim = keccak256("unregistered:claim");
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.issueToken(testUserWithOver18Token, unregisteredClaim, validSignature);
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
        vm.expectEmit(true, true, true, true);
        emit TokenRevoked(testUserWithOver18Token, OVER_18, DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        
        // Verify token was revoked
        assertFalse(over18Token.hasToken(testUserWithOver18Token), "User should not have token anymore");
    }
    
    function testRevokeToken_OnlyOwner() public {
        // Try to revoke token from non-owner
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableUnauthorizedAccount
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
    }
    
    function testRevokeToken_InvalidUserAddress() public {
        // Try to revoke token from zero address
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid user address");
        qtspContract1.revokeToken(address(0), OVER_18);
    }
    
    function testRevokeToken_InvalidClaim() public {
        // Try to revoke token with invalid claim
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.revokeToken(testUserWithOver18Token, INVALID_CLAIM);
    }
    
    function testRevokeToken_UnregisteredClaim() public {
        // Try to revoke token for unregistered claim
        bytes32 unregisteredClaim = keccak256("unregistered:claim");
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        qtspContract1.revokeToken(testUserWithOver18Token, unregisteredClaim);
    }
    
    function testHasToken_ValidToken() public {
        // First issue a token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        // Check if user has token
        bool hasToken = qtspContract1.hasToken(testUserWithOver18Token, OVER_18);
        assertTrue(hasToken, "User should have token");
    }
    
    function testHasToken_NoToken() public view{
        // Check if user without token has token
        bool hasToken = qtspContract1.hasToken(testUserWithoutAnyTokens, OVER_18);
        assertFalse(hasToken, "User should not have token");
    }
    
    function testHasToken_InvalidClaim() public view {
        // Check if user has token for invalid claim - should return false, not revert
        bool hasToken = qtspContract1.hasToken(testUserWithOver18Token, INVALID_CLAIM);
        assertFalse(hasToken, "User should not have token for invalid claim");
    }
    
    function testHasToken_UnregisteredClaim() public view {
        // Check if user has token for unregistered claim - should return false, not revert
        bytes32 unregisteredClaim = keccak256("unregistered:claim");
        bool hasToken = qtspContract1.hasToken(testUserWithOver18Token, unregisteredClaim);
        assertFalse(hasToken, "User should not have token for unregistered claim");
    }
    
    function testContractInitialization() public view {
        // Test that contracts are properly initialized
        assertEq(qtspContract1.owner(), DEFAULT_ANVIL_ADDRESS1, "QTSP Contract 1 owner should be set");
        assertEq(qtspContract2.owner(), DEFAULT_ANVIL_ADDRESS2, "QTSP Contract 2 owner should be set");
        assertEq(address(qtspContract1.claimsRegistryContract()), address(claimsRegistry), "Claims registry should be set correctly");
        assertEq(address(qtspContract2.claimsRegistryContract()), address(claimsRegistry), "Claims registry should be set correctly");
    }
    
    function testQTSPAuthorization() public view {
        // Test that QTSP contracts are properly authorized
        assertTrue(rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS1, OVER_18), "QTSP1 should be authorized for OVER_18");
        assertTrue(rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS2, EU_CITIZEN), "QTSP2 should be authorized for EU_CITIZEN");
    }
    
    function testClaimTokenRegistration() public view {
        // Test that claim tokens are properly registered
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "OVER_18 claim should be registered");
        assertTrue(claimsRegistry.hasClaimToken(EU_CITIZEN), "EU_CITIZEN claim should be registered");
        assertEq(claimsRegistry.getClaimTokenAddress(OVER_18), address(over18Token), "OVER_18 token address should match");
        assertEq(claimsRegistry.getClaimTokenAddress(EU_CITIZEN), address(euCitizenToken), "EU_CITIZEN token address should match");
    }
    
    function testMultipleQTSPContracts() public {
        // Test that both QTSP contracts can issue tokens
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        qtspContract2.issueToken(testUserWithoutAnyTokens, EU_CITIZEN, validSignature);
        
        // Verify tokens were issued
        assertTrue(over18Token.hasToken(testUserWithOver18Token), "User should have OVER_18 token");
        assertTrue(euCitizenToken.hasToken(testUserWithoutAnyTokens), "User should have EU_CITIZEN token");
    }
    
    function testTokenRevocationAndReissuance() public {
        // Issue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(over18Token.hasToken(testUserWithOver18Token), "User should have token");
        
        // Revoke token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.revokeToken(testUserWithOver18Token, OVER_18);
        assertFalse(over18Token.hasToken(testUserWithOver18Token), "User should not have token");
        
        // Reissue token
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract1.issueToken(testUserWithOver18Token, OVER_18, validSignature);
        assertTrue(over18Token.hasToken(testUserWithOver18Token), "User should have token again");
    }
}
