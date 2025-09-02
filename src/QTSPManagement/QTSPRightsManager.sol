// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../ClaimManagement/ClaimsRegistry.sol";

/**
 * @title QTSP Rights Manager
 * @dev Manages permissions for QTSP Contracts to issue and revoke specific claim tokens
 * @notice This contract grants granular permissions to QTSP Contracts for managing specific claims
 *         and maintains the trust relationships between QTSP contracts and claim types
 */
contract QTSPRightsManager is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using ClaimsRegistry for bytes32;
    
    // Mapping: claim type => array of QTSP Contract addresses that can manage it
    mapping(bytes32 => address[]) public claimAuthorizedQTSPContracts;
    
    // Mapping: QTSP Contract address => array of claims they can manage
    mapping(address => bytes32[]) public qtspContractManagedClaims;
    
    // Mapping: QTSP Contract address => is trusted
    mapping(address => bool) public trustedQTSPContracts;

    // Mapping: QTSP Contract owner => QTSP Contract address
    mapping(address => address) public qtspOwnerToContract;
    
    // Mapping: QTSP Contract address => QTSP Contract owner
    mapping(address => address) public qtspContractToOwner;
    
    // Array to keep track of all trusted QTSP Contracts
    address[] public trustedQTSPContractList;
    
    // Events
    event QTSPContractAddedToClaim(address indexed qtspContract, bytes32 indexed claim);
    event QTSPContractRemovedFromClaim(address indexed qtspContract, bytes32 indexed claim);
    event QTSPContractTrusted(address indexed qtspContract);
    event QTSPContractUntrusted(address indexed qtspContract);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract
     * @param initialOwner The initial owner of the contract
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }
    
    /**
     * @dev Add a QTSP Contract to the trusted list
     * @param qtspContract The address of the QTSP Contract to add
     * @param qtspOwner The owner of the QTSP Contract
     * @notice Establishes trust relationship and stores owner-contract mapping
     */
    function addTrustedQTSPContract(address qtspContract, address qtspOwner) external onlyOwner {
        require(qtspContract != address(0), "Invalid QTSP Contract address");
        require(qtspOwner != address(0), "Invalid QTSP Contract owner address");
        require(!trustedQTSPContracts[qtspContract], "QTSP Contract already trusted");
        
        trustedQTSPContracts[qtspContract] = true;
        trustedQTSPContractList.push(qtspContract);
        
        // Store the owner-contract relationship
        qtspOwnerToContract[qtspOwner] = qtspContract;
        qtspContractToOwner[qtspContract] = qtspOwner;
        
        emit QTSPContractTrusted(qtspContract);
    }
    
    /**
     * @dev Remove a QTSP Contract from the trusted list
     * @param qtspContract The address of the QTSP Contract to remove
     * @notice Removes trust status and cleans up all associated permissions
     */
    function removeTrustedQTSPContract(address qtspContract) external onlyOwner {
        require(trustedQTSPContracts[qtspContract], "QTSP Contract not trusted");
        
        trustedQTSPContracts[qtspContract] = false;
        
        // Remove from trustedQTSPContractList using swap-and-pop for gas efficiency
        for (uint256 i = 0; i < trustedQTSPContractList.length; i++) {
            if (trustedQTSPContractList[i] == qtspContract) {
                trustedQTSPContractList[i] = trustedQTSPContractList[trustedQTSPContractList.length - 1];
                trustedQTSPContractList.pop();
                break;
            }
        }
        
        // Remove all permissions for this QTSP Contract
        bytes32[] memory claims = qtspContractManagedClaims[qtspContract];
        for (uint256 i = 0; i < claims.length; i++) {
            removeQTSPContractFromClaim(qtspContract, claims[i]);
        }
        
        emit QTSPContractUntrusted(qtspContract);
    }
    
    /**
     * @dev Add a QTSP Contract to the authorized list for a specific claim
     * @param qtspContract The QTSP Contract address to add
     * @param claim The claim type to authorize
     * @notice Grants permission for a trusted QTSP Contract to manage a specific claim
     */
    function addQTSPContractToClaim(address qtspContract, bytes32 claim) external onlyOwner {
        require(qtspContract != address(0), "Invalid QTSP Contract address");
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        require(trustedQTSPContracts[qtspContract], "QTSP Contract must be trusted first");
        require(!isQTSPContractAuthorizedForClaim(qtspContract, claim), "QTSP Contract already authorized for this claim");
        
        claimAuthorizedQTSPContracts[claim].push(qtspContract);
        qtspContractManagedClaims[qtspContract].push(claim);
        
        emit QTSPContractAddedToClaim(qtspContract, claim);
    }
    
    /**
     * @dev Remove a QTSP Contract from the authorized list for a specific claim
     * @param qtspContract The QTSP Contract address to remove
     * @param claim The claim type to revoke authorization for
     * @notice Revokes permission for a QTSP Contract to manage a specific claim
     */
    function removeQTSPContractFromClaim(address qtspContract, bytes32 claim) public onlyOwner {
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        
        // Remove from claimAuthorizedQTSPContracts using swap-and-pop for gas efficiency
        address[] storage qtspContractList = claimAuthorizedQTSPContracts[claim];
        for (uint256 i = 0; i < qtspContractList.length; i++) {
            if (qtspContractList[i] == qtspContract) {
                qtspContractList[i] = qtspContractList[qtspContractList.length - 1];
                qtspContractList.pop();
                break;
            }
        }
        
        // Remove from qtspContractManagedClaims using swap-and-pop for gas efficiency
        bytes32[] storage claims = qtspContractManagedClaims[qtspContract];
        for (uint256 i = 0; i < claims.length; i++) {
            if (claims[i] == claim) {
                claims[i] = claims[claims.length - 1];
                claims.pop();
                break;
            }
        }
        
        emit QTSPContractRemovedFromClaim(qtspContract, claim);
    }
    
    /**
     * @dev Check if a QTSP Contract owner is authorized to manage a specific claim
     * @param qtspContractOwner The QTSP Contract owner address to check
     * @param claim The claim type to check authorization for
     * @return True if the QTSP Contract owner is authorized for this claim, false otherwise
     * @notice This function checks both the trust status and claim-specific authorization
     */
    function isQTSPContractOwnerAuthorizedForClaim(address qtspContractOwner, bytes32 claim) public view returns (bool) {
        // Get the QTSP contract address from the owner
        address qtspContract = qtspOwnerToContract[qtspContractOwner];
        if (qtspContract == address(0)) {
            return false;
        }
        
        if (!trustedQTSPContracts[qtspContract]) {
            return false;
        }
        
        address[] memory qtspContractList = claimAuthorizedQTSPContracts[claim];
        for (uint256 i = 0; i < qtspContractList.length; i++) {
            if (qtspContractList[i] == qtspContract) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Check if a QTSP Contract is directly authorized to manage a specific claim
     * @param qtspContract The QTSP Contract address to check
     * @param claim The claim type to check authorization for
     * @return True if the QTSP Contract is authorized for this claim, false otherwise
     * @notice This function checks both the trust status and claim-specific authorization
     */
    function isQTSPContractAuthorizedForClaim(address qtspContract, bytes32 claim) public view returns (bool) {
        if (!trustedQTSPContracts[qtspContract]) {
            return false;
        }
        
        address[] memory qtspContractList = claimAuthorizedQTSPContracts[claim];
        for (uint256 i = 0; i < qtspContractList.length; i++) {
            if (qtspContractList[i] == qtspContract) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Get all QTSP Contracts that can manage a specific claim
     * @param claim The claim type to get authorized QTSP Contracts for
     * @return Array of QTSP Contract addresses that can manage the claim
     */
    function getClaimAuthorizedQTSPContracts(bytes32 claim) external view returns (address[] memory) {
        return claimAuthorizedQTSPContracts[claim];
    }
    
    /**
     * @dev Get all claims that a QTSP Contract can manage
     * @param qtspContract The QTSP Contract address to get managed claims for
     * @return Array of claim types the QTSP Contract can manage
     */
    function getQTSPContractManagedClaims(address qtspContract) external view returns (bytes32[] memory) {
        return qtspContractManagedClaims[qtspContract];
    }
    
    /**
     * @dev Get all trusted QTSP Contract addresses
     * @return Array of all trusted QTSP Contract addresses
     * @notice Returns the complete list of QTSP Contracts that are currently trusted
     */
    function getTrustedQTSPContracts() external view returns (address[] memory) {
        return trustedQTSPContractList;
    }

    /**
     * @dev Get the QTSP Contract address for a given owner
     * @param qtspOwner The QTSP Contract owner address to look up
     * @return The QTSP Contract address, or address(0) if not found
     */
    function getQTSPContractForOwner(address qtspOwner) external view returns (address) {
        return qtspOwnerToContract[qtspOwner];
    }
    
    /**
     * @dev Get the QTSP Contract owner for a given contract address
     * @param qtspContract The QTSP Contract address to look up
     * @return The QTSP Contract owner address, or address(0) if not found
     */
    function getQTSPContractOwner(address qtspContract) external view returns (address) {
        return qtspContractToOwner[qtspContract];
    }
    
    /**
     * @dev Check if an address is a QTSP Contract owner
     * @param qtspOwner The address to check
     * @return True if the address is a QTSP Contract owner, false otherwise
     */
    function isQTSPContractOwner(address qtspOwner) external view returns (bool) {
        return qtspOwnerToContract[qtspOwner] != address(0);
    }
    
    /**
     * @dev Required by UUPS to authorize upgrades
     * @param newImplementation The new implementation address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 