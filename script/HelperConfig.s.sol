// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import "../src/ClaimManagement/ClaimsRegistry.sol";
import "../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../src/ClaimManagement/ClaimToken.sol";
import "../src/QTSPManagement/QTSPRightsManager.sol";
import "../src/QTSPManagement/QTSPContract.sol";
import "../src/TrustSmartContract.sol";
import "../src/RestrictedSmartContract.sol";

contract HelperConfig is Script {
    string private sepoliaKeyAlias = "SEPOLIA_PRIVATE_KEY";
    address private DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    // Add private keys for Anvil addresses
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;


    struct NetworkConfig {
        QTSPRightsManager rightsManager;
        ClaimsRegistryContract claimsRegistry;
        TrustSmartContract trustContract;
        QTSPContract qtspContract1;
        QTSPContract qtspContract2;
        ClaimToken over18Token;
        ClaimToken euCitizenToken;
        RestrictedSmartContract restrictedContract;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        // sepolia chain id = 11155111
        // anvil chain id = 31337
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getSepoliaEthConfig(); // Use placeholder config initially
        } else {
            revert("Unsupported network");
        }
    }
    
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            rightsManager: QTSPRightsManager(address(0)), // Replace with deployed address
            claimsRegistry: ClaimsRegistryContract(address(0)), // Replace with deployed address
            trustContract: TrustSmartContract(address(0)), // Replace with deployed address
            qtspContract1: QTSPContract(address(0)), // Replace with deployed address
            qtspContract2: QTSPContract(address(0)), // Replace with deployed address
            over18Token: ClaimToken(address(0)), // Replace with deployed address
            euCitizenToken: ClaimToken(address(0)), // Replace with deployed address
            restrictedContract: RestrictedSmartContract(address(0)) // Replace with deployed address
        });
    }

    // Alternative function for Sepolia deployment
    function deploySepoliaContracts() public returns (NetworkConfig memory) {
        uint256 deployerKey;
        try vm.envUint(sepoliaKeyAlias) returns (uint256 key) {
            deployerKey = key;
        } catch {
            revert("SEPOLIA_PRIVATE_KEY environment variable not set");
        }
        
        vm.startBroadcast(deployerKey);
        
        // Deploy QTSP Rights Manager
        QTSPRightsManager rightsManager = new QTSPRightsManager();
        // Deploy Claims Registry Contract
        ClaimsRegistryContract claimsRegistry = new ClaimsRegistryContract();

        // Deploy Trust Smart Contract
        TrustSmartContract trustContract = new TrustSmartContract(address(rightsManager));

        // Deploy QTSP Contract1
        QTSPContract qtspContract1 = new QTSPContract(address(claimsRegistry), address(trustContract));

        // Deploy QTSP Contract2
        QTSPContract qtspContract2 = new QTSPContract(address(claimsRegistry), address(trustContract));

        // Deploy Claim Tokens
        ClaimToken over18Token = new ClaimToken(ClaimsRegistry.OVER_18, address(rightsManager));

        ClaimToken euCitizenToken = new ClaimToken(ClaimsRegistry.EU_CITIZEN, address(rightsManager));

        // Deploy Restricted Smart Contract
        RestrictedSmartContract restrictedContract = new RestrictedSmartContract(
            address(claimsRegistry),
            address(trustContract)
        );

        // Setup permissions and registrations
        claimsRegistry.registerClaimToken(ClaimsRegistry.OVER_18, address(over18Token));
        claimsRegistry.registerClaimToken(ClaimsRegistry.EU_CITIZEN, address(euCitizenToken));
        rightsManager.addTrustedQTSPContract(address(qtspContract1), DEFAULT_ANVIL_ADDRESS1);
        rightsManager.addTrustedQTSPContract(address(qtspContract2), DEFAULT_ANVIL_ADDRESS2);
        rightsManager.addQTSPContractToClaim(address(qtspContract1), ClaimsRegistry.OVER_18);
        rightsManager.addQTSPContractToClaim(address(qtspContract2), ClaimsRegistry.EU_CITIZEN);
        
        vm.stopBroadcast();
        
        NetworkConfig memory newConfig = NetworkConfig({
            rightsManager: rightsManager,
            claimsRegistry: claimsRegistry,
            trustContract: trustContract,
            qtspContract1: qtspContract1,
            qtspContract2: qtspContract2,
            over18Token: over18Token,
            euCitizenToken: euCitizenToken,
            restrictedContract: restrictedContract
        });
        
        // Update the active network config
        activeNetworkConfig = newConfig;
        
        return newConfig;
    }

    function getOrCreateNetworkConfig() public returns (NetworkConfig memory) {
        if (address(activeNetworkConfig.rightsManager) != address(0)) {
            return activeNetworkConfig;
        }
        
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
    
        // Deploy QTSP Rights Manager
        QTSPRightsManager rightsManager = new QTSPRightsManager();

        // Deploy Claims Registry Contract
        ClaimsRegistryContract claimsRegistry = new ClaimsRegistryContract();

        // Deploy Trust Smart Contract
        TrustSmartContract trustContract = new TrustSmartContract(address(rightsManager));

        // Deploy QTSP Contract 1 (deployed by DEAFULT_ANVIL_ADDRESS)
        QTSPContract qtspContract1 = new QTSPContract(address(claimsRegistry), address(trustContract));

        // Deploy Claim Tokens
        ClaimToken over18Token = new ClaimToken(ClaimsRegistry.OVER_18, address(rightsManager));
        ClaimToken euCitizenToken = new ClaimToken(ClaimsRegistry.EU_CITIZEN, address(rightsManager));

        // Deploy Restricted Smart Contract
        RestrictedSmartContract restrictedContract = new RestrictedSmartContract(
            address(claimsRegistry),
            address(trustContract)
        );
        
        vm.stopBroadcast();
        
        // Switch to second deployer for QTSP Contract 2
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY2);
        
        // Deploy QTSP Contract 2 (deployed by DEAFULT_ANVIL_ADDRESS2)
        QTSPContract qtspContract2 = new QTSPContract(address(claimsRegistry), address(trustContract));
        
        vm.stopBroadcast();

        // Switch back to first deployer for setup
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
        
        // Setup permissions and registrations
        claimsRegistry.registerClaimToken(ClaimsRegistry.OVER_18, address(over18Token));
        claimsRegistry.registerClaimToken(ClaimsRegistry.EU_CITIZEN, address(euCitizenToken));
        
        // Add QTSP Contract 1 with its owner (DEAFULT_ANVIL_ADDRESS1)
        rightsManager.addTrustedQTSPContract(address(qtspContract1), qtspContract1.owner());
        rightsManager.addQTSPContractToClaim(address(qtspContract1), ClaimsRegistry.OVER_18);
        
        // Add QTSP Contract 2 with its owner (DEAFULT_ANVIL_ADDRESS2)
        rightsManager.addTrustedQTSPContract(address(qtspContract2), qtspContract2.owner());
        rightsManager.addQTSPContractToClaim(address(qtspContract2), ClaimsRegistry.EU_CITIZEN);
        
        vm.stopBroadcast();

        NetworkConfig memory newConfig = NetworkConfig({
            rightsManager: rightsManager,
            claimsRegistry: claimsRegistry,
            trustContract: trustContract,
            qtspContract1: qtspContract1,
            qtspContract2: qtspContract2,
            over18Token: over18Token,
            euCitizenToken: euCitizenToken,
            restrictedContract: restrictedContract
        });
        
        // Update the active network config
        activeNetworkConfig = newConfig;
        
        return newConfig;
    }
    
    /**
     * @dev Get the current network configuration
     * @return The current network configuration
     */
    function getCurrentNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
    
    /**
     * @dev Check if contracts are already deployed
     * @return True if contracts are deployed, false otherwise
     */
    function isDeployed() public view returns (bool) {
        return address(activeNetworkConfig.rightsManager) != address(0);
    }
}