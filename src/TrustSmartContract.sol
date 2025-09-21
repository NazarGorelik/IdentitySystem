// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ClaimManagement/ClaimsRegistry.sol";
import "./ClaimManagement/ClaimsRegistryContract.sol";
import "./ClaimManagement/ClaimToken.sol";
import "./QTSPManagement/QTSPRightsManager.sol";

/**
 * @title Trust Smart Contract
 * @dev Handles signature verification and trust management for QTSP Contracts
 * @notice This contract verifies cryptographic signatures from authorized QTSP Contracts
 *         and provides trust verification services for the identity system
 */
contract TrustSmartContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using ClaimsRegistry for bytes32;
    
    // Reference to the QTSP Rights Manager for authorization checks
    QTSPRightsManager public rightsManager;
    
    // Reference to the Claims Registry Contract for token address lookup
    ClaimsRegistryContract public claimsRegistryContract;
    
    // Events
    event SignatureVerified(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    event SignatureVerificationFailed(address indexed user, bytes32 indexed claim, address indexed qtspContractOwner);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initializes the contract with the QTSP Rights Manager and Claims Registry Contract
     * @param _rightsManager Address of the QTSP Rights Manager contract
     * @param _claimsRegistryContract Address of the Claims Registry Contract
     * @param initialOwner The initial owner of the contract
     */
    function initialize(address _rightsManager, address _claimsRegistryContract, address initialOwner) public initializer {
        rightsManager = QTSPRightsManager(_rightsManager);
        claimsRegistryContract = ClaimsRegistryContract(_claimsRegistryContract);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }
    
    /**
     * @dev Verify a signature for a specific claim - automatically handles stored signatures
     * @param user The address of the user whose claim is being verified
     * @param claim The claim type to verify
     * @return True if the signature is valid and from an authorized QTSP Contract
     * @notice This function automatically determines whether to use a stored signature
     *         from a ClaimToken contract or requires external signature verification.
     *         It first checks if the user has a token for this claim type, and if so,
     *         verifies the stored signature. Otherwise, it returns false.
     */
    function verifySignature(
        address user,
        bytes32 claim
    ) public returns (bool) {
        // Get the ClaimToken contract address for this claim type
        address tokenContract = claimsRegistryContract.getClaimTokenAddress(claim);
        
        // If no token contract exists for this claim, verification fails
        if (tokenContract == address(0)) {
            emit SignatureVerificationFailed(user, claim, address(0));
            return false;
        }
        
        // Get the stored signature from the ClaimToken contract
        ClaimToken tokenContractInstance = ClaimToken(tokenContract);
        
        // Check if user has token first
        if (!tokenContractInstance.hasToken(user)) {
            emit SignatureVerificationFailed(user, claim, address(0));
            return false;
        }
        
        // Get the stored signature (this will not revert now since we checked hasToken)
        bytes memory storedSignature = tokenContractInstance.getUserSignature(user);
        
        // Verify the stored signature using the internal verification logic
        return _verifySignatureInternal(user, claim, storedSignature);
    }
    
    /**
     * @dev Internal function to verify a signature from a QTSP Contract for a specific claim
     * @param user The address of the user whose claim is being verified
     * @param claim The claim type to verify
     * @param signature The cryptographic signature to verify
     * @return True if the signature is valid and from an authorized QTSP Contract
     * @notice This internal function handles the actual signature verification logic
     */
    function _verifySignatureInternal(
        address user,
        bytes32 claim,
        bytes memory signature
    ) internal returns (bool) {
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
     * @dev Required by UUPS to authorize upgrades
     * @param newImplementation The new implementation address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
} 