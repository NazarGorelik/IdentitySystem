// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./helpers/HelperConfig.s.sol";
import "./helpers/SharedStructs.s.sol";
import "../src/ClaimManagement/ClaimsRegistry.sol";
import "../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../src/ClaimManagement/ClaimToken.sol";
import "../src/QTSPManagement/QTSPRightsManager.sol";
import "../src/QTSPManagement/QTSPContract.sol";
import "../src/TrustSmartContract.sol";

/**
 * @title UUPS Proxy Upgrade Script
 * @dev Script to upgrade implementation contracts for UUPS proxies
 * @notice This script allows upgrading the implementation logic while preserving
 *         all state, addresses, and user interactions
 */
contract UpgradeUUPS is Script {
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        console.log("=== Starting UUPS Proxy Upgrade Process ===");
        console.log("Network Chain ID:", block.chainid);
        
        if (block.chainid == 11155111) {
            upgradeSepoliaContracts();
        } else if (block.chainid == 31337) {
            upgradeAnvilContracts();
        } else {
            revert("Unsupported network");
        }
        
        console.log("=== Upgrade Process Completed ===");
    }
    
    function upgradeSepoliaContracts() internal {
        uint256 deployerKey;
        try vm.envUint("SEPOLIA_PRIVATE_KEY") returns (uint256 key) {
            deployerKey = key;
        } catch {
            revert("SEPOLIA_PRIVATE_KEY environment variable not set");
        }
        
        console.log("=== Upgrading Sepolia Contracts ===");
        
        // Get proxy addresses from HelperConfig
        console.log("Getting proxy addresses from HelperConfig...");
        HelperConfig helperConfig = new HelperConfig();
        SharedStructs.NetworkConfig memory config = helperConfig.deploySepoliaContracts();
        
        console.log("Found proxy addresses:");
        console.log("Rights Manager Proxy:", address(config.proxies.rightsManager));
        console.log("Claims Registry Proxy:", address(config.proxies.claimsRegistry));
        console.log("Trust Contract Proxy:", address(config.proxies.trustContract));
        console.log("QTSP Contract 1 Proxy:", address(config.proxies.qtspContract1));
        console.log("QTSP Contract 2 Proxy:", address(config.proxies.qtspContract2));
        console.log("OVER_18 Token Proxy:", address(config.proxies.over18Token));
        console.log("EU_CITIZEN Token Proxy:", address(config.proxies.euCitizenToken));
        
        vm.startBroadcast(deployerKey);
        
        // Deploy new implementation contracts one by one to avoid memory issues
        console.log("Deploying new implementation contracts...");
        
        console.log("Deploying new QTSP Rights Manager implementation...");
        QTSPRightsManager newRightsManagerImpl = new QTSPRightsManager();
        
        console.log("Deploying new Claims Registry Contract implementation...");
        ClaimsRegistryContract newClaimsRegistryImpl = new ClaimsRegistryContract();
        
        console.log("Deploying new Trust Smart Contract implementation...");
        TrustSmartContract newTrustContractImpl = new TrustSmartContract();
        
        console.log("Deploying new QTSP Contract 1 implementation...");
        QTSPContract newQtspContract1Impl = new QTSPContract();
        
        console.log("Deploying new QTSP Contract 2 implementation...");
        QTSPContract newQtspContract2Impl = new QTSPContract();
        
        console.log("Deploying new OVER_18 Token implementation...");
        ClaimToken newOver18TokenImpl = new ClaimToken();
        
        console.log("Deploying new EU_CITIZEN Token implementation...");
        ClaimToken newEuCitizenTokenImpl = new ClaimToken();
        
        // Upgrade implementations
        console.log("Upgrading QTSP Rights Manager...");
        config.proxies.rightsManager.upgradeToAndCall(address(newRightsManagerImpl), "");
        
        console.log("Upgrading Claims Registry Contract...");
        config.proxies.claimsRegistry.upgradeToAndCall(address(newClaimsRegistryImpl), "");
        
        console.log("Upgrading Trust Smart Contract...");
        config.proxies.trustContract.upgradeToAndCall(address(newTrustContractImpl), "");
        
        console.log("Upgrading QTSP Contract 1...");
        config.proxies.qtspContract1.upgradeToAndCall(address(newQtspContract1Impl), "");
        
        console.log("Upgrading QTSP Contract 2...");
        config.proxies.qtspContract2.upgradeToAndCall(address(newQtspContract2Impl), "");
        
        console.log("Upgrading OVER_18 Token...");
        config.proxies.over18Token.upgradeToAndCall(address(newOver18TokenImpl), "");
        
        console.log("Upgrading EU_CITIZEN Token...");
        config.proxies.euCitizenToken.upgradeToAndCall(address(newEuCitizenTokenImpl), "");
        
        vm.stopBroadcast();
        
        console.log("=== Sepolia Contracts Upgraded Successfully ===");
        logUpgradeSummary(
            newRightsManagerImpl,
            newClaimsRegistryImpl,
            newTrustContractImpl,
            newQtspContract1Impl,
            newQtspContract2Impl,
            newOver18TokenImpl,
            newEuCitizenTokenImpl
        );
    }
    
    function upgradeAnvilContracts() internal {
        console.log("=== Upgrading Anvil Contracts ===");
        
        // Get proxy addresses from HelperConfig
        console.log("Getting proxy addresses from HelperConfig...");
        HelperConfig helperConfig = new HelperConfig();
        SharedStructs.NetworkConfig memory config = helperConfig.getOrCreateNetworkConfig();
        
        console.log("Found proxy addresses:");
        console.log("Rights Manager Proxy:", address(config.proxies.rightsManager));
        console.log("Claims Registry Proxy:", address(config.proxies.claimsRegistry));
        console.log("Trust Contract Proxy:", address(config.proxies.trustContract));
        console.log("QTSP Contract 1 Proxy:", address(config.proxies.qtspContract1));
        console.log("QTSP Contract 2 Proxy:", address(config.proxies.qtspContract2));
        console.log("OVER_18 Token Proxy:", address(config.proxies.over18Token));
        console.log("EU_CITIZEN Token Proxy:", address(config.proxies.euCitizenToken));
        
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
        
        // Deploy new implementation contracts one by one to avoid memory issues
        QTSPRightsManager newRightsManagerImpl = new QTSPRightsManager();
        ClaimsRegistryContract newClaimsRegistryImpl = new ClaimsRegistryContract();
        TrustSmartContract newTrustContractImpl = new TrustSmartContract();
        QTSPContract newQtspContract1Impl = new QTSPContract();
        QTSPContract newQtspContract2Impl = new QTSPContract();
        ClaimToken newOver18TokenImpl = new ClaimToken();
        ClaimToken newEuCitizenTokenImpl = new ClaimToken();
        
        // Upgrade implementations
        config.proxies.rightsManager.upgradeToAndCall(address(newRightsManagerImpl), "");
        config.proxies.claimsRegistry.upgradeToAndCall(address(newClaimsRegistryImpl), "");
        config.proxies.trustContract.upgradeToAndCall(address(newTrustContractImpl), "");
        config.proxies.qtspContract1.upgradeToAndCall(address(newQtspContract1Impl), "");
        config.proxies.over18Token.upgradeToAndCall(address(newOver18TokenImpl), "");
        config.proxies.euCitizenToken.upgradeToAndCall(address(newEuCitizenTokenImpl), "");
        
        vm.stopBroadcast();


        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY2);

        config.proxies.qtspContract2.upgradeToAndCall(address(newQtspContract2Impl), "");

        vm.stopBroadcast();
        
        console.log("=== Anvil Contracts Upgraded Successfully ===");
        logUpgradeSummary(
            newRightsManagerImpl,
            newClaimsRegistryImpl,
            newTrustContractImpl,
            newQtspContract1Impl,
            newQtspContract2Impl,
            newOver18TokenImpl,
            newEuCitizenTokenImpl
        );
    }
    
    function logUpgradeSummary(
        QTSPRightsManager newRightsManagerImpl,
        ClaimsRegistryContract newClaimsRegistryImpl,
        TrustSmartContract newTrustContractImpl,
        QTSPContract newQtspContract1Impl,
        QTSPContract newQtspContract2Impl,
        ClaimToken newOver18TokenImpl,
        ClaimToken newEuCitizenTokenImpl
    ) internal pure {
        console.log("=== Upgrade Summary ===");
        console.log("New QTSP Rights Manager Implementation:", address(newRightsManagerImpl));
        console.log("New Claims Registry Contract Implementation:", address(newClaimsRegistryImpl));
        console.log("New Trust Smart Contract Implementation:", address(newTrustContractImpl));
        console.log("New QTSP Contract 1 Implementation:", address(newQtspContract1Impl));
        console.log("New QTSP Contract 2 Implementation:", address(newQtspContract2Impl));
        console.log("New OVER_18 Token Implementation:", address(newOver18TokenImpl));
        console.log("New EU_CITIZEN Token Implementation:", address(newEuCitizenTokenImpl));
    }
}
