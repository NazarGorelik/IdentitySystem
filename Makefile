# Identity System Makefile
# This Makefile provides commands for interacting with the Identity System contracts
# on both Anvil (local) and Sepolia (testnet) networks

# =============================================================================
# CONFIGURATION VARIABLES
# =============================================================================

# Anvil Configuration
ANVIL_RPC_URL = http://127.0.0.1:8545
ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Sepolia Configuration (set these in your .env)
# SEPOLIA_RPC_URL="your_sepolia_rpc_url"
# Sepolia Configuration (set these in your keystore)
# export SEPOLIA_PRIVATE_KEY="your_sepolia_private_key"

# Import environment variables from .env file (if it exists)
-include .env
export $(shell sed 's/=.*//' .env 2>/dev/null || true)

# Contract Addresses - Pass these as parameters when running commands
# =============================================================================
# ANVIL CONTRACT ADDRESSES (Pass as parameters)
# =============================================================================
# Example: make anvil-issue-over18-token ANVIL_QTSP_CONTRACT_1=0x1234...
# Example: make anvil-access-age-restricted ANVIL_RESTRICTED_CONTRACT=0x5678...

# =============================================================================
# SEPOLIA CONTRACT ADDRESSES (Pass as parameters)
# =============================================================================
# Example: make sepolia-issue-over18-token SEPOLIA_QTSP_CONTRACT_1=0x1234...
# Example: make sepolia-access-age-restricted SEPOLIA_RESTRICTED_CONTRACT=0x5678...

# Test User Addresses
ANVIL_TEST_USER = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
SEPOLIA_TEST_USER = 0x242DDa6Dc21bbf23D77575697C19cFAeA1e14489

# Claim Hashes
OVER_18_CLAIM = 0x1b6c0c6d8737f44f75fe21c0970c4440531d01cdef329d4ef309e823c42e0678
EU_CITIZEN_CLAIM = 0x1b6c0c6d8737f44f75fe21c0970c4440531d01cdef329d4ef309e823c42e0678

# =============================================================================
# ANVIL COMMANDS
# =============================================================================

.PHONY: anvil-deploy
anvil-deploy:
	@echo "Deploying contracts to Anvil..."
	forge script script/Deploy.s.sol --rpc-url $(ANVIL_RPC_URL) --broadcast --private-key $(ANVIL_PRIVATE_KEY)

.PHONY: anvil-get-implementation
anvil-get-implementation:
	@echo "Getting implementation address for proxy..."
	@echo "Usage: make anvil-get-implementation PROXY_ADDRESS=<proxy_address>"
	@if [ -z "$(PROXY_ADDRESS)" ]; then echo "Error: PROXY_ADDRESS not set"; exit 1; fi
	cast storage $(PROXY_ADDRESS) 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $(ANVIL_RPC_URL)

.PHONY: anvil-issue-over18-token
anvil-issue-over18-token:
	@echo "Issuing OVER_18 token to test user..."
	@echo "Usage: make anvil-issue-over18-token ANVIL_QTSP_CONTRACT_1=<address>"
	@if [ -z "$(ANVIL_QTSP_CONTRACT_1)" ]; then echo "Error: ANVIL_QTSP_CONTRACT_1 not set"; exit 1; fi
	cast send $(ANVIL_QTSP_CONTRACT_1) "issueToken(address,bytes32,bytes)" $(ANVIL_TEST_USER) $(OVER_18_CLAIM) 0x4cb69294f82974f06df9ff8667a93766f9d76ae9ddda83c55674b905352953691d3f7c65653820e2a64c8ac2e0d6cb11dd540366b0dd1fa93f1c49ec9b7b68651c --private-key $(ANVIL_PRIVATE_KEY) --rpc-url $(ANVIL_RPC_URL)

.PHONY: anvil-revoke-over18-token
anvil-revoke-over18-token:
	@echo "Revoking OVER_18 token from test user..."
	@echo "Usage: make anvil-revoke-over18-token ANVIL_QTSP_CONTRACT_1=<address>"
	@if [ -z "$(ANVIL_QTSP_CONTRACT_1)" ]; then echo "Error: ANVIL_QTSP_CONTRACT_1 not set"; exit 1; fi
	cast send $(ANVIL_QTSP_CONTRACT_1) "revokeToken(address,bytes32)" $(ANVIL_TEST_USER) $(OVER_18_CLAIM) --private-key $(ANVIL_PRIVATE_KEY) --rpc-url $(ANVIL_RPC_URL)

