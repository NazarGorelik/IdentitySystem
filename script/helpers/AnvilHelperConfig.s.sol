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
    address private DEPLOYER_PUBLIC_KEY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private DEPLOYER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address private MOCK_DEPLOYER_PUBLIC_KEY = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 private MOCK_DEPLOYER_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address private TEST_USER = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

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
        
        generateTestSignatures(newConfig);
        activeNetworkConfig = newConfig;

        return newConfig;
    }
    
    function _deployAnvilImplementations() private returns (SharedStructs.ImplementationConfig memory) {
        // Start broadcast for contract deployments
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        
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
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        
        ERC1967Proxy rightsManagerProxy = _deployRightsManagerProxy(impls.rightsManagerImpl, DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy claimsRegistryProxy = _deployClaimsRegistryProxy(impls.claimsRegistryImpl, DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy trustContractProxy = _deployTrustContractProxy(impls.trustContractImpl, address(rightsManagerProxy), address(claimsRegistryProxy), DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy qtspContract1Proxy = _deployQTSPContract1Proxy(impls.qtspContract1Impl, address(claimsRegistryProxy), DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy qtspContract2Proxy = _deployQTSPContract2Proxy(impls.qtspContract2Impl, address(claimsRegistryProxy), MOCK_DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy over18TokenProxy = _deployOver18TokenProxy(impls.over18TokenImpl, address(rightsManagerProxy), DEPLOYER_PUBLIC_KEY);
        ERC1967Proxy euCitizenTokenProxy = _deployEuCitizenTokenProxy(impls.euCitizenTokenImpl, address(rightsManagerProxy), DEPLOYER_PUBLIC_KEY);
        
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
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        
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

    function generateTestSignatures(SharedStructs.NetworkConfig memory config) internal view {
        console.log("========================");
        console.log("\n=== Generating Test Signatures for Anvil ===");

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
    ) internal view {
        // Create the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(TEST_USER, claimType));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(DEPLOYER_PRIVATE_KEY, ethSignedMessageHash);
        
        // Create proper 65-byte signature
        bytes memory signature = abi.encodePacked(r, s, v);
        
        console.log("---", claimName, "Claim ---");
        console.log("QTSP Contract:", qtspContract);
        console.log("Test User:", TEST_USER);
        console.log("Claim Type:", vm.toString(claimType));
        console.log("Signature:", vm.toString(signature));
        console.log("");
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
