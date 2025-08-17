// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimsRegistry.sol";

/**
 * @title Claims Registry Contract
 * @dev Manages claim token contracts and their addresses
 * @notice This contract stores the addresses of deployed ClaimToken contracts
 */
contract ClaimsRegistryContract {
    using ClaimsRegistry for bytes32;
    
    // I need to kepp both mappings to ensure that both claims don't have the same token address
    // Mapping from claim type to ClaimToken contract address
    mapping(bytes32 => address) public claimToToken;
    
    // Mapping from ClaimToken address to claim type
    mapping(address => bytes32) public tokenToClaim;
    
    // Owner of the contract
    address public owner;
    
    // Events
    event ClaimTokenRegistered(bytes32 indexed claim, address indexed tokenAddress);
    event ClaimTokenRemoved(bytes32 indexed claim, address indexed tokenAddress);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Register a ClaimToken contract for a specific claim
     * @param claim The claim type
     * @param tokenAddress The address of the ClaimToken contract
     */
    function registerClaimToken(bytes32 claim, address tokenAddress) external onlyOwner {
        require(ClaimsRegistry.isValidClaim(claim), "Invalid claim type");
        require(tokenAddress != address(0), "Invalid token address");
        require(claimToToken[claim] == address(0), "Claim token already registered");
        require(tokenToClaim[tokenAddress] == bytes32(0), "Token already registered for another claim");
        
        claimToToken[claim] = tokenAddress;
        tokenToClaim[tokenAddress] = claim;
        
        emit ClaimTokenRegistered(claim, tokenAddress);
    }
    
    /**
     * @dev Remove a ClaimToken contract registration
     * @param claim The claim type
     */
    function removeClaimToken(bytes32 claim) external onlyOwner {
        require(claimToToken[claim] != address(0), "Claim token not registered");
        
        address tokenAddress = claimToToken[claim];
        claimToToken[claim] = address(0);
        tokenToClaim[tokenAddress] = bytes32(0);
        
        emit ClaimTokenRemoved(claim, tokenAddress);
    }
    
    /**
     * @dev Get the ClaimToken address for a claim
     * @param claim The claim type
     * @return The ClaimToken contract address
     */
    function getClaimTokenAddress(bytes32 claim) external view returns (address) {
        return claimToToken[claim];
    }
    
    /**
     * @dev Get the claim type for a ClaimToken address
     * @param tokenAddress The ClaimToken contract address
     * @return The claim type
     */
    function getClaimForToken(address tokenAddress) external view returns (bytes32) {
        return tokenToClaim[tokenAddress];
    }
    
    /**
     * @dev Check if a claim has a registered token contract
     * @param claim The claim type
     * @return True if the claim has a registered token contract
     */
    function hasClaimToken(bytes32 claim) external view returns (bool) {
        return claimToToken[claim] != address(0);
    }

    function getClaimName(bytes32 claim) external pure returns (string memory) {
        return ClaimsRegistry.getClaimName(claim);
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