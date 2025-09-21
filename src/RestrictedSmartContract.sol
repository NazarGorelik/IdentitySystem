// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimManagement/ClaimsRegistry.sol";
import "./ClaimManagement/ClaimsRegistryContract.sol";
import "./QTSPManagement/QTSPContract.sol";
import "./TrustSmartContract.sol";
import "forge-std/console.sol";

/**
 * @title Restricted Smart Contract
 * @dev Example contract that requires specific claims for access control
 * @notice This contract demonstrates how to use the identity system for access control
 *         by requiring users to have specific verified claims before accessing services
 */
contract RestrictedSmartContract {
    using ClaimsRegistry for bytes32;
    
    // Trust Smart Contract for signature verification
    TrustSmartContract public trustContract;
    
    // Events
    event AccessGranted(address indexed user, bytes32 indexed claim);
    event AccessDenied(address indexed user, bytes32 indexed claim, string reason);
    event ServiceUsed(address indexed user, string serviceName);
    
    // Owner of the contract
    address public owner;

    /**
     * @dev Constructor initializes the contract with required dependencies
     * @param _trustContract Address of the Trust Smart Contract
     */
    constructor(address _trustContract) {
        trustContract = TrustSmartContract(_trustContract);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Access a service that requires the user to be over 18
     * @param user The address of the user requesting access
     * @notice This function verifies that the user has a valid OVER_18 claim
     *         before granting access to age-restricted services
     */
    function accessAgeRestrictedService(address user) external {
        require(user != address(0), "Invalid user address");
        
        // Verify the signature using TrustSmartContract (automatically handles stored signatures)
        bool isValidSignature = trustContract.verifySignature(user, ClaimsRegistry.OVER_18);
        require(isValidSignature, "Invalid signature from QTSP");
        
        emit AccessGranted(user, ClaimsRegistry.OVER_18);
        emit ServiceUsed(user, "Age Restricted Service");
    }
    
    /**
     * @dev Access a service that requires EU citizenship
     * @param user The address of the user requesting access
     * @notice This function verifies that the user has a valid EU_CITIZEN claim
     *         before granting access to EU citizen-only services
     */
    function accessEUCitizenService(address user) external {
        require(user != address(0), "Invalid user address");
        
        // Verify the signature using TrustSmartContract (automatically handles stored signatures)
        bool isValidSignature = trustContract.verifySignature(user, ClaimsRegistry.EU_CITIZEN);
        require(isValidSignature, "Invalid signature from QTSP");
        
        emit AccessGranted(user, ClaimsRegistry.EU_CITIZEN);
        emit ServiceUsed(user, "EU Citizen Service");
    }
    
    /**
     * @dev Check if a user can access a specific service based on their claims
     * @param user The address of the user to check
     * @param claim The required claim type for access
     * @return True if the user can access the service, false otherwise
     * @notice This function verifies that the user has a valid signature for the
     *         specified claim from an authorized QTSP Contract
     */
    function canAccessService(address user, bytes32 claim) external returns (bool) {
        // Verify the signature using TrustSmartContract (automatically handles stored signatures)
        return trustContract.verifySignature(user, claim);
    }
    
    /**
     * @dev Get the Trust Smart Contract address
     * @return The address of the Trust Smart Contract used for signature verification
     */
    function getTrustContract() external view returns (address) {
        return address(trustContract);
    }
} 