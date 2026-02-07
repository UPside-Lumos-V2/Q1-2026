// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/FeatureTypes.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: SwapNet
@Date: 2026-01-25
@Attacker: 0x6cAad74121bF602e71386505A4687f310e0D833e
@Target: 0x0000000000000000000000000000000000000000
@TxHash: 0xc15df1d131e98d24aa0f107a67e33e66cf2ea27903338cc437a3665b6404dd57
@ChainId: 8453
@GasUsed: 518705
*/

abstract contract SwapNetBase is BaseTest {
    function setUp() public virtual {
        vm.createSelectFork("base", 41289840);
        target = 0x0000000000000000000000000000000000000000;
        txHash = 0xc15df1d131e98d24aa0f107a67e33e66cf2ea27903338cc437a3665b6404dd57;
    }
}