.PHONY: anvil-access-age-restricted
anvil-access-age-restricted:
	@echo "Accessing age-restricted service..."
	@echo "Usage: make anvil-access-age-restricted ANVIL_RESTRICTED_CONTRACT=<address>"
	@if [ -z "$(ANVIL_RESTRICTED_CONTRACT)" ]; then echo "Error: ANVIL_RESTRICTED_CONTRACT not set"; exit 1; fi
	cast send $(ANVIL_RESTRICTED_CONTRACT) "accessAgeRestrictedService(address)" $(ANVIL_TEST_USER) --private-key $(ANVIL_PRIVATE_KEY) --rpc-url $(ANVIL_RPC_URL)

.PHONY: anvil-check-age-access
anvil-check-age-access:
	@echo "Checking if user can access service..."
	@echo "Usage: make anvil-check-access ANVIL_RESTRICTED_CONTRACT=<address>"
	@if [ -z "$(ANVIL_RESTRICTED_CONTRACT)" ]; then echo "Error: ANVIL_RESTRICTED_CONTRACT not set"; exit 1; fi
	cast call $(ANVIL_RESTRICTED_CONTRACT) "canAccessService(address,bytes32)" $(ANVIL_TEST_USER) $(OVER_18_CLAIM) --rpc-url $(ANVIL_RPC_URL)

#make anvil-test-workflow ANVIL_QTSP_CONTRACT_1=.. ANVIL_RESTRICTED_CONTRACT=..
.PHONY: anvil-test-workflow
anvil-test-workflow:
	@echo "Running complete test workflow on Anvil..."
	@echo "1. Issuing OVER_18 token..."
	@$(MAKE) anvil-issue-over18-token
	@echo "2. Checking access..."
	@$(MAKE) anvil-check-age-access
	@echo "3. Accessing age-restricted service..."
	@$(MAKE) anvil-access-age-restricted
	@echo "4. Revoke OVER_18 token..."
	@$(MAKE) anvil-revoke-over18-token
	@echo "5. Checking access..."
	@$(MAKE) anvil-check-age-access

# =============================================================================
# SEPOLIA COMMANDS
# =============================================================================

.PHONY: sepolia-deploy
sepolia-deploy:
	@echo "Deploying contracts to Sepolia..."
	forge script script/Deploy.s.sol --rpc-url $(SEPOLIA_RPC_URL) --account SEPOLIA_PRIVATE_KEY --sender 0xE6654Db73881ff06904FF4D1dCAf578b454d9bA4 --broadcast -vvv

.PHONY: sepolia-get-implementation
sepolia-get-implementation:
	@echo "Getting implementation address for proxy..."
	@echo "Usage: make sepolia-get-implementation PROXY_ADDRESS=<proxy_address>"
	@if [ -z "$(PROXY_ADDRESS)" ]; then echo "Error: PROXY_ADDRESS not set"; exit 1; fi
	cast storage $(PROXY_ADDRESS) 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $(SEPOLIA_RPC_URL)

.PHONY: sepolia-issue-over18-token
sepolia-issue-over18-token:
	@echo "Issuing OVER_18 token to test user..."
	@echo "Usage: make sepolia-issue-over18-token SEPOLIA_QTSP_CONTRACT_1=<address>"
	@if [ -z "$(SEPOLIA_QTSP_CONTRACT_1)" ]; then echo "Error: SEPOLIA_QTSP_CONTRACT_1 not set"; exit 1; fi
	cast send $(SEPOLIA_QTSP_CONTRACT_1) "issueToken(address,bytes32,bytes)" $(SEPOLIA_TEST_USER) $(OVER_18_CLAIM) $(SIGNATURE) --account SEPOLIA_PRIVATE_KEY --rpc-url $(SEPOLIA_RPC_URL)

.PHONY: sepolia-revoke-over18-token
sepolia-revoke-over18-token:
	@echo "Revoking OVER_18 token from test user..."
	@echo "Usage: make sepolia-revoke-over18-token SEPOLIA_QTSP_CONTRACT_1=<address>"
	@if [ -z "$(SEPOLIA_QTSP_CONTRACT_1)" ]; then echo "Error: SEPOLIA_QTSP_CONTRACT_1 not set"; exit 1; fi
	cast send $(SEPOLIA_QTSP_CONTRACT_1) "revokeToken(address,bytes32)" $(SEPOLIA_TEST_USER) $(OVER_18_CLAIM) --account SEPOLIA_PRIVATE_KEY --rpc-url $(SEPOLIA_RPC_URL)

.PHONY: sepolia-access-age-restricted
sepolia-access-age-restricted:
	@echo "Accessing age-restricted service..."
	@echo "Usage: make sepolia-access-age-restricted SEPOLIA_RESTRICTED_CONTRACT=<address>"
	@if [ -z "$(SEPOLIA_RESTRICTED_CONTRACT)" ]; then echo "Error: SEPOLIA_RESTRICTED_CONTRACT not set"; exit 1; fi
	cast send $(SEPOLIA_RESTRICTED_CONTRACT) "accessAgeRestrictedService(address)" $(SEPOLIA_TEST_USER) --account SEPOLIA_PRIVATE_KEY --rpc-url $(SEPOLIA_RPC_URL)

