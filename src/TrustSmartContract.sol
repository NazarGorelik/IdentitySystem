// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./ClaimManagement/ClaimsRegistry.sol";
import "./ClaimManagement/ClaimToken.sol";
import "./QTSPManagement/QTSPRightsManager.sol";

/**
 * @title Trust Smart Contract
 * @dev Handles signature verification and trust management for QTSP Contracts
 * @notice This contract verifies cryptographic signatures from authorized QTSP Contracts
 *         and provides trust verification services for the identity system
 */
contract TrustSmartContract {
    using ClaimsRegistry for bytes32;
    
    // Reference to the QTSP Rights Manager for authorization checks
    QTSPRightsManager public rightsManager;
    
    // Events
    event SignatureVerified(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    event SignatureVerificationFailed(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    
    // Owner of the contract
    address public owner;
    
    /**
     * @dev Constructor initializes the contract with the QTSP Rights Manager
     * @param _rightsManager Address of the QTSP Rights Manager contract
     */
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
     * @param user The address of the user whose claim is being verified
     * @param claim The claim type to verify
     * @param signature The cryptographic signature to verify
     * @return True if the signature is valid and from an authorized QTSP Contract
     * @notice This function recovers the signer from the signature and verifies
     *         their authorization to issue the specified claim
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
     * @param user The address of the user whose claim is being verified
     * @param claim The claim type to verify
     * @param tokenContract The ClaimToken contract address containing the stored signature
     * @return True if the signature is valid and from an authorized QTSP Contract
     * @notice This function retrieves a stored signature from a ClaimToken contract
     *         and verifies its authenticity and authorization
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
     * @param signature The signature to recover the signer from
     * @return The address of the signer
     * @notice This function handles Ethereum signature recovery with proper
     *         signature malleability protection
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
     * @param qtspContract The QTSP Contract address to check
     * @return True if the QTSP Contract is trusted, false otherwise
     */
    function isTrustedQTSPContract(address qtspContract) external view returns (bool) {
        return rightsManager.trustedQTSPContracts(qtspContract);
    }
    
    /**
     * @dev Check if a QTSP Contract is authorized for a specific claim
     * @param qtspContract The QTSP Contract address to check
     * @param claim The claim type to check authorization for
     * @return True if the QTSP Contract is authorized for this claim, false otherwise
     */
    function isQTSPContractAuthorizedForClaim(address qtspContract, bytes32 claim) external view returns (bool) {
        return rightsManager.isQTSPContractAuthorizedForClaim(qtspContract, claim);
    }
    
    /**
     * @dev Get the rights manager address
     * @return The address of the QTSP Rights Manager contract
     */
    function getRightsManager() external view returns (address) {
        return address(rightsManager);
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner The new owner address
     * @notice Only the current owner can call this function
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }
} 