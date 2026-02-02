// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TokenHelper.sol";
import "./FeatureTypes.sol";
import "forge-std/Test.sol";

contract BaseTest is Test {
    address fundingToken = address(0);
    address target = address(0);
    address beneficiary = address(0);

    // 3-Dimensional Classification (multiple selections supported)
    VulnerabilityType[] internal vulnerabilityTypes;
    AttackVector[] internal attackVectors;
    Mitigation[] internal mitigations;

    // Known storage slots to track (can be set by auditor before exploit)
    bytes32[] internal trackedSlots;

    // Profit records for multiple tokens
    struct ProfitRecord {
        address token;
        uint256 amount;
        string symbol;
        uint8 decimals;
    }
    ProfitRecord[] internal profitRecords;

    struct ChainInfo {
        string name;
        string symbol;
    }

    struct StorageDelta {
        bytes32 slot;
        bytes32 valueBefore;
        bytes32 valueAfter;
    }

    mapping(uint256 => ChainInfo) private chainIdToInfo;

    constructor() {
        chainIdToInfo[1] = ChainInfo("MAINNET", "ETH");
        chainIdToInfo[238] = ChainInfo("BLAST", "ETH");
        chainIdToInfo[10] = ChainInfo("OPTIMISM", "ETH");
        chainIdToInfo[250] = ChainInfo("FANTOM", "FTM");
        chainIdToInfo[42_161] = ChainInfo("ARBITRUM", "ETH");
        chainIdToInfo[56] = ChainInfo("BSC", "BNB");
        chainIdToInfo[1285] = ChainInfo("MOONRIVER", "MOVR");
        chainIdToInfo[100] = ChainInfo("GNOSIS", "XDAI");
        chainIdToInfo[43_114] = ChainInfo("AVALANCHE", "AVAX");
        chainIdToInfo[137] = ChainInfo("POLYGON", "MATIC");
        chainIdToInfo[42_220] = ChainInfo("CELO", "CELO");
        chainIdToInfo[8453] = ChainInfo("BASE", "ETH");
        chainIdToInfo[1329] = ChainInfo("SEI", "SEI");
    }

    function getChainSymbol(
        uint256 chainId
    ) internal view returns (string memory symbol) {
        symbol = chainIdToInfo[chainId].symbol;
        if (bytes(symbol).length == 0) symbol = "ETH";
    }

    function _getTokenData(
        address token,
        address account
    ) internal returns (string memory symbol, uint256 balance, uint8 decimals) {
        if (token == address(0)) {
            symbol = getChainSymbol(block.chainid);
            balance = account.balance;
            decimals = 18;
        } else {
            symbol = TokenHelper.getTokenSymbol(token);
            balance = TokenHelper.getTokenBalance(token, account);
            decimals = TokenHelper.getTokenDecimals(token);
        }
    }

    function _logTokenBalance(
        address token,
        address account,
        string memory label
    ) internal {
        (string memory symbol, uint256 balance, uint8 decimals) = _getTokenData(token, account);
        emit log_named_decimal_uint(string(abi.encodePacked(label, " ", symbol, " Balance")), balance, decimals);
    }

    // ==================== Enum to String Converters ====================

    function _vulnTypeToString(
        VulnerabilityType vuln
    ) internal pure returns (string memory) {
        if (vuln == VulnerabilityType.REENTRANCY) return "REENTRANCY";
        if (vuln == VulnerabilityType.ORACLE_MANIPULATION) return "ORACLE_MANIPULATION";
        if (vuln == VulnerabilityType.FLASH_LOAN) return "FLASH_LOAN";
        if (vuln == VulnerabilityType.ACCESS_CONTROL) return "ACCESS_CONTROL";
        if (vuln == VulnerabilityType.INTEGER_OVERFLOW) return "INTEGER_OVERFLOW";
        if (vuln == VulnerabilityType.LOGIC_ERROR) return "LOGIC_ERROR";
        if (vuln == VulnerabilityType.GOVERNANCE) return "GOVERNANCE";
        if (vuln == VulnerabilityType.FRONT_RUNNING) return "FRONT_RUNNING";
        if (vuln == VulnerabilityType.SIGNATURE_REPLAY) return "SIGNATURE_REPLAY";
        if (vuln == VulnerabilityType.PRICE_MANIPULATION) return "PRICE_MANIPULATION";
        if (vuln == VulnerabilityType.UNINITIALIZED_PROXY) return "UNINITIALIZED_PROXY";
        if (vuln == VulnerabilityType.STORAGE_COLLISION) return "STORAGE_COLLISION";
        return "UNKNOWN";
    }

    function _attackVectorToString(
        AttackVector vector
    ) internal pure returns (string memory) {
        // Interaction Patterns
        if (vector == AttackVector.REPETITION_ABUSE) return "REPETITION_ABUSE";
        if (vector == AttackVector.UNSAFE_EXTERNAL_CALL) return "UNSAFE_EXTERNAL_CALL";
        if (vector == AttackVector.SIGNATURE_COLLISION) return "SIGNATURE_COLLISION";
        if (vector == AttackVector.INSECURE_INTERFACE) return "INSECURE_INTERFACE";
        if (vector == AttackVector.UNRESTRICTED_TRANSFER) return "UNRESTRICTED_TRANSFER";
        // Revenue Paths
        if (vector == AttackVector.DIRECT_THEFT) return "DIRECT_THEFT";
        if (vector == AttackVector.PRICE_DISTORTION) return "PRICE_DISTORTION";
        if (vector == AttackVector.TOKEN_INFLATION) return "TOKEN_INFLATION";
        if (vector == AttackVector.FEE_EXTRACTION) return "FEE_EXTRACTION";
        if (vector == AttackVector.COLLATERAL_DRAIN) return "COLLATERAL_DRAIN";
        if (vector == AttackVector.GOVERNANCE_TAKEOVER) return "GOVERNANCE_TAKEOVER";
        return "UNKNOWN";
    }

    function _mitigationToString(
        Mitigation mit
    ) internal pure returns (string memory) {
        if (mit == Mitigation.PAUSABLE) return "PAUSABLE";
        if (mit == Mitigation.RATE_LIMITABLE) return "RATE_LIMITABLE";
        if (mit == Mitigation.BLACKLISTABLE) return "BLACKLISTABLE";
        if (mit == Mitigation.CIRCUIT_BREAKER) return "CIRCUIT_BREAKER";
        if (mit == Mitigation.TIMELOCK_EFFECTIVE) return "TIMELOCK_EFFECTIVE";
        if (mit == Mitigation.INPUT_VALIDATION) return "INPUT_VALIDATION";
        if (mit == Mitigation.ACCESS_CONTROL) return "ACCESS_CONTROL";
        if (mit == Mitigation.REENTRANCY_GUARD) return "REENTRANCY_GUARD";
        if (mit == Mitigation.ORACLE_HARDENING) return "ORACLE_HARDENING";
        if (mit == Mitigation.NONE_EFFECTIVE) return "NONE_EFFECTIVE";
        return "UNKNOWN";
    }

    // ==================== Result Writers ====================

    function _getOutputDir() internal view returns (string memory) {
        // Default to local directory
        string memory outputDir = "data/local/";
        // Check for CI environment variable
        try vm.envString("CI") returns (string memory val) {
            // Check if CI is set to "true"
            if (keccak256(abi.encodePacked(val)) == keccak256(abi.encodePacked("true"))) {
                outputDir = "data/verified/";
            }
        } catch {}
        return outputDir;
    }

    function _writeExecutionResult(
        string memory tag,
        uint256 gasUsed,
        uint256 profit,
        string memory symbol,
        uint8 decimals
    ) internal {
        string memory jsonObj = "result";

        vm.serializeString(jsonObj, "mode", tag);
        vm.serializeUint(jsonObj, "chain_id", block.chainid);
        vm.serializeUint(jsonObj, "block_number", block.number);
        vm.serializeUint(jsonObj, "block_timestamp", block.timestamp);
        vm.serializeUint(jsonObj, "gas_used", gasUsed);
        vm.serializeUint(jsonObj, "realized_profit", profit);
        vm.serializeString(jsonObj, "token_symbol", symbol);
        vm.serializeUint(jsonObj, "token_decimals", decimals);
        vm.serializeAddress(jsonObj, "token_address", fundingToken);

        uint256 victimCodeSize = target == address(0) ? 0 : target.code.length;
        vm.serializeUint(jsonObj, "victim_code_size", victimCodeSize);

        string memory finalJson = vm.serializeBool(jsonObj, "success", true);

        string memory fileName = string(
            abi.encodePacked(
                _getOutputDir(),
                "result_",
                tag,
                "_",
                vm.toString(block.timestamp),
                "_",
                vm.toString(block.number),
                ".json"
            )
        );

        vm.writeJson(finalJson, fileName);
    }

    function _writeExploitResult(
        string memory tag,
        uint256 gasUsed,
        StorageDelta[] memory deltas
    ) internal {
        string memory jsonObj = "result";

        // Basic info
        vm.serializeString(jsonObj, "mode", tag);
        vm.serializeUint(jsonObj, "chain_id", block.chainid);
        vm.serializeUint(jsonObj, "block_number", block.number);
        vm.serializeUint(jsonObj, "block_timestamp", block.timestamp);

        // === 3-Dimensional Classification (arrays) ===
        vm.serializeUint(jsonObj, "vulnerability_count", vulnerabilityTypes.length);
        vm.serializeUint(jsonObj, "attack_vector_count", attackVectors.length);
        vm.serializeUint(jsonObj, "mitigation_count", mitigations.length);

        // === Fingerprint (Auto-extracted) ===
        vm.serializeUint(jsonObj, "gas_used", gasUsed);
        vm.serializeUint(jsonObj, "storage_writes_count", deltas.length);
        uint256 victimCodeSize = target == address(0) ? 0 : target.code.length;
        vm.serializeUint(jsonObj, "victim_code_size", victimCodeSize);

        // === Target Info ===
        vm.serializeAddress(jsonObj, "target", target);

        // === Profit Data (multiple tokens) ===
        vm.serializeUint(jsonObj, "profit_count", profitRecords.length);

        string memory finalJson = vm.serializeBool(jsonObj, "success", true);

        string memory fileName = string(
            abi.encodePacked(
                _getOutputDir(),
                "result_",
                tag,
                "_",
                vm.toString(block.timestamp),
                "_",
                vm.toString(block.number),
                ".json"
            )
        );

        vm.writeJson(finalJson, fileName);

        // Write classification to separate file
        _writeClassification(tag);

        // Write storage deltas to separate file
        _writeStorageDeltas(tag, deltas);

        // Write profit records to separate file
        _writeProfitRecords(tag);
    }

    function _writeClassification(
        string memory tag
    ) internal {
        string memory vulnsJson = "[";
        for (uint256 i = 0; i < vulnerabilityTypes.length; i++) {
            if (i > 0) vulnsJson = string(abi.encodePacked(vulnsJson, ","));
            vulnsJson = string(
                abi.encodePacked(
                    vulnsJson,
                    '{"id":',
                    vm.toString(uint256(vulnerabilityTypes[i])),
                    ',"name":"',
                    _vulnTypeToString(vulnerabilityTypes[i]),
                    '"}'
                )
            );
        }
        vulnsJson = string(abi.encodePacked(vulnsJson, "]"));

        string memory vectorsJson = "[";
        for (uint256 i = 0; i < attackVectors.length; i++) {
            if (i > 0) vectorsJson = string(abi.encodePacked(vectorsJson, ","));
            vectorsJson = string(
                abi.encodePacked(
                    vectorsJson,
                    '{"id":',
                    vm.toString(uint256(attackVectors[i])),
                    ',"name":"',
                    _attackVectorToString(attackVectors[i]),
                    '"}'
                )
            );
        }
        vectorsJson = string(abi.encodePacked(vectorsJson, "]"));

        string memory mitsJson = "[";
        for (uint256 i = 0; i < mitigations.length; i++) {
            if (i > 0) mitsJson = string(abi.encodePacked(mitsJson, ","));
            mitsJson = string(
                abi.encodePacked(
                    mitsJson,
                    '{"id":',
                    vm.toString(uint256(mitigations[i])),
                    ',"name":"',
                    _mitigationToString(mitigations[i]),
                    '"}'
                )
            );
        }
        mitsJson = string(abi.encodePacked(mitsJson, "]"));

        string memory classFile = string(
            abi.encodePacked(_getOutputDir(), "classification_", tag, "_", vm.toString(block.timestamp), ".json")
        );
        string memory finalJson = string(
            abi.encodePacked(
                '{"vulnerabilities":', vulnsJson, ',"attack_vectors":', vectorsJson, ',"mitigations":', mitsJson, "}"
            )
        );
        vm.writeFile(classFile, finalJson);
    }

    function _writeProfitRecords(
        string memory tag
    ) internal {
        if (profitRecords.length == 0) return;

        string memory profitsJson = "[";
        for (uint256 i = 0; i < profitRecords.length; i++) {
            if (i > 0) profitsJson = string(abi.encodePacked(profitsJson, ","));
            profitsJson = string(
                abi.encodePacked(
                    profitsJson,
                    '{"token":"',
                    vm.toString(profitRecords[i].token),
                    '","symbol":"',
                    profitRecords[i].symbol,
                    '","amount":',
                    vm.toString(profitRecords[i].amount),
                    ',"decimals":',
                    vm.toString(profitRecords[i].decimals),
                    "}"
                )
            );
        }
        profitsJson = string(abi.encodePacked(profitsJson, "]"));

        string memory profitFile =
            string(abi.encodePacked(_getOutputDir(), "profits_", tag, "_", vm.toString(block.timestamp), ".json"));
        string memory finalJson = string(abi.encodePacked('{"profits":', profitsJson, "}"));
        vm.writeFile(profitFile, finalJson);
    }

    function _writeStorageDeltas(
        string memory tag,
        StorageDelta[] memory deltas
    ) internal {
        string memory deltasJson = "[";
        for (uint256 i = 0; i < deltas.length && i < 50; i++) {
            if (i > 0) deltasJson = string(abi.encodePacked(deltasJson, ","));
            deltasJson = string(
                abi.encodePacked(
                    deltasJson,
                    '{"slot":"',
                    vm.toString(deltas[i].slot),
                    '","before":"',
                    vm.toString(deltas[i].valueBefore),
                    '","after":"',
                    vm.toString(deltas[i].valueAfter),
                    '"}'
                )
            );
        }
        deltasJson = string(abi.encodePacked(deltasJson, "]"));

        string memory storageFile =
            string(abi.encodePacked(_getOutputDir(), "storage_", tag, "_", vm.toString(block.timestamp), ".json"));
        string memory storageJson = string(abi.encodePacked('{"deltas":', deltasJson, "}"));
        vm.writeFile(storageFile, storageJson);
    }

    /// @notice Write partial result when replay/exploit fails (reverts)
    /// @dev Captures available data even on failure for debugging
    function _writePartialResult(
        string memory tag,
        string memory revertReason,
        uint256 gasUsed
    ) internal {
        (string memory diagnosis, string memory guide) = _diagnoseRevert(revertReason);

        string memory jsonObj = "partial";

        vm.serializeString(jsonObj, "mode", tag);
        vm.serializeUint(jsonObj, "chain_id", block.chainid);
        vm.serializeUint(jsonObj, "block_number", block.number);
        vm.serializeUint(jsonObj, "block_timestamp", block.timestamp);
        vm.serializeBool(jsonObj, "success", false);

        vm.serializeString(jsonObj, "revert_reason", revertReason);
        vm.serializeString(jsonObj, "diagnosis", diagnosis);
        vm.serializeString(jsonObj, "guide", guide);

        vm.serializeUint(jsonObj, "gas_used", gasUsed);

        uint256 victimCodeSize = target == address(0) ? 0 : target.code.length;
        vm.serializeUint(jsonObj, "victim_code_size", victimCodeSize);

        vm.serializeAddress(jsonObj, "target", target);
        string memory finalJson = vm.serializeAddress(jsonObj, "beneficiary", beneficiary);

        string memory fileName = string(
            abi.encodePacked(
                _getOutputDir(),
                "partial_",
                tag,
                "_",
                vm.toString(block.timestamp),
                "_",
                vm.toString(block.number),
                ".json"
            )
        );

        vm.writeJson(finalJson, fileName);
    }

    /// @notice Diagnose revert reason and provide guidance
    /// @param reason The revert reason string
    /// @return diagnosis Human-readable diagnosis
    /// @return guide Suggested fix for the auditor
    function _diagnoseRevert(
        string memory reason
    ) internal pure returns (string memory diagnosis, string memory guide) {
        bytes memory reasonBytes = bytes(reason);

        // Check for common patterns
        if (_containsIgnoreCase(reasonBytes, "owner") || _containsIgnoreCase(reasonBytes, "Ownable")) {
            return ("Permission issue - caller is not the owner", "Use vm.prank(ownerAddress) to impersonate the owner");
        }
        if (
            _containsIgnoreCase(reasonBytes, "balance") || _containsIgnoreCase(reasonBytes, "insufficient")
                || _containsIgnoreCase(reasonBytes, "underflow")
        ) {
            return (
                "Insufficient balance or funds",
                "Use vm.deal(address, amount) for ETH or deal(token, address, amount) for ERC20"
            );
        }
        if (_containsIgnoreCase(reasonBytes, "allowance") || _containsIgnoreCase(reasonBytes, "approve")) {
            return ("Token allowance not set", "Call token.approve(spender, amount) before the exploit");
        }
        if (
            _containsIgnoreCase(reasonBytes, "time") || _containsIgnoreCase(reasonBytes, "lock")
                || _containsIgnoreCase(reasonBytes, "expired")
        ) {
            return ("Time-based restriction", "Use vm.warp(timestamp) to advance block time");
        }
        if (_containsIgnoreCase(reasonBytes, "paused") || _containsIgnoreCase(reasonBytes, "Paused")) {
            return ("Contract is paused", "Fork from a block before the pause, or use vm.store to modify pause state");
        }
        if (_containsIgnoreCase(reasonBytes, "blacklist") || _containsIgnoreCase(reasonBytes, "blocked")) {
            return ("Address is blacklisted", "Use a different address or vm.store to modify blacklist");
        }
        if (_containsIgnoreCase(reasonBytes, "reentrancy") || _containsIgnoreCase(reasonBytes, "ReentrancyGuard")) {
            return ("Reentrancy guard triggered", "The attack may require a different entry point");
        }

        // Default
        return (
            "Custom revert condition",
            "Analyze the target contract to understand the revert condition. Run forge test -vvvv for detailed trace."
        );
    }

    /// @notice Check if haystack contains needle (case-insensitive)
    function _containsIgnoreCase(
        bytes memory haystack,
        string memory needle
    ) internal pure returns (bool) {
        bytes memory needleBytes = bytes(needle);
        if (needleBytes.length > haystack.length) return false;

        for (uint256 i = 0; i <= haystack.length - needleBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                bytes1 h = haystack[i + j];
                bytes1 n = needleBytes[j];
                // Convert to lowercase for comparison
                if (h >= 0x41 && h <= 0x5A) h = bytes1(uint8(h) + 32);
                if (n >= 0x41 && n <= 0x5A) n = bytes1(uint8(n) + 32);
                if (h != n) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    // ==================== Modifiers ====================

    modifier balanceLog() {
        uint256 startGas = gasleft();
        address user = beneficiary == address(0) ? address(this) : beneficiary;
        (string memory symbol, uint256 startBalance, uint8 decimals) = _getTokenData(fundingToken, user);

        if (fundingToken == address(0)) vm.deal(user, 0);
        _logTokenBalance(fundingToken, user, "Before");

        _;

        uint256 gasUsed = startGas - gasleft();
        (,, uint256 endBalance) = _getTokenData(fundingToken, user);
        uint256 profit = endBalance > startBalance ? endBalance - startBalance : 0;

        _logTokenBalance(fundingToken, user, "After");
        _writeExecutionResult("DEFAULT", gasUsed, profit, symbol, decimals);
    }

    modifier recordMetrics(
        string memory tag
    ) {
        uint256 startGas = gasleft();
        address user = beneficiary == address(0) ? address(this) : beneficiary;
        (string memory symbol, uint256 startBalance, uint8 decimals) = _getTokenData(fundingToken, user);

        if (fundingToken == address(0)) vm.deal(user, 0);
        _logTokenBalance(fundingToken, user, string(abi.encodePacked("[", tag, "] Before")));

        _;

        uint256 gasUsed = startGas - gasleft();
        (,, uint256 endBalance) = _getTokenData(fundingToken, user);
        uint256 profit = endBalance > startBalance ? endBalance - startBalance : 0;

        _logTokenBalance(fundingToken, user, string(abi.encodePacked("[", tag, "] After")));
        _writeExecutionResult(tag, gasUsed, profit, symbol, decimals);
    }

    /// @notice Main exploit modifier - call addVulnerability(), addAttackVector(), addMitigation() inside
    modifier exploit() {
        uint256 startGas = gasleft();
        address user = beneficiary == address(0) ? address(this) : beneficiary;

        // Capture before values for tracked slots
        bytes32[] memory beforeValues = new bytes32[](trackedSlots.length);
        for (uint256 i = 0; i < trackedSlots.length; i++) {
            beforeValues[i] = vm.load(target, trackedSlots[i]);
        }

        vm.record();

        if (fundingToken == address(0)) vm.deal(user, 0);
        _logTokenBalance(fundingToken, user, "[EXPLOIT] Before");

        _;

        uint256 gasUsed = startGas - gasleft();

        // Get storage accesses and build deltas
        (, bytes32[] memory writes) = vm.accesses(target);

        // Merge tracked slots with written slots
        uint256 totalSlots = trackedSlots.length + writes.length;
        StorageDelta[] memory deltas = new StorageDelta[](totalSlots);
        uint256 idx = 0;

        // Add tracked slots with before/after values
        for (uint256 i = 0; i < trackedSlots.length; i++) {
            deltas[idx++] = StorageDelta({
                slot: trackedSlots[i], valueBefore: beforeValues[i], valueAfter: vm.load(target, trackedSlots[i])
            });
        }

        // Add written slots (before value unknown)
        for (uint256 i = 0; i < writes.length; i++) {
            deltas[idx++] =
                StorageDelta({slot: writes[i], valueBefore: bytes32(0), valueAfter: vm.load(target, writes[i])});
        }

        _logTokenBalance(fundingToken, user, "[EXPLOIT] After");
        _writeExploitResult("EXPLOIT", gasUsed, deltas);

        // Clear state for next test
        delete trackedSlots;
        delete profitRecords;
        delete vulnerabilityTypes;
        delete attackVectors;
        delete mitigations;
    }

    // ==================== Helper Functions ====================

    /// @notice Add storage slots to track before/after values
    function trackSlot(
        bytes32 slot
    ) internal {
        trackedSlots.push(slot);
    }

    /// @notice Add multiple storage slots to track
    function trackSlots(
        bytes32[] memory slots
    ) internal {
        for (uint256 i = 0; i < slots.length; i++) {
            trackedSlots.push(slots[i]);
        }
    }

    function logTokenBalance(
        address token,
        address account,
        string memory label
    ) internal {
        _logTokenBalance(token, account, label);
    }

    function logMultipleTokenBalances(
        address[] memory tokens,
        address account,
        string memory label
    ) internal {
        emit log_string(string(abi.encodePacked("=== ", label, " ===")));
        for (uint256 i = 0; i < tokens.length; i++) {
            _logTokenBalance(tokens[i], account, "");
        }
    }

    /// @notice Record profit for a specific token
    /// @param token Token address (address(0) for native ETH)
    /// @param amount Amount of profit in token's smallest unit
    function addProfit(
        address token,
        uint256 amount
    ) internal {
        (string memory symbol,, uint8 decimals) = _getTokenData(token, address(0));
        profitRecords.push(ProfitRecord({token: token, amount: amount, symbol: symbol, decimals: decimals}));
    }

    /// @notice Record profits for multiple tokens at once
    function addProfits(
        address[] memory tokens,
        uint256[] memory amounts
    ) internal {
        require(tokens.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            addProfit(tokens[i], amounts[i]);
        }
    }

    // ==================== Classification Helpers ====================

    /// @notice Add a vulnerability type (multiple allowed)
    function addVulnerability(
        VulnerabilityType vuln
    ) internal {
        vulnerabilityTypes.push(vuln);
    }

    /// @notice Add an attack vector (multiple allowed)
    function addAttackVector(
        AttackVector vector
    ) internal {
        attackVectors.push(vector);
    }

    /// @notice Add a mitigation (multiple allowed)
    function addMitigation(
        Mitigation mit
    ) internal {
        mitigations.push(mit);
    }
}
