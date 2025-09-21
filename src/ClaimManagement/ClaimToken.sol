// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ClaimsRegistry.sol";
import "../QTSPManagement/QTSPRightsManager.sol";

/**
 * @title Claim Token
 * @dev Custom token contract representing a specific claim with signature storage
 * @notice Each claim type gets its own token contract that stores claimType and signature
 *         for individual users. Tokens can only be issued/revoked by authorized QTSP contracts.
 *         This is a custom implementation optimized for identity claims, not a standard ERC20 token.
 */
contract ClaimToken is Initializable, UUPSUpgradeable, OwnableUpgradeable {
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
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract
     * @param _claimType The claim type this token represents (must be valid in ClaimsRegistry)
     * @param _rightsManager The QTSP Rights Manager address for authorization checks
     * @param initialOwner The initial owner of the contract
     */
    function initialize(
        bytes32 _claimType, 
        address _rightsManager, 
        address initialOwner
    ) public initializer {
        require(ClaimsRegistry.isValidClaim(_claimType), "Invalid claim type");
        require(_rightsManager != address(0), "Invalid rights manager address");
        
        claimType = _claimType;
        rightsManager = QTSPRightsManager(_rightsManager);
        
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }
    
    modifier onlyAuthorizedQTSPContract() {
        require(rightsManager.isQTSPContractAuthorizedForClaim(msg.sender, claimType), "Only authorized QTSP Contract can call this function");
        _;
    }
    
    /**
     * @dev Issue token to a user (only callable by authorized QTSP Contracts)
     * @param user The user address to issue the token to
     * @param signature The cryptographic signature to store with the token
     * @notice This function mints 1 ERC20 token and stores a signature that proves the user's claim
     *         has been verified by an authorized QTSP Contract
     */
    function issueToken(address user, bytes memory signature) external onlyAuthorizedQTSPContract {
        require(user != address(0), "Invalid user address");
        require(signature.length == 65, "Invalid signature length");
        require(userSignatures[user].length == 0, "User already has a token");
        
        userSignatures[user] = signature;
        emit TokenIssued(user, claimType, signature);
    }
    
    /**
     * @dev Revoke token from a user (only callable by authorized QTSP Contracts)
     * @param user The user address to revoke the token from
     * @notice This function burns the ERC20 token and removes the stored signature, 
     *         effectively revoking the user's verified claim
     */
    function revokeToken(address user) external onlyAuthorizedQTSPContract {
        require(user != address(0), "Invalid user address");
        require(userSignatures[user].length > 0, "User does not have a token");
        
        delete userSignatures[user];
        emit TokenRevoked(user);
    }
    
    /**
     * @dev Check if a user has a verified signature for this claim
     * @param user The user address to check
     * @return True if user has a signature, false otherwise
     * @notice This function indicates whether a user's claim has been verified
     */
    function hasToken(address user) external view returns (bool) {
        return userSignatures[user].length > 0;
    }
    
    /**
     * @dev Get the stored signature for a user
     * @param user The user address to get the signature for
     * @return The cryptographic signature for the user
     * @notice This function retrieves the signature that proves the user's
     *         claim has been verified by an authorized QTSP Contract
     */
    function getUserSignature(address user) external view returns (bytes memory) {
        require(userSignatures[user].length > 0, "User does not have a token");
        return userSignatures[user];
    }
    
    /**
     * @dev Get the claim type as bytes32
     * @return The claim type hash that this token represents
     */
    function getClaimType() external view returns (bytes32) {
        return claimType;
    }
    
    /**
     * @dev Get the claim name as a human-readable string
     * @return The claim name as a string for display purposes
     * @notice This function provides a human-readable representation of the claim type
     */
    function getClaimName() external view returns (string memory) {
        return ClaimsRegistry.getClaimName(claimType);
    }
    
    /**
     * @dev Get the rights manager address
     * @return The address of the QTSP Rights Manager contract
     */
    function getRightsManager() external view returns (address) {
        return address(rightsManager);
    }
    
    /**
     * @dev Required by UUPS to authorize upgrades
     * @param newImplementation The new implementation address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 