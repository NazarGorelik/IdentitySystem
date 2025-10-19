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
        HelperConfig helperConfig = new HelperConfig();
        uint256 chainId = helperConfig.getChainId();

        if (chainId == 11155111) {
            // Sepolia network - always deploy
            try helperConfig.deploySepoliaContracts() returns (SharedStructs.NetworkConfig memory config) {
                logDeploymentSummary(config);
            } catch Error(string memory reason) {
                console.log("Sepolia deployment failed:", reason);
                revert("Sepolia deployment failed");
            }
        } else if (chainId == 31337) {
            // Anvil network - get or create
            try helperConfig.getOrCreateAnvilNetworkConfig() returns (SharedStructs.NetworkConfig memory config) {
                logDeploymentSummary(config);
            } catch Error(string memory reason) {
                console.log("Anvil deployment failed:", reason);
                revert("Anvil deployment failed");
            }
        } else {
            revert("Unsupported network");
        }
        
        console.log("=== Deployment Process Completed ===");
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
        console.log("To upgrade contracts, first deploy new implementations, then upgrade proxies. Example with OVER_18 token:");
        console.log("");
        
        if (block.chainid == 31337) {
            console.log("***Run 'cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url http://127.0.0.1:8545' to get the Implementation address");
            console.log("Step 1: Deploy ClaimsRegistry library");
            console.log("forge create src/ClaimManagement/ClaimsRegistry.sol:ClaimsRegistry --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast");
            console.log("");
            console.log("Step 2: Deploy new OVER_18 ClaimToken implementation (replace <CLAIMS_REGISTRY_ADDRESS> with Step 1 address)");
            console.log("forge create src/ClaimManagement/ClaimToken.sol:ClaimToken --libraries src/ClaimManagement/ClaimsRegistry.sol:ClaimsRegistry:<CLAIMS_REGISTRY_ADDRESS> --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast");
            console.log("");
            console.log("Step 3: Upgrade OVER_18 ClaimToken proxy (replace <NEW_OVER18_IMPL> with Step 2 address)");
            console.log("cast send", address(config.proxies.over18Token), '"upgradeToAndCall(address,bytes)" <NEW_OVER18_IMPL> "0x" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');
        } else if (block.chainid == 11155111) {
            console.log("***Run 'cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $SEPOLIA_RPC_URL' to get the Implementation address");
            console.log("Step 1: Deploy ClaimsRegistry library");
            console.log("forge create src/ClaimManagement/ClaimsRegistry.sol:ClaimsRegistry --rpc-url $SEPOLIA_RPC_URL --account SEPOLIA_PRIVATE_KEY --broadcast");
            console.log("");
            console.log("Step 2: Deploy new OVER_18 ClaimToken implementation (replace <CLAIMS_REGISTRY_ADDRESS> with Step 1 address)");
            console.log("forge create src/ClaimManagement/ClaimToken.sol:ClaimToken --libraries src/ClaimManagement/ClaimsRegistry.sol:ClaimsRegistry:<CLAIMS_REGISTRY_ADDRESS> --rpc-url $SEPOLIA_RPC_URL --account SEPOLIA_PRIVATE_KEY --broadcast");
            console.log("");
            console.log("Step 3: Upgrade OVER_18 ClaimToken proxy (replace <NEW_OVER18_IMPL> with Step 2 address)");
            console.log("cast send", address(config.proxies.over18Token), '"upgradeToAndCall(address,bytes)" <NEW_OVER18_IMPL> "0x" --rpc-url $SEPOLIA_RPC_URL --account SEPOLIA_PRIVATE_KEY');
        }
    }
}