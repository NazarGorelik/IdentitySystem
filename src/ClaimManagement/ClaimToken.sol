// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimsRegistry.sol";
import "../QTSPManagement/QTSPRightsManager.sol";

/**
 * @title Claim Token
 * @dev Custom token representing a specific claim with signature storage
 * @notice Each claim type gets its own token contract that stores claimType and signature
 */
contract ClaimToken {
    using ClaimsRegistry for bytes32;
    
    // The claim type this token represents (bytes32)
    bytes32 public claimType;
    
    // Reference to the QTSP Rights Manager for authorization checks
    QTSPRightsManager public rightsManager;
    
    // Mapping to store signatures for each user
    mapping(address => bytes) public userSignatures;
    
    // Events
    event TokenIssued(address indexed user, bytes32 claimType, bytes signature);
    event TokenRevoked(address indexed user);
    
    // Owner of the contract
    address public owner;
    
    /**
     * @dev Constructor sets the claim type and validates it against ClaimsRegistry
     * @param _claimType The claim type this token represents (must be valid in ClaimsRegistry)
     * @param _rightsManager The QTSP Rights Manager address
     */
    constructor(bytes32 _claimType, address _rightsManager) {
        require(ClaimsRegistry.isValidClaim(_claimType), "Invalid claim type");
        require(_rightsManager != address(0), "Invalid rights manager address");
        claimType = _claimType;
        rightsManager = QTSPRightsManager(_rightsManager);
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthorizedQTSPContract() {
        require(rightsManager.isQTSPContractAuthorizedForClaim(msg.sender, claimType), "Only authorized QTSP Contract can call this function");
        _;
    }
    
    /**
     * @dev Issue token to a user (only callable by authorized QTSP Contracts)
     * @param user The user to issue token to
     * @param signature The signature to store
     */
    function issueToken(address user, bytes memory signature) external onlyAuthorizedQTSPContract {
        require(user != address(0), "Invalid user address");
        require(signature.length == 65, "Invalid signature length");
        
        userSignatures[user] = signature;
        emit TokenIssued(user, claimType, signature);
    }
    
    /**
     * @dev Revoke token from a user (only callable by authorized QTSP Contracts)
     * @param user The user to revoke token from
     */
    function revokeToken(address user) external onlyAuthorizedQTSPContract {
        require(user != address(0), "Invalid user address");
        require(userSignatures[user].length > 0, "User does not have a token");
        
        delete userSignatures[user];
        emit TokenRevoked(user);
    }
    
    /**
     * @dev Check if a user has a signature
     * @param user The user to check
     * @return True if user has a signature, false otherwise
     */
    function hasToken(address user) external view returns (bool) {
        return userSignatures[user].length > 0;
    }
    
    /**
     * @dev Get the signature for a user
     * @param user The user to get signature for
     * @return The signature for the user
     */
    function getUserSignature(address user) external view returns (bytes memory) {
        require(userSignatures[user].length > 0, "User does not have a token");
        return userSignatures[user];
    }
    
    /**
     * @dev Get the claim type as bytes32
     * @return The claim type
     */
    function getClaimType() external view returns (bytes32) {
        return claimType;
    }
    
    /**
     * @dev Get the claim name as a string
     * @return The claim name
     */
    function getClaimName() external view returns (string memory) {
        return ClaimsRegistry.getClaimName(claimType);
    }
    
    /**
     * @dev Get the rights manager address
     * @return The rights manager address
     */
    function getRightsManager() external view returns (address) {
        return address(rightsManager);
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }
} 