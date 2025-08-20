// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../ClaimManagement/ClaimsRegistryContract.sol";
import "../ClaimManagement/ClaimToken.sol";

/**
 * @title QTSP Contract
 * @dev Handles token issuance and revocation for Qualified Trust Service Providers
 * @notice This contract manages the issuance and revocation of claim tokens through
 *         authorized QTSP contracts that have been registered in the system
 */
contract QTSPContract {
    using ClaimsRegistry for bytes32;
    
    // Reference to the Claims Registry Contract
    ClaimsRegistryContract public claimsRegistryContract;

    // Owner of the contract
    address public owner;
    
    // Events
    event TokenIssued(address indexed user, bytes32 indexed claim, address indexed qtsp);
    event TokenRevoked(address indexed user, bytes32 indexed claim, address indexed qtsp);
    
    /**
     * @dev Constructor initializes the contract with required dependencies
     * @param _claimsRegistryContract Address of the Claims Registry Contract
     */
    constructor(address _claimsRegistryContract) {
        owner = msg.sender;
        claimsRegistryContract = ClaimsRegistryContract(_claimsRegistryContract);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Issue token to a user with a provided signature
     * @param user The address of the user to issue the token to
     * @param claim The claim type to issue
     * @param signature The cryptographic signature to store with the token
     * @notice Only the contract owner can call this function
     */
    function issueToken(
        address user,
        bytes32 claim,
        bytes memory signature
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        
        // Get the token contract address from the claims registry
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        require(tokenContract != address(0), "Claim token not registered");

        // Issue token and store the signature
        ClaimToken(tokenContract).issueToken(user, signature);
        
        emit TokenIssued(user, claim, msg.sender);
    }
    
    /**
     * @dev Revoke token from a user
     * @param user The address of the user to revoke the token from
     * @param claim The claim type to revoke
     * @notice Only the contract owner can call this function
     */
    function revokeToken(
        address user,
        bytes32 claim
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        
        // Get the token contract address from the claims registry
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        require(tokenContract != address(0), "Claim token not registered");
        
        // Revoke token
        ClaimToken(tokenContract).revokeToken(user);
        
        emit TokenRevoked(user, claim, msg.sender);
    }
    
    /**
     * @dev Check if a user has a specific claim token
     * @param user The address of the user to check
     * @param claim The claim type to check for
     * @return True if the user has the claim token, false otherwise
     */
    function hasToken(address user, bytes32 claim) external view returns (bool) {
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        if (tokenContract == address(0)) {
            return false;
        }
        
        return ClaimToken(tokenContract).hasToken(user);
    }
} 