// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../script/helpers/HelperConfig.s.sol";
import "../../script/helpers/SharedStructs.s.sol";

contract ClaimsRegistryContractTest is Test {
    SharedStructs.NetworkConfig public config;
    ClaimsRegistryContract public claimsRegistry;
    ClaimToken public over18Token;
    ClaimToken public euCitizenToken;
    QTSPRightsManager public rightsManager;
    
    address public DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    
    bytes32 public constant OVER_18 = ClaimsRegistry.OVER_18;
    bytes32 public constant EU_CITIZEN = ClaimsRegistry.EU_CITIZEN;
    bytes32 public constant INVALID_CLAIM = keccak256("invalid:claim");
    
    event ClaimTokenRegistered(bytes32 indexed claim, address indexed tokenAddress);
    event ClaimTokenRemoved(bytes32 indexed claim, address indexed tokenAddress);
    
    function setUp() public {
        // Use your deployment script to get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getOrCreateNetworkConfig();

        rightsManager = config.proxies.rightsManager;
        claimsRegistry = config.proxies.claimsRegistry;
        over18Token = config.proxies.over18Token;
        euCitizenToken = config.proxies.euCitizenToken;
    }
    
    function testConstructor() public view {
        assertEq(claimsRegistry.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should be set correctly");
    }
    
    function testClaimTokenConstructor() public view {
        // Test that ClaimToken contracts are properly initialized
        assertEq(over18Token.claimType(), OVER_18, "OVER_18 token should have correct claim type");
        assertEq(euCitizenToken.claimType(), EU_CITIZEN, "EU_CITIZEN token should have correct claim type");
        assertEq(over18Token.getRightsManager(), address(rightsManager), "OVER_18 token should have correct rights manager");
        assertEq(euCitizenToken.getRightsManager(), address(rightsManager), "EU_CITIZEN token should have correct rights manager");
        assertEq(over18Token.owner(), DEFAULT_ANVIL_ADDRESS1, "OVER_18 token should have correct owner");
        assertEq(euCitizenToken.owner(), DEFAULT_ANVIL_ADDRESS1, "EU_CITIZEN token should have correct owner");
    }
    
    function testRegisterClaimToken() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // First remove the existing registration if it exists
        if (claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.removeClaimToken(OVER_18);
        }
        
        vm.expectEmit(true, true, false, false);
        emit ClaimTokenRegistered(OVER_18, address(over18Token));
        
        claimsRegistry.registerClaimToken(OVER_18, address(over18Token));
        
        assertEq(claimsRegistry.claimToToken(OVER_18), address(over18Token), "Claim should map to token");
        assertEq(claimsRegistry.tokenToClaim(address(over18Token)), OVER_18, "Token should map to claim");
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "Claim should have token");
        
        vm.stopPrank();
    }
    
    function testRegisterClaimToken_OnlyOwner() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableUnauthorizedAccount
        claimsRegistry.registerClaimToken(OVER_18, address(over18Token));
        
        vm.stopPrank();
    }
    
    function testRegisterClaimToken_InvalidClaim() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid claim type");
        claimsRegistry.registerClaimToken(INVALID_CLAIM, address(over18Token));
        
        vm.stopPrank();
    }
    
    function testRegisterClaimToken_InvalidAddress() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        vm.expectRevert("Invalid token address");
        claimsRegistry.registerClaimToken(OVER_18, address(0));
        
        vm.stopPrank();
    }
    
    function testRegisterClaimToken_AlreadyRegistered() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // The token is already registered from deployment, so this should fail
        vm.expectRevert("Claim token already registered");
        claimsRegistry.registerClaimToken(OVER_18, address(over18Token));
        
        vm.stopPrank();
    }
    
    function testRegisterClaimToken_TokenAlreadyRegistered() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // The token is already registered from deployment, so this should fail
        vm.expectRevert("Claim token already registered");
        claimsRegistry.registerClaimToken(EU_CITIZEN, address(over18Token));
        
        vm.stopPrank();
    }
    
    function testRemoveClaimToken() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // The token is already registered from deployment, so we can remove it directly
        vm.expectEmit(true, true, false, false);
        emit ClaimTokenRemoved(OVER_18, address(over18Token));
        
        claimsRegistry.removeClaimToken(OVER_18);
        
        assertEq(claimsRegistry.claimToToken(OVER_18), address(0), "Claim should not map to token");
        assertEq(claimsRegistry.tokenToClaim(address(over18Token)), bytes32(0), "Token should not map to claim");
        assertFalse(claimsRegistry.hasClaimToken(OVER_18), "Claim should not have token");
        
        vm.stopPrank();
    }
    
    function testRemoveClaimToken_OnlyOwner() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS2);
        
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableUnauthorizedAccount
        claimsRegistry.removeClaimToken(OVER_18);
        
        vm.stopPrank();
    }
    
    function testRemoveClaimToken_NotRegistered() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // First remove the existing registration if it exists
        if (claimsRegistry.hasClaimToken(OVER_18)) {
            claimsRegistry.removeClaimToken(OVER_18);
        }
        
        // Now try to remove a non-existent claim
        vm.expectRevert("Claim token not registered");
        claimsRegistry.removeClaimToken(OVER_18);
        
        vm.stopPrank();
    }
    
    function testGetClaimTokenAddress() public view{
        // The token is already registered from deployment, so we can test directly
        address tokenAddress = claimsRegistry.getClaimTokenAddress(OVER_18);
        assertEq(tokenAddress, address(over18Token), "Should return correct token address");
    }
    
    function testGetClaimForToken() public view{
        // The token is already registered from deployment, so we can test directly
        bytes32 claim = claimsRegistry.getClaimForToken(address(over18Token));
        assertEq(claim, OVER_18, "Should return correct claim");
    }

    function testHasClaimToken() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // Initially true because deployment already registered it
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "Should have token initially from deployment");
        
        // Remove token
        claimsRegistry.removeClaimToken(OVER_18);
        assertFalse(claimsRegistry.hasClaimToken(OVER_18), "Should not have token after removal");
        
        // Re-register token
        claimsRegistry.registerClaimToken(OVER_18, address(over18Token));
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "Should have token after re-registration");
        
        vm.stopPrank();
    }
    
    function testGetClaimName() public view{
        string memory over18Name = claimsRegistry.getClaimName(OVER_18);
        assertEq(over18Name, "OVER_18", "Should return correct claim name");
        
        string memory euCitizenName = claimsRegistry.getClaimName(EU_CITIZEN);
        assertEq(euCitizenName, "EU_CITIZEN", "Should return correct claim name");
    }
    
    function testTransferOwnership() public {
        address newOwner = address(0x456);
        
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        claimsRegistry.transferOwnership(newOwner);
        assertEq(claimsRegistry.owner(), newOwner, "Ownership should be transferred");
        vm.stopPrank();
    }
    
    function testTransferOwnership_OnlyOwner() public {
        address newOwner = address(0x456);
        
        vm.startPrank(DEFAULT_ANVIL_ADDRESS2);
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableUnauthorizedAccount
        claimsRegistry.transferOwnership(newOwner);
        vm.stopPrank();
    }
    
    function testTransferOwnership_InvalidAddress() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert(); // OpenZeppelin Ownable will revert with OwnableInvalidOwner
        claimsRegistry.transferOwnership(address(0));
        vm.stopPrank();
    }
    
    function testMultipleRegistrations() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // The tokens are already registered from deployment, so we can test the mappings directly
        // Verify mappings
        assertEq(claimsRegistry.claimToToken(OVER_18), address(over18Token));
        assertEq(claimsRegistry.claimToToken(EU_CITIZEN), address(euCitizenToken));
        assertEq(claimsRegistry.tokenToClaim(address(over18Token)), OVER_18);
        assertEq(claimsRegistry.tokenToClaim(address(euCitizenToken)), EU_CITIZEN);
        
        vm.stopPrank();
    }

    function testRemoveAndReaddClaim() public {
        vm.startPrank(DEFAULT_ANVIL_ADDRESS1);
        
        // Initially true because deployment already registered it
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "Should have token initially from deployment");
        
        // Remove
        claimsRegistry.removeClaimToken(OVER_18);
        assertFalse(claimsRegistry.hasClaimToken(OVER_18), "Should not have token after removal");
        
        // Re-add
        claimsRegistry.registerClaimToken(OVER_18, address(over18Token));
        assertTrue(claimsRegistry.hasClaimToken(OVER_18), "Should have token after re-adding");
        
        vm.stopPrank();
    }
}