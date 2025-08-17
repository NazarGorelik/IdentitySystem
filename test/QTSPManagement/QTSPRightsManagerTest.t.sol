// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/TrustSmartContract.sol";
import "../../script/HelperConfig.s.sol";

contract QTSPRightsManagerTest is Test {
    HelperConfig.NetworkConfig public config;
    QTSPRightsManager public rightsManager;
    ClaimsRegistryContract public claimsRegistry;
    TrustSmartContract public trustContract;
    QTSPContract public qtspContract1;
    QTSPContract public qtspContract2;
    ClaimToken public over18Token;
    ClaimToken public euCitizenToken;
    
    // Test addresses
    address public DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public testUser1 = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    address public testUser2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address public unauthorizedUser = 0x1234567890123456789012345678901234567890;
    
    // Claim types
    bytes32 public constant OVER_18 = ClaimsRegistry.OVER_18;
    bytes32 public constant EU_CITIZEN = ClaimsRegistry.EU_CITIZEN;
    
    // Events
    event QTSPContractAddedToClaim(address indexed qtspContract, bytes32 indexed claim);
    event QTSPContractRemovedFromClaim(address indexed qtspContract, bytes32 indexed claim);
    event QTSPContractTrusted(address indexed qtspContract);
    event QTSPContractUntrusted(address indexed qtspContract);
    
    function setUp() public {
        // Use HelperConfig for deployment
        HelperConfig helperConfig = new HelperConfig();
        config = helperConfig.getOrCreateNetworkConfig();
        
        // Get contract addresses from deployment
        rightsManager = QTSPRightsManager(config.rightsManager);
        claimsRegistry = ClaimsRegistryContract(config.claimsRegistry);
        trustContract = TrustSmartContract(config.trustContract);
        qtspContract1 = QTSPContract(config.qtspContract1);
        qtspContract2 = QTSPContract(config.qtspContract2);
        over18Token = ClaimToken(config.over18Token);
        euCitizenToken = ClaimToken(config.euCitizenToken);
    }
    
    // Test constructor and initial state
    function testConstructor() public view {
        assertEq(rightsManager.owner(), DEFAULT_ANVIL_ADDRESS1, "Owner should be set correctly");
    }
    
    // Test addTrustedQTSPContract function
    function testAddTrustedQTSPContract() public {
        address newQTSP = address(0x123);
        address newQTSOwner = address(0x456);
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, false, false, false);
        emit QTSPContractTrusted(newQTSP);
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
        
        assertTrue(rightsManager.trustedQTSPContracts(newQTSP), "QTSP should be trusted");
        assertEq(rightsManager.qtspOwnerToContract(newQTSOwner), newQTSP, "Owner mapping should be set");
        assertEq(rightsManager.qtspContractToOwner(newQTSP), newQTSOwner, "Contract mapping should be set");
        
        address[] memory trustedList = rightsManager.getTrustedQTSPContracts();
        bool found = false;
        for (uint256 i = 0; i < trustedList.length; i++) {
            if (trustedList[i] == newQTSP) {
                found = true;
                break;
            }
        }
        assertTrue(found, "QTSP should be in trusted list");
    }
    
    function testAddTrustedQTSPContract_OnlyOwner() public {
        address newQTSP = address(0x123);
        address newQTSOwner = address(0x456);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can call this function");
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
    }
    
    function testAddTrustedQTSPContract_InvalidAddress() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid QTSP Contract address");
        rightsManager.addTrustedQTSPContract(address(0), address(0x456));
    }
    
    function testAddTrustedQTSPContract_InvalidOwner() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid QTSP Contract owner address");
        rightsManager.addTrustedQTSPContract(address(0x123), address(0));
    }
    
    function testAddTrustedQTSPContract_AlreadyTrusted() public {
        address newQTSP = address(0x123);
        address newQTSOwner = address(0x456);
        
        // Add first time
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
        
        // Try to add again
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("QTSP Contract already trusted");
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
    }
    
    // Test removeTrustedQTSPContract function
    function testRemoveTrustedQTSPContract() public {
        address newQTSP = address(0x123);
        address newQTSOwner = address(0x456);
        
        // Add QTSP first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
        
        // Remove QTSP
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, false, false, false);
        emit QTSPContractUntrusted(newQTSP);
        rightsManager.removeTrustedQTSPContract(newQTSP);
        
        assertFalse(rightsManager.trustedQTSPContracts(newQTSP), "QTSP should not be trusted");
        
        address[] memory trustedList = rightsManager.getTrustedQTSPContracts();
        bool found = false;
        for (uint256 i = 0; i < trustedList.length; i++) {
            if (trustedList[i] == newQTSP) {
                found = true;
                break;
            }
        }
        assertFalse(found, "QTSP should not be in trusted list");
    }
    
    function testRemoveTrustedQTSPContract_OnlyOwner() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can call this function");
        rightsManager.removeTrustedQTSPContract(address(qtspContract1));
    }
    
    function testRemoveTrustedQTSPContract_NotTrusted() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("QTSP Contract not trusted");
        rightsManager.removeTrustedQTSPContract(address(0x123));
    }
    
    // Test addQTSPContractToClaim function
    function testAddQTSPContractToClaim() public {
        address newQTSP = address(0x123);
        address newQTSOwner = address(0x456);
        
        // Add QTSP to trusted list first
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        rightsManager.addTrustedQTSPContract(newQTSP, newQTSOwner);
        
        // Add QTSP to claim
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, true, false, false);
        emit QTSPContractAddedToClaim(newQTSP, OVER_18);
        rightsManager.addQTSPContractToClaim(newQTSP, OVER_18);
        
        assertTrue(rightsManager.isQTSPContractAuthorizedForClaim(newQTSP, OVER_18), "QTSP should be authorized for claim");
        
        address[] memory authorizedQTSPs = rightsManager.getClaimAuthorizedQTSPContracts(OVER_18);
        bool found = false;
        for (uint256 i = 0; i < authorizedQTSPs.length; i++) {
            if (authorizedQTSPs[i] == newQTSP) {
                found = true;
                break;
            }
        }
        assertTrue(found, "QTSP should be in authorized list for claim");
        
        bytes32[] memory managedClaims = rightsManager.getQTSPContractManagedClaims(newQTSP);
        bool claimFound = false;
        for (uint256 i = 0; i < managedClaims.length; i++) {
            if (managedClaims[i] == OVER_18) {
                claimFound = true;
                break;
            }
        }
        assertTrue(claimFound, "Claim should be in managed claims list");
    }
    
    function testAddQTSPContractToClaim_OnlyOwner() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can call this function");
        rightsManager.addQTSPContractToClaim(address(qtspContract1), OVER_18);
    }
    
    function testAddQTSPContractToClaim_InvalidAddress() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid QTSP Contract address");
        rightsManager.addQTSPContractToClaim(address(0), OVER_18);
    }
    
    function testAddQTSPContractToClaim_InvalidClaim() public {
        bytes32 invalidClaim = keccak256("INVALID_CLAIM");
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid claim type");
        rightsManager.addQTSPContractToClaim(address(qtspContract1), invalidClaim);
    }
    
    function testAddQTSPContractToClaim_NotTrusted() public {
        address untrustedQTSP = address(0x123);
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("QTSP Contract must be trusted first");
        rightsManager.addQTSPContractToClaim(untrustedQTSP, OVER_18);
    }
    
    function testAddQTSPContractToClaim_AlreadyAuthorized() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("QTSP Contract already authorized for this claim");
        rightsManager.addQTSPContractToClaim(address(qtspContract1), OVER_18);
    }
    
    // Test removeQTSPContractFromClaim function
    function testRemoveQTSPContractFromClaim() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectEmit(true, true, false, false);
        emit QTSPContractRemovedFromClaim(address(qtspContract1), OVER_18);
        rightsManager.removeQTSPContractFromClaim(address(qtspContract1), OVER_18);
        
        assertFalse(rightsManager.isQTSPContractAuthorizedForClaim(address(qtspContract1), OVER_18), "QTSP should not be authorized for claim");
        
        address[] memory authorizedQTSPs = rightsManager.getClaimAuthorizedQTSPContracts(OVER_18);
        bool found = false;
        for (uint256 i = 0; i < authorizedQTSPs.length; i++) {
            if (authorizedQTSPs[i] == address(qtspContract1)) {
                found = true;
                break;
            }
        }
        assertFalse(found, "QTSP should not be in authorized list for claim");
    }
    
    function testRemoveQTSPContractFromClaim_OnlyOwner() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can call this function");
        rightsManager.removeQTSPContractFromClaim(address(qtspContract1), OVER_18);
    }
    
    function testRemoveQTSPContractFromClaim_InvalidClaim() public {
        bytes32 invalidClaim = keccak256("INVALID_CLAIM");
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid claim type");
        rightsManager.removeQTSPContractFromClaim(address(qtspContract1), invalidClaim);
    }
    
    // Test isQTSPContractOwnerAuthorizedForClaim function
    function testIsQTSPContractOwnerAuthorizedForClaim() public view {
        // Test with authorized owner
        bool isAuthorized = rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS1, OVER_18);
        assertTrue(isAuthorized, "QTSP owner should be authorized for OVER_18 claim");
        
        // Test with unauthorized owner
        bool isNotAuthorized = rightsManager.isQTSPContractOwnerAuthorizedForClaim(DEFAULT_ANVIL_ADDRESS1, EU_CITIZEN);
        assertFalse(isNotAuthorized, "QTSP owner should not be authorized for EU_CITIZEN claim");
        
        // Test with non-owner
        bool nonOwnerAuthorized = rightsManager.isQTSPContractOwnerAuthorizedForClaim(unauthorizedUser, OVER_18);
        assertFalse(nonOwnerAuthorized, "Non-owner should not be authorized");
    }
    
    // Test isQTSPContractAuthorizedForClaim function
    function testIsQTSPContractAuthorizedForClaim() public view {
        // Test with authorized contract
        bool isAuthorized = rightsManager.isQTSPContractAuthorizedForClaim(address(qtspContract1), OVER_18);
        assertTrue(isAuthorized, "QTSP contract should be authorized for OVER_18 claim");
        
        // Test with unauthorized contract
        bool isNotAuthorized = rightsManager.isQTSPContractAuthorizedForClaim(address(qtspContract1), EU_CITIZEN);
        assertFalse(isNotAuthorized, "QTSP contract should not be authorized for EU_CITIZEN claim");
        
        // Test with untrusted contract
        bool untrustedAuthorized = rightsManager.isQTSPContractAuthorizedForClaim(unauthorizedUser, OVER_18);
        assertFalse(untrustedAuthorized, "Untrusted contract should not be authorized");
    }
    
    // Test getClaimAuthorizedQTSPContracts function
    function testGetClaimAuthorizedQTSPContracts() public view {
        address[] memory authorizedQTSPs = rightsManager.getClaimAuthorizedQTSPContracts(OVER_18);
        
        bool qtsp1Found = false;
        for (uint256 i = 0; i < authorizedQTSPs.length; i++) {
            if (authorizedQTSPs[i] == address(qtspContract1)) {
                qtsp1Found = true;
                break;
            }
        }
        assertTrue(qtsp1Found, "QTSP1 should be in authorized list for OVER_18 claim");
        
        address[] memory euAuthorizedQTSPs = rightsManager.getClaimAuthorizedQTSPContracts(EU_CITIZEN);
        bool qtsp2Found = false;
        for (uint256 i = 0; i < euAuthorizedQTSPs.length; i++) {
            if (euAuthorizedQTSPs[i] == address(qtspContract2)) {
                qtsp2Found = true;
                break;
            }
        }
        assertTrue(qtsp2Found, "QTSP2 should be in authorized list for EU_CITIZEN claim");
    }
    
    // Test getQTSPContractManagedClaims function
    function testGetQTSPContractManagedClaims() public view {
        bytes32[] memory qtsp1Claims = rightsManager.getQTSPContractManagedClaims(address(qtspContract1));
        
        bool over18Found = false;
        for (uint256 i = 0; i < qtsp1Claims.length; i++) {
            if (qtsp1Claims[i] == OVER_18) {
                over18Found = true;
                break;
            }
        }
        assertTrue(over18Found, "OVER_18 claim should be in QTSP1 managed claims");
        
        bytes32[] memory qtsp2Claims = rightsManager.getQTSPContractManagedClaims(address(qtspContract2));
        bool euCitizenFound = false;
        for (uint256 i = 0; i < qtsp2Claims.length; i++) {
            if (qtsp2Claims[i] == EU_CITIZEN) {
                euCitizenFound = true;
                break;
            }
        }
        assertTrue(euCitizenFound, "EU_CITIZEN claim should be in QTSP2 managed claims");
    }
    
    // Test getTrustedQTSPContracts function
    function testGetTrustedQTSPContracts() public view {
        address[] memory trustedQTSPs = rightsManager.getTrustedQTSPContracts();
        
        bool qtsp1Found = false;
        bool qtsp2Found = false;
        for (uint256 i = 0; i < trustedQTSPs.length; i++) {
            if (trustedQTSPs[i] == address(qtspContract1)) {
                qtsp1Found = true;
            }
            if (trustedQTSPs[i] == address(qtspContract2)) {
                qtsp2Found = true;
            }
        }
        assertTrue(qtsp1Found, "QTSP1 should be in trusted list");
        assertTrue(qtsp2Found, "QTSP2 should be in trusted list");
    }
    
    // Test getQTSPContractForOwner function
    function testGetQTSPContractForOwner() public view {
        address qtspContract = rightsManager.getQTSPContractForOwner(DEFAULT_ANVIL_ADDRESS1);
        assertEq(qtspContract, address(qtspContract1), "Should return correct QTSP contract for owner");
        
        address nonOwnerContract = rightsManager.getQTSPContractForOwner(unauthorizedUser);
        assertEq(nonOwnerContract, address(0), "Should return address(0) for non-owner");
    }
    
    // Test getQTSPContractOwner function
    function testGetQTSPContractOwner() public view {
        address owner = rightsManager.getQTSPContractOwner(address(qtspContract1));
        assertEq(owner, DEFAULT_ANVIL_ADDRESS1, "Should return correct owner for QTSP contract");
        
        address nonContractOwner = rightsManager.getQTSPContractOwner(unauthorizedUser);
        assertEq(nonContractOwner, address(0), "Should return address(0) for non-contract");
    }
    
    // Test isQTSPContractOwner function
    function testIsQTSPContractOwner() public view {
        bool isOwner = rightsManager.isQTSPContractOwner(DEFAULT_ANVIL_ADDRESS1);
        assertTrue(isOwner, "Should identify QTSP contract owner");
        
        bool isNotOwner = rightsManager.isQTSPContractOwner(unauthorizedUser);
        assertFalse(isNotOwner, "Should not identify non-owner as QTSP contract owner");
    }
    
    // Test transferOwnership function
    function testTransferOwnership() public {
        address newOwner = address(0x789);
        
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        rightsManager.transferOwnership(newOwner);
        
        assertEq(rightsManager.owner(), newOwner, "Ownership should be transferred");
    }
    
    function testTransferOwnership_OnlyOwner() public {
        address newOwner = address(0x789);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("Only owner can call this function");
        rightsManager.transferOwnership(newOwner);
    }
    
    function testTransferOwnership_InvalidAddress() public {
        vm.prank(DEFAULT_ANVIL_ADDRESS1);
        vm.expectRevert("Invalid new owner address");
        rightsManager.transferOwnership(address(0));
    }
    
    // Test integration with ClaimsRegistry
    function testIntegrationWithClaimsRegistry() public pure {
        // Test that the contract can access ClaimsRegistry functions
        assertTrue(ClaimsRegistry.isValidClaim(OVER_18), "OVER_18 should be valid claim");
        assertTrue(ClaimsRegistry.isValidClaim(EU_CITIZEN), "EU_CITIZEN should be valid claim");
        
        bytes32 invalidClaim = keccak256("INVALID_CLAIM");
        assertFalse(ClaimsRegistry.isValidClaim(invalidClaim), "Invalid claim should not be valid");
    }
}
