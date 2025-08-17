// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimManagement/ClaimsRegistry.sol";
import "./ClaimManagement/ClaimsRegistryContract.sol";
import "./QTSPManagement/QTSPContract.sol";
import "./TrustSmartContract.sol";

/**
 * @title Restricted Smart Contract
 * @dev Example contract that requires specific claims for access
 * @notice This contract demonstrates how to use the identity system for access control
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
     * @param user The address of the user
     */
    function accessAgeRestrictedService(address user) external {
        require(user != address(0), "Invalid user address");
        
        // Get the token contract address
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(ClaimsRegistry.OVER_18);
        
        // Verify the stored signature using TrustSmartContract
        bool isValidSignature = trustContract.verifyStoredSignature(user, ClaimsRegistry.OVER_18, tokenContract);
        require(isValidSignature, "Invalid signature from QTSP");
        
        emit AccessGranted(user, ClaimsRegistry.OVER_18);
        emit ServiceUsed(user, "Age Restricted Service");
    }
    
    /**
     * @dev Access a service that requires EU citizenship
     * @param user The address of the user
     */
    function accessEUCitizenService(address user) external {
        require(user != address(0), "Invalid user address");
        
        // Get the token contract address
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(ClaimsRegistry.EU_CITIZEN);
        
        // Verify the stored signature using TrustSmartContract
        bool isValidSignature = trustContract.verifyStoredSignature(user, ClaimsRegistry.EU_CITIZEN, tokenContract);
        require(isValidSignature, "Invalid signature from QTSP");
        
        emit AccessGranted(user, ClaimsRegistry.EU_CITIZEN);
        emit ServiceUsed(user, "EU Citizen Service");
    }
    
    /**
     * @dev Check if a user can access a specific service
     * @param user The address of the user
     * @param claim The required claim
     * @return True if the user can access the service
     */
    function canAccessService(address user, bytes32 claim) external returns (bool) {
        // Get the token contract address
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        if (tokenContract == address(0)) {
            return false;
        }
        
        // Verify the stored signature using TrustSmartContract
        return trustContract.verifyStoredSignature(user, claim, tokenContract);
    }
    
    /**
     * @dev Get the Trust Smart Contract address
     * @return The Trust Smart Contract address
     */
    function getTrustContract() external view returns (address) {
        return address(trustContract);
    }
} 