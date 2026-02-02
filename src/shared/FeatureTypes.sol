// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Technical vulnerability symptom (what went wrong)
enum VulnerabilityType {
    UNKNOWN,
    REENTRANCY,
    ORACLE_MANIPULATION,
    FLASH_LOAN,
    ACCESS_CONTROL,
    INTEGER_OVERFLOW,
    LOGIC_ERROR,
    GOVERNANCE,
    FRONT_RUNNING,
    SIGNATURE_REPLAY,
    PRICE_MANIPULATION,
    UNINITIALIZED_PROXY,
    STORAGE_COLLISION
}

/// @notice Attack vector combining interaction pattern and revenue path
/// @dev Based on DeFiTail (interaction) and SCONE-bench (monetization) research
enum AttackVector {
    UNKNOWN,
    // === Interaction Patterns (DeFiTail) ===
    REPETITION_ABUSE, // Flash loan atomic repetition to drain liquidity
    UNSAFE_EXTERNAL_CALL, // Unintended external call hijacking execution
    SIGNATURE_COLLISION, // 4-byte function signature collision exploit
    INSECURE_INTERFACE, // ERC interface misuse (approvals, callbacks)
    UNRESTRICTED_TRANSFER, // Missing sender validation on transfers

    // === Revenue Paths (SCONE-bench) ===
    DIRECT_THEFT, // Direct balance drain to attacker wallet
    PRICE_DISTORTION, // Oracle/AMM price manipulation for arbitrage
    TOKEN_INFLATION, // Mint/reward abuse then dump
    FEE_EXTRACTION, // Protocol fee hijacking
    COLLATERAL_DRAIN, // Lending protocol collateral manipulation
    GOVERNANCE_TAKEOVER // Vote/proposal manipulation for fund extraction
}

/// @notice Defense mechanism that could have mitigated the attack
/// @dev Helps protocol designers understand effective countermeasures
enum Mitigation {
    UNKNOWN,
    PAUSABLE, // GlobalPause could have stopped it
    RATE_LIMITABLE, // Withdrawal limits could reduce damage
    BLACKLISTABLE, // Address blacklist could block attacker
    CIRCUIT_BREAKER, // ERC-7265 style circuit breaker effective
    TIMELOCK_EFFECTIVE, // Timelock delay could have prevented
    INPUT_VALIDATION, // Better input validation needed
    ACCESS_CONTROL, // Proper access modifiers needed
    REENTRANCY_GUARD, // ReentrancyGuard would prevent
    ORACLE_HARDENING, // TWAP or multiple oracle sources needed
    NONE_EFFECTIVE // No simple mitigation available
}
