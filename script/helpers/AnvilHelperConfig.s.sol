// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ClaimManagement/ClaimsRegistry.sol";
import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/TrustSmartContract.sol";
import "../../src/RestrictedSmartContract.sol";
import "./SharedStructs.s.sol";

contract AnvilHelperConfig is Script {
    address private DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private DEFAULT_ANVIL_PRIVATE_KEY2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    SharedStructs.NetworkConfig public activeNetworkConfig;

    function getOrCreateAnvilNetworkConfig() public returns (SharedStructs.NetworkConfig memory) {
        if (address(activeNetworkConfig.proxies.rightsManager) != address(0)) {
            return activeNetworkConfig;
        }
        
        SharedStructs.ImplementationConfig memory impls = _deployAnvilImplementations();
        SharedStructs.ProxyConfig memory proxies = _deployAnvilProxies(impls);
        _setupAnvilPermissions(proxies);
        
        SharedStructs.NetworkConfig memory newConfig = SharedStructs.NetworkConfig({
            implementations: impls,
            proxies: proxies
        });
        
        activeNetworkConfig = newConfig;
        return newConfig;
    }
    
    function _deployAnvilImplementations() private returns (SharedStructs.ImplementationConfig memory) {
        // Start broadcast for contract deployments
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
        
        QTSPRightsManager rightsManagerImpl = new QTSPRightsManager();
        ClaimsRegistryContract claimsRegistryImpl = new ClaimsRegistryContract();
        TrustSmartContract trustContractImpl = new TrustSmartContract();
        QTSPContract qtspContract1Impl = new QTSPContract();
        QTSPContract qtspContract2Impl = new QTSPContract();
        ClaimToken over18TokenImpl = new ClaimToken();
        ClaimToken euCitizenTokenImpl = new ClaimToken();
        RestrictedSmartContract restrictedContractImpl = new RestrictedSmartContract(
            address(0)  // Will be set after proxy deployment
        );
        
        vm.stopBroadcast();
        
        return SharedStructs.ImplementationConfig({
            rightsManagerImpl: rightsManagerImpl,
            claimsRegistryImpl: claimsRegistryImpl,
            trustContractImpl: trustContractImpl,
            qtspContract1Impl: qtspContract1Impl,
            qtspContract2Impl: qtspContract2Impl,
            over18TokenImpl: over18TokenImpl,
            euCitizenTokenImpl: euCitizenTokenImpl,
            restrictedContractImpl: restrictedContractImpl
        });
    }
    
    function _deployAnvilProxies(SharedStructs.ImplementationConfig memory impls) private returns (SharedStructs.ProxyConfig memory) {
        // Start broadcast for proxy deployments
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
        
        ERC1967Proxy rightsManagerProxy = _deployRightsManagerProxy(impls.rightsManagerImpl, DEFAULT_ANVIL_ADDRESS1);
        ERC1967Proxy claimsRegistryProxy = _deployClaimsRegistryProxy(impls.claimsRegistryImpl, DEFAULT_ANVIL_ADDRESS1);
        ERC1967Proxy trustContractProxy = _deployTrustContractProxy(impls.trustContractImpl, address(rightsManagerProxy), address(claimsRegistryProxy), DEFAULT_ANVIL_ADDRESS1);
        ERC1967Proxy qtspContract1Proxy = _deployQTSPContract1Proxy(impls.qtspContract1Impl, address(claimsRegistryProxy), DEFAULT_ANVIL_ADDRESS1);
        ERC1967Proxy qtspContract2Proxy = _deployQTSPContract2Proxy(impls.qtspContract2Impl, address(claimsRegistryProxy), DEFAULT_ANVIL_ADDRESS2);
        ERC1967Proxy over18TokenProxy = _deployOver18TokenProxy(impls.over18TokenImpl, address(rightsManagerProxy), DEFAULT_ANVIL_ADDRESS1);
        ERC1967Proxy euCitizenTokenProxy = _deployEuCitizenTokenProxy(impls.euCitizenTokenImpl, address(rightsManagerProxy), DEFAULT_ANVIL_ADDRESS1);
        
        RestrictedSmartContract restrictedContract = new RestrictedSmartContract(
            address(trustContractProxy)
        );
        
        vm.stopBroadcast();
        
        return SharedStructs.ProxyConfig({
            rightsManager: QTSPRightsManager(address(rightsManagerProxy)),
            claimsRegistry: ClaimsRegistryContract(address(claimsRegistryProxy)),
            trustContract: TrustSmartContract(address(trustContractProxy)),
            qtspContract1: QTSPContract(address(qtspContract1Proxy)),
            qtspContract2: QTSPContract(address(qtspContract2Proxy)),
            over18Token: ClaimToken(address(over18TokenProxy)),
            euCitizenToken: ClaimToken(address(euCitizenTokenProxy)),
            restrictedContract: restrictedContract
        });
    }
    
    function _deployQTSPContract2Proxy(QTSPContract impl, address claimsRegistry, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployRightsManagerProxy(QTSPRightsManager impl, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPRightsManager.initialize.selector, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployClaimsRegistryProxy(ClaimsRegistryContract impl, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimsRegistryContract.initialize.selector, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployTrustContractProxy(TrustSmartContract impl, address rightsManager, address claimsRegistry, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(TrustSmartContract.initialize.selector, rightsManager, claimsRegistry, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployQTSPContract1Proxy(QTSPContract impl, address claimsRegistry, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployOver18TokenProxy(ClaimToken impl, address rightsManager, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.OVER_18, rightsManager, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployEuCitizenTokenProxy(ClaimToken impl, address rightsManager, address owner) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.EU_CITIZEN, rightsManager, owner);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _setupAnvilPermissions(SharedStructs.ProxyConfig memory proxies) private {
        vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY1);
        
        // Register claim tokens
        ClaimsRegistryContract(address(proxies.claimsRegistry)).registerClaimToken(
            ClaimsRegistry.OVER_18, 
            address(proxies.over18Token)
        );
        ClaimsRegistryContract(address(proxies.claimsRegistry)).registerClaimToken(
            ClaimsRegistry.EU_CITIZEN, 
            address(proxies.euCitizenToken)
        );
        
        // Add QTSP Contract 1 with its owner
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract1), 
            QTSPContract(address(proxies.qtspContract1)).owner()
        );
        QTSPRightsManager(address(proxies.rightsManager)).addQTSPContractToClaim(
            address(proxies.qtspContract1), 
            ClaimsRegistry.OVER_18
        );
        
        // Add QTSP Contract 2 with its owner
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract2), 
            QTSPContract(address(proxies.qtspContract2)).owner()
        );
        QTSPRightsManager(address(proxies.rightsManager)).addQTSPContractToClaim(
            address(proxies.qtspContract2), 
            ClaimsRegistry.EU_CITIZEN
        );
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Get the current network configuration
     * @return The current network configuration
     */
    function getCurrentNetworkConfig() public view returns (SharedStructs.NetworkConfig memory) {
        return activeNetworkConfig;
    }
    
    /**
     * @dev Check if contracts are already deployed
     * @return True if contracts are deployed, false otherwise
     */
    function isDeployed() public view returns (bool) {
        return address(activeNetworkConfig.proxies.rightsManager) != address(0);
    }
}
