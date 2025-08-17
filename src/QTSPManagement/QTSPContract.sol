// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../ClaimManagement/ClaimsRegistryContract.sol";
import "../ClaimManagement/ClaimToken.sol";

/**
 * @title QTSP Contract
 * @dev Handles token issuance and revocation for Qualified Trust Service Providers
 * @notice This contract only manages the issuance and revocation of claim tokens
 */
contract QTSPContract {
    using ClaimsRegistry for bytes32;
    
    // Reference to the Claims Registry Contract
    address public claimsRegistryContract;
    
    // Reference to the Trust Smart Contract for signature verification
    address public trustContract;

    // Owner of the contract
    address public owner;
    
    // Events
    event TokenIssued(address indexed user, bytes32 indexed claim, address indexed qtsp);
    event TokenRevoked(address indexed user, bytes32 indexed claim, address indexed qtsp);
    
    constructor(address _claimsRegistryContract, address _trustContract) {
        owner = msg.sender;
        claimsRegistryContract = _claimsRegistryContract;
        trustContract = _trustContract;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Issue token to a user (signature is generated internally)
     * @param user The address of the user
     * @param claim The claim type
     * @param signature The signature to store
     */
    function issueToken(
        address user,
        bytes32 claim,
        bytes memory signature
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        
        // Get the token contract address from the claims registry
        address tokenContract = ClaimsRegistryContract(claimsRegistryContract).getClaimTokenAddress(claim);
        require(tokenContract != address(0), "Claim token not registered");

        // Issue token and store the signature
        ClaimToken(tokenContract).issueToken(user, signature);
        
        emit TokenIssued(user, claim, msg.sender);
    }
    
    /**
     * @dev Revoke token from a user
     * @param user The address of the user
     * @param claim The claim type
     */
    function revokeToken(
        address user,
        bytes32 claim
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        
        // Get the token contract address from the claims registry
        address tokenContract = ClaimsRegistryContract(claimsRegistryContract).getClaimTokenAddress(claim);
        require(tokenContract != address(0), "Claim token not registered");
        
        // Revoke token
        ClaimToken(tokenContract).revokeToken(user);
        
        emit TokenRevoked(user, claim, msg.sender);
    }
    
    /**
     * @dev Check if a user has a specific claim token
     * @param user The address of the user
     * @param claim The claim type
     * @return True if the user has the claim token, false otherwise
     */
    function hasToken(address user, bytes32 claim) external view returns (bool) {
        address tokenContract = ClaimsRegistryContract(claimsRegistryContract).getClaimTokenAddress(claim);
        if (tokenContract == address(0)) {
            return false;
        }
        
        return ClaimToken(tokenContract).hasToken(user);
    }
} 