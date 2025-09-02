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
        config = helperConfig.getOrCreateNetworkConfig();
        
        // Get contract addresses from your deployment
        trustContract = TrustSmartContract(config.proxies.trustContract);
        rightsManager = QTSPRightsManager(config.proxies.rightsManager);
        claimToken = ClaimToken(config.proxies.over18Token);
        qtspContract = QTSPContract(config.proxies.qtspContract1);
    }
    
    function testVerifySignature_ValidSignature() public {
        // Create message hash
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Sign with QTSP private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verify signature
        vm.expectEmit(true, true, true, true);
        emit SignatureVerified(testUserWithOver18Token, OVER_18, DEFAULT_ANVIL_ADDRESS1);
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, OVER_18, signature);
        assertTrue(isValid);
    }
    
    function testVerifySignature_InvalidSignature() public {
        // Create invalid signature (wrong private key)
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        uint256 wrongPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verify signature should fail
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithOver18Token, OVER_18, vm.addr(wrongPrivateKey));
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, OVER_18, signature);
        assertFalse(isValid, "Signature should be invalid");
    }
    
    function testVerifySignature_UnauthorizedQTSP() public {
        // Create signature with unauthorized QTSP
        address unauthorizedQTSP = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint256 unauthorizedPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verify signature should fail due to unauthorized QTSP
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithOver18Token, OVER_18, unauthorizedQTSP);
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, OVER_18, signature);
        assertFalse(isValid);
    }
    
    function testVerifySignature_WrongClaim() public {
        // Create signature for wrong claim
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, EU_CITIZEN));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verify signature should fail due to wrong claim
        vm.expectEmit(true, true, true, true);
        emit SignatureVerificationFailed(testUserWithOver18Token, EU_CITIZEN, DEFAULT_ANVIL_ADDRESS1);
        
        bool isValid = trustContract.verifySignature(testUserWithOver18Token, EU_CITIZEN, signature);
        assertFalse(isValid);
    }
    
    function testVerifySignature_InvalidSignatureLength() public {
        // Create invalid signature length
        bytes memory invalidSignature = new bytes(64);
        
        vm.expectRevert("Invalid signature length");
        trustContract.verifySignature(testUserWithOver18Token, OVER_18, invalidSignature);
    }
    
    function testVerifyStoredSignature_ValidSignature() public {
        // Create a proper signature
        bytes32 messageHash = keccak256(abi.encodePacked(testUserWithOver18Token, OVER_18));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Sign with QTSP private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEFAULT_ANVIL_PRIVATE_KEY1, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // First issue a token to store the signature
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        qtspContract.issueToken(testUserWithOver18Token, OVER_18, signature);
        
        // Now verify the stored signature
        bool isValid = trustContract.verifyStoredSignature(testUserWithOver18Token, OVER_18, address(claimToken));
        assertTrue(isValid);
    }
    
    function testVerifyStoredSignature_NoToken() public {
        // Try to verify stored signature for user without token
        bool isValid = trustContract.verifyStoredSignature(testUserWithoutAnyTokens, OVER_18, address(claimToken));
        assertFalse(isValid);
    }
    
    function testVerifyStoredSignature_InvalidTokenContract() public {
        vm.expectRevert("Invalid token contract address");
        trustContract.verifyStoredSignature(testUserWithOver18Token, OVER_18, address(0));
    }
    
    function testRecoverSigner() public view{
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
    
    function testRecoverSigner_InvalidSignatureLength() public {
        bytes memory invalidSignature = new bytes(64);
        
        vm.expectRevert("Invalid signature length");
        trustContract.recoverSigner(bytes32(0), invalidSignature);
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