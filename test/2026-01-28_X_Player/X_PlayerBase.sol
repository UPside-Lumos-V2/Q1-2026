// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/FeatureTypes.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: X Player
@Date: 2026-01-28
@Attacker: 0x9dF9A1D108EE9c667070514b9A238B724a86094F
@Target: 0x80bd723DC38A07952dB40C1C2A45084714399bD9
@TxHash: 0x9779341b2b80ba679c83423c93ecfc2ebcec82f9f94c02624f83d8a647ee2e49
@ChainId: 56
@GasUsed: 2148945
*/

abstract contract X_PlayerBase is BaseTest {
    function setUp() public virtual {
        vm.createSelectFork("bsc", 77915281);
        target = 0x80bd723DC38A07952dB40C1C2A45084714399bD9;
        txHash = 0x9779341b2b80ba679c83423c93ecfc2ebcec82f9f94c02624f83d8a647ee2e49;
    }
}
