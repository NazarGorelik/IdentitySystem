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

contract SepoliaHelperConfig is Script {
    string private sepoliaKeyAlias = "SEPOLIA_PRIVATE_KEY";
    address private DEFAULT_ANVIL_ADDRESS1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private DEFAULT_ANVIL_ADDRESS2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;


    function getSepoliaEthConfig() public pure returns (SharedStructs.NetworkConfig memory) {
        return SharedStructs.NetworkConfig({
            implementations: SharedStructs.ImplementationConfig({
                rightsManagerImpl: QTSPRightsManager(address(0)),
                claimsRegistryImpl: ClaimsRegistryContract(address(0)),
                trustContractImpl: TrustSmartContract(address(0)),
                qtspContract1Impl: QTSPContract(address(0)),
                qtspContract2Impl: QTSPContract(address(0)),
                over18TokenImpl: ClaimToken(address(0)),
                euCitizenTokenImpl: ClaimToken(address(0)),
                restrictedContractImpl: RestrictedSmartContract(address(0))
            }),
            proxies: SharedStructs.ProxyConfig({
                rightsManager: QTSPRightsManager(address(0)),
                claimsRegistry: ClaimsRegistryContract(address(0)),
                trustContract: TrustSmartContract(address(0)),
                qtspContract1: QTSPContract(address(0)),
                qtspContract2: QTSPContract(address(0)),
                over18Token: ClaimToken(address(0)),
                euCitizenToken: ClaimToken(address(0)),
                restrictedContract: RestrictedSmartContract(address(0))
            })
        });
    }

    function deploySepoliaContracts() public returns (SharedStructs.NetworkConfig memory) {
        uint256 deployerKey = _getSepoliaDeployerKey();
        
        SharedStructs.ImplementationConfig memory impls = _deploySepoliaImplementations();
        SharedStructs.ProxyConfig memory proxies = _deploySepoliaProxies(impls, deployerKey);
        _setupSepoliaPermissions(proxies);
        
        SharedStructs.NetworkConfig memory newConfig = SharedStructs.NetworkConfig({
            implementations: impls,
            proxies: proxies
        });
        
        return newConfig;
    }
    
    function _getSepoliaDeployerKey() private view returns (uint256) {
        try vm.envUint(sepoliaKeyAlias) returns (uint256 key) {
            return key;
        } catch {
            revert("SEPOLIA_PRIVATE_KEY environment variable not set");
        }
    }
    
    function _deploySepoliaImplementations() private returns (SharedStructs.ImplementationConfig memory) {
        vm.startBroadcast();
        
        QTSPRightsManager rightsManagerImpl = new QTSPRightsManager();
        ClaimsRegistryContract claimsRegistryImpl = new ClaimsRegistryContract();
        TrustSmartContract trustContractImpl = new TrustSmartContract();
        QTSPContract qtspContract1Impl = new QTSPContract();
        QTSPContract qtspContract2Impl = new QTSPContract();
        ClaimToken over18TokenImpl = new ClaimToken();
        ClaimToken euCitizenTokenImpl = new ClaimToken();
        RestrictedSmartContract restrictedContractImpl = new RestrictedSmartContract(
            address(0), // Will be set after proxy deployment
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
    
    function _deploySepoliaProxies(SharedStructs.ImplementationConfig memory impls, uint256 deployerKey) private returns (SharedStructs.ProxyConfig memory) {
        vm.startBroadcast();
        
        ERC1967Proxy rightsManagerProxy = _deployRightsManagerProxySepolia(impls.rightsManagerImpl, deployerKey);
        ERC1967Proxy claimsRegistryProxy = _deployClaimsRegistryProxySepolia(impls.claimsRegistryImpl, deployerKey);
        ERC1967Proxy trustContractProxy = _deployTrustContractProxySepolia(impls.trustContractImpl, address(rightsManagerProxy), deployerKey);
        ERC1967Proxy qtspContract1Proxy = _deployQTSPContract1ProxySepolia(impls.qtspContract1Impl, address(claimsRegistryProxy), deployerKey);
        ERC1967Proxy qtspContract2Proxy = _deployQTSPContract2ProxySepolia(impls.qtspContract2Impl, address(claimsRegistryProxy), deployerKey);
        ERC1967Proxy over18TokenProxy = _deployOver18TokenProxySepolia(impls.over18TokenImpl, address(rightsManagerProxy), deployerKey);
        ERC1967Proxy euCitizenTokenProxy = _deployEuCitizenTokenProxySepolia(impls.euCitizenTokenImpl, address(rightsManagerProxy), deployerKey);
        
        RestrictedSmartContract restrictedContract = new RestrictedSmartContract(
            address(claimsRegistryProxy),
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
    
    // Sepolia-specific proxy deployment functions (for private key usage)
    function _deployRightsManagerProxySepolia(QTSPRightsManager impl, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPRightsManager.initialize.selector, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployClaimsRegistryProxySepolia(ClaimsRegistryContract impl, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimsRegistryContract.initialize.selector, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployTrustContractProxySepolia(TrustSmartContract impl, address rightsManager, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(TrustSmartContract.initialize.selector, rightsManager, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployQTSPContract1ProxySepolia(QTSPContract impl, address claimsRegistry, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployQTSPContract2ProxySepolia(QTSPContract impl, address claimsRegistry, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployOver18TokenProxySepolia(ClaimToken impl, address rightsManager, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.OVER_18, rightsManager, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployEuCitizenTokenProxySepolia(ClaimToken impl, address rightsManager, uint256 deployerKey) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.EU_CITIZEN, rightsManager, deployerKey);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _setupSepoliaPermissions(SharedStructs.ProxyConfig memory proxies) private {
        vm.startBroadcast();
        
        // Register claim tokens
        ClaimsRegistryContract(address(proxies.claimsRegistry)).registerClaimToken(
            ClaimsRegistry.OVER_18, 
            address(proxies.over18Token)
        );
        ClaimsRegistryContract(address(proxies.claimsRegistry)).registerClaimToken(
            ClaimsRegistry.EU_CITIZEN, 
            address(proxies.euCitizenToken)
        );
        
        // Setup QTSP permissions
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract1), 
            DEFAULT_ANVIL_ADDRESS1
        );
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract2), 
            DEFAULT_ANVIL_ADDRESS2
        );
        QTSPRightsManager(address(proxies.rightsManager)).addQTSPContractToClaim(
            address(proxies.qtspContract1), 
            ClaimsRegistry.OVER_18
        );
        QTSPRightsManager(address(proxies.rightsManager)).addQTSPContractToClaim(
            address(proxies.qtspContract2), 
            ClaimsRegistry.EU_CITIZEN
        );
        
        vm.stopBroadcast();
    }
}
