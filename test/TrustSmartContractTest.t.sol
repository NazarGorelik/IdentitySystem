// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/TrustSmartContract.sol";
import "../src/ClaimManagement/ClaimsRegistry.sol";
import "../src/ClaimManagement/ClaimToken.sol";
import "../src/QTSPManagement/QTSPRightsManager.sol";
import "../src/QTSPManagement/QTSPContract.sol";
import "../script/helpers/HelperConfig.s.sol";
import "../script/helpers/SharedStructs.s.sol";

contract TrustSmartContractTest is Test {
    SharedStructs.NetworkConfig public config;
    TrustSmartContract public trustContract;
    QTSPRightsManager public rightsManager;
    ClaimToken public claimToken;
    QTSPContract public qtspContract;
    QTSPContract public qtspContract2;
    
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
    
    event SignatureVerified(address indexed user, bytes32 indexed claim, address indexed qtspContract);
    event SignatureVerificationFailed(address indexed user, bytes32 indexed claim, address indexed qtspContract);
    
    function setUp() public {
        // Use your deployment script to get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getOrCreateAnvilNetworkConfig();
        
        // Get contract addresses from your deployment
        trustContract = TrustSmartContract(config.proxies.trustContract);
        rightsManager = QTSPRightsManager(config.proxies.rightsManager);
        claimToken = ClaimToken(config.proxies.over18Token);
        qtspContract = QTSPContract(config.proxies.qtspContract1);
        qtspContract2 = QTSPContract(config.proxies.qtspContract2);
    }
    
    function testVerifySignature_ValidStoredSignature() public {
        // Create a proper signature
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Sign with QTSP private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // First issue a token to store the signature
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, signature);
        
        // Now verify the signature using the new simplified function
        vm.expectEmit(true, true, true, true);
        emit SignatureVerified(testUserWithOver18Token, OVER_18, DEFAULT_ANVIL_ADDRESS1);
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, OVER_18);
        assertTrue(isValid);
    }
    
    function testVerifySignature_NoToken() public {
        // Try to verify signature for user without token
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithoutAnyTokens, OVER_18, address(0));
        
        bool isValid = trustContract.verifySignature(testUserWithoutAnyTokens, OVER_18);
        assertFalse(isValid);
    }
    
    function testVerifySignature_InvalidClaim() public {
        // Try to verify signature for a claim that doesn't exist
        bytes32 invalidClaim = keccak256("invalid:claim");
        
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithOver18Token, invalidClaim, address(0));
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, invalidClaim);
        assertFalse(isValid);
    }
    
    function testVerifySignature_UnauthorizedQTSPSignature() public {
        // Create signature with unauthorized QTSP
        uint256 unauthorizedPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Issue token with unauthorized signature
        vm.prank(DEFAULT_ANVIL_ADDRESS2); // This should fail since DEFAULT_ANVIL_ADDRESS2 is not authorized for OVER_18
        vm.expectRevert();
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, signature);
    }
    
    function testVerifySignature_WrongClaimType() public {
        // Create signature for EU_CITIZEN claim but try to verify for OVER_18
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, EU_CITIZEN));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY2, ethSignedMessageHash); // Use address2 for EU_CITIZEN
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Issue token for EU_CITIZEN using qtspContract2 (which is owned by DEFAULT_ANVIL_ADDRESS2)
        vm.prank(DEFAULT_ANVIL_ADDRESS2);
        qtspContract2.issueToken(testUserWithOver18Token, EU_CITIZEN, signature);
        
        // Try to verify for OVER_18 - should fail since user doesn't have OVER_18 token
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithOver18Token, OVER_18, address(0));
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, OVER_18);
        assertFalse(isValid);
    }
    
    function testRecoverSigner() public{
        // Create message hash
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Sign with known private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Recover signer
        address recoveredSigner = trustContract.recoverSigner(ethSignedMessageHash, signature);
        assertEq(recoveredSigner, DEFAULT_ANVIL_ADDRESS1, "Recovered signer should match");
    }
    
    function testContractInitialization() public view {
        // Test that contracts are properly initialized
        assertEq(trustContract.owner(), DEFAULT_ANVIL_ADDRESS1, "Trust contract owner should be set");
        assertEq(address(trustContract.rightsManager()), address(rightsManager), "Rights manager should be set");
        assertEq(rightsManager.owner(), DEFAULT_ANVIL_ADDRESS1, "Rights manager owner should be set");
        assertEq(claimToken.owner(), DEFAULT_ANVIL_ADDRESS1, "Claim token owner should be set");
        assertEq(qtspContract.owner(), DEFAULT_ANVIL_ADDRESS1, "QTSP contract owner should be set");
    }
    
    function testQTSPAuthorization() public view {
        // Test that QTSP contracts are properly authorized
        assertTrue(rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS1, OVER_18), "QTSP should be authorized for OVER_18");
        assertTrue(rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS2, EU_CITIZEN), "QTSP should be authorized for EU_CITIZEN");
    }
    
    function testClaimTokenRegistration() public view {
        // Test that claim tokens are properly registered
        assertTrue(config.proxies.claimsRegistry.hasClaimToken(OVER_18), "OVER_18 claim should be registered");
        assertTrue(config.proxies.claimsRegistry.hasClaimToken(EU_CITIZEN), "EU_CITIZEN claim should be registered");
        assertEq(config.proxies.claimsRegistry.getClaimTokenAddress(OVER_18), address(config.proxies.over18Token), "OVER_18 token address should match");
        assertEq(config.proxies.claimsRegistry.getClaimTokenAddress(EU_CITIZEN), address(config.proxies.euCitizenToken), "EU_CITIZEN token address should match");
    }
}