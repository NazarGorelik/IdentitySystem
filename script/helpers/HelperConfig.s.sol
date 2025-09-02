// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import "./SepoliaHelperConfig.s.sol";
import "./AnvilHelperConfig.s.sol";
import "./SharedStructs.s.sol";

contract HelperConfig is Script {
    SepoliaHelperConfig public sepoliaHelper;
    AnvilHelperConfig public anvilHelper;
    
    using SharedStructs for SharedStructs.NetworkConfig;
    using SharedStructs for SharedStructs.ImplementationConfig;
    using SharedStructs for SharedStructs.ProxyConfig;

    SharedStructs.NetworkConfig public activeNetworkConfig;
    uint256 private currentChainId;

    constructor() {
        // Initialize helpers based on network - only check chain ID once
        currentChainId = block.chainid;
        if (currentChainId == 11155111) { // Sepolia
            sepoliaHelper = new SepoliaHelperConfig();
            // activeNetworkConfig will be set when deploySepoliaContracts() is called
        } else if (currentChainId == 31337) { // Anvil
            anvilHelper = new AnvilHelperConfig();
            // activeNetworkConfig will be set when getOrCreateAnvilNetworkConfig() is called
        } else {
            revert("Unsupported network");
        }
    }

    function getOrCreateNetworkConfig() public returns (SharedStructs.NetworkConfig memory) {
        // Use cached chain ID to avoid repeated block.chainid calls
        if (currentChainId == 31337) {
            require(address(anvilHelper) != address(0), "Anvil helper not initialized");
            activeNetworkConfig = anvilHelper.getOrCreateAnvilNetworkConfig();
            return activeNetworkConfig;
        } else {
            require(address(sepoliaHelper) != address(0), "Sepolia helper not initialized");
            activeNetworkConfig = sepoliaHelper.deploySepoliaContracts();
            return activeNetworkConfig;
        }
    }

    function deploySepoliaContracts() public returns (SharedStructs.NetworkConfig memory) {
        require(address(sepoliaHelper) != address(0), "Sepolia helper not initialized");
        activeNetworkConfig = sepoliaHelper.deploySepoliaContracts();
        return activeNetworkConfig;
    }
    
    /**
     * @dev Get the current network configuration
     * @return The current network configuration
     */
    function getCurrentNetworkConfig() public view returns (SharedStructs.NetworkConfig memory) {
        return activeNetworkConfig;
    }
    
    /**
     * @dev Get the current chain ID
     * @return The current chain ID
     */
    function getChainId() public view returns (uint256) {
        return currentChainId;
    }
    
    /**
     * @dev Check if contracts are already deployed
     * @return True if contracts are deployed, false otherwise
     */
    function isDeployed() public view returns (bool) {
        return address(activeNetworkConfig.proxies.rightsManager) != address(0);
    }
}
