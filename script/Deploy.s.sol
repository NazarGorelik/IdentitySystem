// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "./helpers/HelperConfig.s.sol";
import "./helpers/SharedStructs.s.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Token System Deployment Script
 * @dev Script to deploy the custom token-based identity system with network differentiation
 * @notice Now includes signature generation for testing purposes and UUPS proxy deployment
 */
contract Deploy is Script {
    function run() external {
        console.log("=== Starting Deployment Process ===");
        console.log("Network Chain ID:", block.chainid);
        
        HelperConfig helperConfig = new HelperConfig();
        
        // Deploy contracts based on network - use cached chain ID from HelperConfig
        uint256 chainId = helperConfig.getChainId();
        if (chainId == 11155111) {
            // Sepolia network - always deploy
            console.log("=== Deploying to Sepolia Network ===");
            try helperConfig.deploySepoliaContracts() returns (SharedStructs.NetworkConfig memory config) {
                logDeploymentSummary(config);
                console.log("=== Note: For Sepolia, generate signatures off-chain using MetaMask ===");
            } catch Error(string memory reason) {
                console.log("Sepolia deployment failed:", reason);
                revert("Sepolia deployment failed");
            }
        } else if (chainId == 31337) {
            // Anvil network - get or create
            console.log("=== Deploying to Anvil Network ===");
            try helperConfig.getOrCreateNetworkConfig() returns (SharedStructs.NetworkConfig memory config) {
                logDeploymentSummary(config);
                
                // Generate test signatures for Anvil network
                console.log();
                console.log("\n=== Generating Test Signatures for Anvil ===");
                generateTestSignatures(config);
                
            } catch Error(string memory reason) {
                console.log("Anvil deployment failed:", reason);
                revert("Anvil deployment failed");
            }
        } else {
            revert("Unsupported network");
        }
        
        console.log("=== Deployment Process Completed ===");
    }
    
    function generateTestSignatures(SharedStructs.NetworkConfig memory config) internal pure {
        // Generate signature for OVER_18 claim
        generateSignatureForClaim(
            "OVER_18",
            ClaimsRegistry.OVER_18,
            address(config.proxies.qtspContract1)
        );
        
        // Generate signature for EU_CITIZEN claim
        generateSignatureForClaim(
            "EU_CITIZEN", 
            ClaimsRegistry.EU_CITIZEN,
            address(config.proxies.qtspContract2)
        );
    }
    
    function generateSignatureForClaim(
        string memory claimName,
        bytes32 claimType,
        address qtspContract
    ) internal pure {
        // Generate a test user address (you can replace this with actual addresses)
        address testUser = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 privateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        // Create the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(testUser, claimType));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        
        // Fix: Create proper 65-byte signature without abi.encodePacked
        bytes memory signature = new bytes(65);
        assembly {
            mstore(add(signature, 32), r)
            mstore(add(signature, 64), s)
            mstore8(add(signature, 96), v)
        }
        
        console.log("---", claimName, "Claim ---");
        console.log("QTSP Contract:", qtspContract);
        console.log("Test User:", testUser);
        console.log("Claim Type:", vm.toString(claimType));
        console.log("Signature:", vm.toString(signature));
        console.log("");
    }
    
    function logDeploymentSummary(SharedStructs.NetworkConfig memory config) internal view {
        console.log("=== Deployment Summary ===");
        console.log("Network Chain ID:", block.chainid); // Keep this for logging purposes
        console.log("");
        console.log("=== Implementation Contracts ===");
        console.log("QTSP Rights Manager Implementation:", address(config.implementations.rightsManagerImpl));
        console.log("Claims Registry Contract Implementation:", address(config.implementations.claimsRegistryImpl));
        console.log("Trust Smart Contract Implementation:", address(config.implementations.trustContractImpl));
        console.log("QTSP Contract 1 Implementation:", address(config.implementations.qtspContract1Impl));
        console.log("QTSP Contract 2 Implementation:", address(config.implementations.qtspContract2Impl));
        console.log("OVER_18 Token Implementation:", address(config.implementations.over18TokenImpl));
        console.log("EU_CITIZEN Token Implementation:", address(config.implementations.euCitizenTokenImpl));
        console.log("Restricted Contract Implementation:", address(config.implementations.restrictedContractImpl));
        console.log("");
        console.log("=== Proxy Contracts (Use These Addresses) ===");
        console.log("QTSP Rights Manager Proxy:", address(config.proxies.rightsManager));
        console.log("Claims Registry Contract Proxy:", address(config.proxies.claimsRegistry));
        console.log("Trust Smart Contract Proxy:", address(config.proxies.trustContract));
        console.log("QTSP Contract 1 Proxy:", address(config.proxies.qtspContract1));
        console.log("QTSP Contract 2 Proxy:", address(config.proxies.qtspContract2));
        console.log("OVER_18 Token Proxy:", address(config.proxies.over18Token));
        console.log("EU_CITIZEN Token Proxy:", address(config.proxies.euCitizenToken));
        console.log("Restricted Contract (Direct):", address(config.proxies.restrictedContract));
        console.log("");
        console.log("=== Permission Setup ===");
        console.log("QTSP Contract 1 is trusted and can manage: OVER_18");
        console.log("QTSP Contract 2 is trusted and can manage: EU_CITIZEN");
        console.log("ClaimToken contracts use QTSPRightsManager for authorization");
        console.log("");
        console.log("=== Registered Claims ===");
        console.log("OVER_18 claim registered with token proxy:", address(config.proxies.over18Token));
        console.log("EU_CITIZEN claim registered with token proxy:", address(config.proxies.euCitizenToken));
        console.log("");
        console.log("=== UUPS Proxy Information ===");
        console.log("All contracts (except RestrictedSmartContract) are upgradeable via UUPS pattern");
        console.log("Implementation contracts can be upgraded while preserving state and addresses");
        console.log("Use proxy addresses for all interactions with the system");
    }
}
