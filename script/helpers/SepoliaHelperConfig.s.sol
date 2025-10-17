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

    uint256 private DEPLOYER_PRIVATE_KEY = vm.envUint("SEPOLIA_PRIVATE_KEY");
    address private DEPLOYER_ADDRESS = vm.addr(DEPLOYER_PRIVATE_KEY);
    uint256 private MOCK_DEPLOYER_PRIVATE_KEY = vm.envUint("MOCK_SEPOLIA_PRIVATE_KEY");
    address private MOCK_DEPLOYER_ADDRESS = vm.addr(MOCK_DEPLOYER_PRIVATE_KEY);
    address private TEST_USER = 0x242DDa6Dc21bbf23D77575697C19cFAeA1e14489;

    function deploySepoliaContracts() public returns (SharedStructs.NetworkConfig memory) {
        SharedStructs.ImplementationConfig memory impls = _deploySepoliaImplementations();
        SharedStructs.ProxyConfig memory proxies = _deploySepoliaProxies(impls);
        _setupSepoliaPermissions(proxies);
        
        SharedStructs.NetworkConfig memory newConfig = SharedStructs.NetworkConfig({
            implementations: impls,
            proxies: proxies
        });
        
        generateTestSignatures(newConfig);

        return newConfig;
    }
    
    function _deploySepoliaImplementations() private returns (SharedStructs.ImplementationConfig memory) {
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
    
    function _deploySepoliaProxies(SharedStructs.ImplementationConfig memory impls) private returns (SharedStructs.ProxyConfig memory) {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        ERC1967Proxy rightsManagerProxy = _deployRightsManagerProxySepolia(impls.rightsManagerImpl);
        ERC1967Proxy claimsRegistryProxy = _deployClaimsRegistryProxySepolia(impls.claimsRegistryImpl);
        ERC1967Proxy trustContractProxy = _deployTrustContractProxySepolia(impls.trustContractImpl, address(rightsManagerProxy), address(claimsRegistryProxy));
        ERC1967Proxy qtspContract1Proxy = _deployQTSPContract1ProxySepolia(impls.qtspContract1Impl, address(claimsRegistryProxy));
        ERC1967Proxy qtspContract2Proxy = _deployQTSPContract2ProxySepolia(impls.qtspContract2Impl, address(claimsRegistryProxy));
        ERC1967Proxy over18TokenProxy = _deployOver18TokenProxySepolia(impls.over18TokenImpl, address(rightsManagerProxy));
        ERC1967Proxy euCitizenTokenProxy = _deployEuCitizenTokenProxySepolia(impls.euCitizenTokenImpl, address(rightsManagerProxy));
        RestrictedSmartContract restrictedContract = new RestrictedSmartContract(address(trustContractProxy));
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
    function _deployRightsManagerProxySepolia(QTSPRightsManager impl) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPRightsManager.initialize.selector, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployClaimsRegistryProxySepolia(ClaimsRegistryContract impl) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimsRegistryContract.initialize.selector, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployTrustContractProxySepolia(TrustSmartContract impl, address rightsManager, address claimsRegistry) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(TrustSmartContract.initialize.selector, rightsManager, claimsRegistry, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployQTSPContract1ProxySepolia(QTSPContract impl, address claimsRegistry) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployQTSPContract2ProxySepolia(QTSPContract impl, address claimsRegistry) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(QTSPContract.initialize.selector, claimsRegistry, MOCK_DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployOver18TokenProxySepolia(ClaimToken impl, address rightsManager) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.OVER_18, rightsManager, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _deployEuCitizenTokenProxySepolia(ClaimToken impl, address rightsManager) private returns (ERC1967Proxy) {
        bytes memory data = abi.encodeWithSelector(ClaimToken.initialize.selector, ClaimsRegistry.EU_CITIZEN, rightsManager, DEPLOYER_ADDRESS);
        return new ERC1967Proxy(address(impl), data);
    }
    
    function _setupSepoliaPermissions(SharedStructs.ProxyConfig memory proxies) private {
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
        
        // Setup QTSP permissions
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract1), 
            proxies.qtspContract1.owner()
        );
        QTSPRightsManager(address(proxies.rightsManager)).addTrustedQTSPContract(
            address(proxies.qtspContract2), 
            proxies.qtspContract2.owner()
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

    function generateTestSignatures(SharedStructs.NetworkConfig memory config) internal view {
        console.log("========================");
        console.log("\n=== Generating Test Signatures for Anvil ===");
        
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
        
        console.log("=== Signature Generation Complete ===");
        console.log("Note: Use these signatures with the deployed QTSP contracts");
    }

    function generateSignatureForClaim(
        string memory claimName,
        bytes32 claimType,
        address qtspContract
    ) internal view {
        // Create the message hash (same as in TrustSmartContract)
        bytes32 messageHash = keccak256(abi.encodePacked(TEST_USER, claimType));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        console.log("---", claimName, "Claim ---");
        console.log("QTSP Contract:", qtspContract);
        console.log("Test User:", TEST_USER);
        console.log("Claim Type:", vm.toString(claimType));
        console.log("Message Hash:", vm.toString(messageHash));
        console.log("ETH Signed Message Hash:", vm.toString(ethSignedMessageHash));
        console.log("");
        console.log("Run this command to generate the signature:");
        console.log("cast wallet sign --no-hash", vm.toString(ethSignedMessageHash), "--account SEPOLIA_PRIVATE_KEY");
        console.log("");
    }
}