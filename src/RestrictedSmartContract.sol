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
    
    // QTSP Contract for claim verification
    ClaimsRegistryContract public claimsRegistryContract;
    
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
     * @param _claimsRegistryContract Address of the Claims Registry Contract
     * @param _trustContract Address of the Trust Smart Contract
     */
    constructor(address _claimsRegistryContract, address _trustContract) {
        claimsRegistryContract = ClaimsRegistryContract(_claimsRegistryContract);
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
        console.log("=== accessAgeRestrictedService called ===");
        console.log("User address:", user);
        
        require(user != address(0), "Invalid user address");
        console.log("User address is valid");
        
        // Get the token contract address for the OVER_18 claim
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(ClaimsRegistry.OVER_18);
        console.log("Token contract address:", tokenContract);
        
        require(tokenContract != address(0), "OVER_18 claim token not registered");
        console.log("OVER_18 claim token is registered");
        
        // Verify the stored signature using TrustSmartContract
        bool isValidSignature = trustContract.verifyStoredSignature(user, ClaimsRegistry.OVER_18, tokenContract);
        console.log("Signature valid:", isValidSignature);
        
        require(isValidSignature, "Invalid signature from QTSP");
        console.log("Signature verification passed");
        
        emit AccessGranted(user, ClaimsRegistry.OVER_18);
        emit ServiceUsed(user, "Age Restricted Service");
        console.log("Access granted and events emitted");
    }
    
    /**
     * @dev Access a service that requires EU citizenship
     * @param user The address of the user requesting access
     * @notice This function verifies that the user has a valid EU_CITIZEN claim
     *         before granting access to EU citizen-only services
     */
    function accessEUCitizenService(address user) external {
        require(user != address(0), "Invalid user address");
        
        // Get the token contract address for the EU_CITIZEN claim
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(ClaimsRegistry.EU_CITIZEN);
        
        // Verify the stored signature using TrustSmartContract
        bool isValidSignature = trustContract.verifyStoredSignature(user, ClaimsRegistry.EU_CITIZEN, tokenContract);
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
        // Get the token contract address for the specified claim
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        if (tokenContract == address(0)) {
            return false;
        }
        
        // Verify the stored signature using TrustSmartContract
        return trustContract.verifyStoredSignature(user, claim, tokenContract);
    }
    
    /**
     * @dev Get the Trust Smart Contract address
     * @return The address of the Trust Smart Contract used for signature verification
     */
    function getTrustContract() external view returns (address) {
        return address(trustContract);
    }
} 