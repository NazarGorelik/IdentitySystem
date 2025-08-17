// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimManagement/ClaimsRegistry.sol";
import "./ClaimManagement/ClaimToken.sol";
import "./QTSPManagement/QTSPRightsManager.sol";


/**
 * @title Trust Smart Contract
 * @dev Handles signature verification and trust management for QTSP Contracts
 * @notice This contract verifies signatures and manages trust relationships
 */
contract TrustSmartContract {
    using ClaimsRegistry for bytes32;
    
    // Reference to the QTSP Rights Manager
    QTSPRightsManager public rightsManager;
    
    // Events
    event SignatureVerified(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    event SignatureVerificationFailed(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    
    // Owner of the contract
    address public owner;
    
    constructor(address _rightsManager) {
        owner = msg.sender;
        rightsManager = QTSPRightsManager(_rightsManager);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    /**
     * @dev Verify a signature from a QTSP Contract for a specific claim
     * @param user The address of the user
     * @param claim The claim type
     * @param signature The signature to verify
     * @return True if the signature is valid and from an authorized QTSP Contract
     */
    function verifySignature(
        address user,
        bytes32 claim,
        bytes memory signature
    ) public returns (bool) {
        require(signature.length == 65, "Invalid signature length");
        
        // Create the message hash that was signed
        bytes32 messageHash = keccak256(abi.encodePacked(user, claim));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        
        // Recover the signer from the signature
        address signer = recoverSigner(ethSignedMessageHash, signature);
        
        // Check if the signer is a trusted QTSP Contract with permission for this claim
        bool isAuthorized = rightsManager.isQTSPContractOwnerAuthorizedForClaim(signer, claim);

        if (isAuthorized) {
            emit SignatureVerified(user, claim, signer);
        } else {
            emit SignatureVerificationFailed(user, claim, signer);
        }
        
        return isAuthorized;
    }
    
    /**
     * @dev Verify a signature stored in a ClaimToken contract
     * @param user The address of the user
     * @param claim The claim type
     * @param tokenContract The ClaimToken contract address
     * @return True if the signature is valid and from an authorized QTSP Contract
     */
    function verifyStoredSignature(
        address user,
        bytes32 claim,
        address tokenContract
    ) external returns (bool) {
        require(tokenContract != address(0), "Invalid token contract address");
        
        // Get the stored signature from the ClaimToken contract
        ClaimToken tokenContractInstance = ClaimToken(tokenContract);
        bytes memory storedSignature = tokenContractInstance.getUserSignature(user);
        
        // Check if user has token and signature exists
        if (!tokenContractInstance.hasToken(user) || storedSignature.length == 0) {
            return false;
        }
        
        // Verify the stored signature
        return verifySignature(user, claim, storedSignature);
    }
    
    /**
     * @dev Recover the signer address from a signature
     * @param hash The hash that was signed
     * @param signature The signature
     * @return The address of the signer
     */
    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        // Handle signature malleability
        if (v < 27) {
            v += 27;
        }
        
        require(v == 27 || v == 28, "Invalid signature 'v' value");
        
        return ecrecover(hash, v, r, s);
    }
    
    /**
     * @dev Check if a QTSP Contract is trusted
     * @param qtspContract The QTSP Contract address
     * @return True if the QTSP Contract is trusted
     */
    function isTrustedQTSPContract(address qtspContract) external view returns (bool) {
        return rightsManager.trustedQTSPContracts(qtspContract);
    }
    
    /**
     * @dev Check if a QTSP Contract is authorized for a specific claim
     * @param qtspContract The QTSP Contract address
     * @param claim The claim type
     * @return True if the QTSP Contract is authorized for this claim
     */
    function isQTSPContractAuthorizedForClaim(address qtspContract, bytes32 claim) external view returns (bool) {
        return rightsManager.isQTSPContractAuthorizedForClaim(qtspContract, claim);
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