// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/FeatureTypes.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: PGNLZ
@Date: 2026-01-27
@Attacker: 0xFE95ECc0795399662221AB48948CDcF3f6D4AA86
@Target: 0x0000000000000000000000000000000000000000
@TxHash: 0xc7270212846136f3d103d1802a30cdaa6f8f280c4bce02240e99806101e08121
@ChainId: 56
@GasUsed: 3050246
*/

abstract contract PGNLZBase is BaseTest {
    function setUp() public virtual {
        vm.createSelectFork("bsc", 77721026);
        target = 0x0000000000000000000000000000000000000000;
        txHash = 0xc7270212846136f3d103d1802a30cdaa6f8f280c4bce02240e99806101e08121;
    }
}
