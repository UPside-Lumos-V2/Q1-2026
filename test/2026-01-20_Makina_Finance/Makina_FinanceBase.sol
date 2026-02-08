// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/FeatureTypes.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: Makina Finance
@Date: 2026-01-20
@Attacker: 0x935bfb495E33f74d2E9735DF1DA66acE442ede48
@Target: 0x935bfb495E33f74d2E9735DF1DA66acE442ede48
@TxHash: 0x569733b8016ef9418f0b6bde8c14224d9e759e79301499908ecbcd956a0651f5
@ChainId: 1
@GasUsed: 4709593
*/

abstract contract Makina_FinanceBase is BaseTest {
    function setUp() public virtual {
        vm.createSelectFork("mainnet", 24273361);
        target = 0x935bfb495E33f74d2E9735DF1DA66acE442ede48;
        txHash = 0x569733b8016ef9418f0b6bde8c14224d9e759e79301499908ecbcd956a0651f5;
    }
}