.PHONY: sepolia-check-age-access
sepolia-check-age-access:
	@echo "Checking if user can access OVER_18 service..."
	@echo "Usage: make sepolia-check-age-access SEPOLIA_RESTRICTED_CONTRACT=<address>"
	@if [ -z "$(SEPOLIA_RESTRICTED_CONTRACT)" ]; then echo "Error: SEPOLIA_RESTRICTED_CONTRACT not set"; exit 1; fi
	cast call $(SEPOLIA_RESTRICTED_CONTRACT) "canAccessService(address,bytes32)" $(SEPOLIA_TEST_USER) $(OVER_18_CLAIM) --rpc-url $(SEPOLIA_RPC_URL)

#make sepolia-test-workflow SEPOLIA_QTSP_CONTRACT_1=.. SEPOLIA_RESTRICTED_CONTRACT=.. SIGNATURE=..
.PHONY: sepolia-test-workflow
sepolia-test-workflow:
	@echo "Running complete test workflow on Sepolia..."
	@echo "1. Issuing OVER_18 token..."
	@$(MAKE) sepolia-issue-over18-token
	@echo "2. Checking access..."
	@$(MAKE) sepolia-check-age-access
	@echo "3. Accessing age-restricted service..."
	@$(MAKE) sepolia-access-age-restricted
	@echo "4. Revoke OVER_18 token..."
	@$(MAKE) sepolia-revoke-over18-token
	@echo "5. Checking access..."
	@$(MAKE) sepolia-check-age-access

# =============================================================================
# UTILITY COMMANDS
# =============================================================================

.PHONY: help
help:
	@echo "Identity System Makefile Commands"
	@echo "=================================="
	@echo ""
	@echo "ANVIL COMMANDS (Local Development):"
	@echo "  anvil-deploy                   - Deploy all contracts to Anvil"
	@echo "  anvil-get-implementation       - Get implementation address for proxy"
	@echo "  anvil-issue-over18-token       - Issue OVER_18 token to test user"
	@echo "  anvil-revoke-over18-token      - Revoke OVER_18 token from test user"
	@echo "  anvil-access-age-restricted    - Access age-restricted service"
	@echo "  anvil-check-age-access         - Check if user can access OVER_18 service"
	@echo "  anvil-test-workflow            - Run complete test workflow"
	@echo ""
	@echo "SEPOLIA COMMANDS (Testnet):"
	@echo "  sepolia-deploy                 - Deploy all contracts to Sepolia"
	@echo "  sepolia-get-implementation     - Get implementation address for proxy"
	@echo "  sepolia-issue-over18-token     - Issue OVER_18 token to test user"
	@echo "  sepolia-revoke-over18-token    - Revoke OVER_18 token from test user"
	@echo "  sepolia-access-age-restricted  - Access age-restricted service"
	@echo "  sepolia-check-age-access       - Check if user can access OVER_18 service"
	@echo "  sepolia-test-workflow          - Run complete test workflow"
	@echo ""
	@echo "UTILITY COMMANDS:"
	@echo "  help                           - Show this help message"
	@echo "  clean                          - Clean build artifacts"
	@echo ""
	@echo "SETUP INSTRUCTIONS:"
	@echo "1. Run deployment commands to deploy contracts"
	@echo "2. Copy contract addresses from deployment output"
	@echo "3. Pass addresses as parameters when running commands"
	@echo "4. Ensure SEPOLIA_RPC_URL and SEPOLIA_PRIVATE_KEY are set in .env file or keystore"
	@echo ""
	@echo "EXAMPLE USAGE:"
	@echo "  make anvil-deploy"
	@echo "  make anvil-issue-over18-token ANVIL_QTSP_CONTRACT_1=0x1234..."
	@echo "  make anvil-access-age-restricted ANVIL_RESTRICTED_CONTRACT=0x5678..."
	@echo "  make anvil-revoke-over18-token ANVIL_QTSP_CONTRACT_1=0x1234..."
	@echo ""
	@echo "  make sepolia-deploy"
	@echo "  make sepolia-issue-over18-token SEPOLIA_QTSP_CONTRACT_1=0x1234..."
	@echo "  make sepolia-access-age-restricted SEPOLIA_RESTRICTED_CONTRACT=0x5678..."

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	forge clean

.PHONY: build
build:
	@echo "Building contracts..."
	forge build

.PHONY: test
test:
	@echo "Running tests..."
	forge test

.PHONY: test-verbose
test-verbose:
	@echo "Running tests with verbose output..."
	forge test -vvv
