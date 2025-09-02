// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../../src/ClaimManagement/ClaimsRegistryContract.sol";
import "../../src/ClaimManagement/ClaimToken.sol";
import "../../src/QTSPManagement/QTSPRightsManager.sol";
import "../../src/QTSPManagement/QTSPContract.sol";
import "../../src/TrustSmartContract.sol";
import "../../src/RestrictedSmartContract.sol";

/**
 * @title SharedStructs
 * @dev Shared struct definitions for all helper config contracts
 */
library SharedStructs {
    struct NetworkConfig {
        ImplementationConfig implementations;
        ProxyConfig proxies;
    }
    
    struct ImplementationConfig {
        QTSPRightsManager rightsManagerImpl;
        ClaimsRegistryContract claimsRegistryImpl;
        TrustSmartContract trustContractImpl;
        QTSPContract qtspContract1Impl;
        QTSPContract qtspContract2Impl;
        ClaimToken over18TokenImpl;
        ClaimToken euCitizenTokenImpl;
        RestrictedSmartContract restrictedContractImpl;
    }
    
    struct ProxyConfig {
        QTSPRightsManager rightsManager;
        ClaimsRegistryContract claimsRegistry;
        TrustSmartContract trustContract;
        QTSPContract qtspContract1;
        QTSPContract qtspContract2;
        ClaimToken over18Token;
        ClaimToken euCitizenToken;
        RestrictedSmartContract restrictedContract;
    }
}
