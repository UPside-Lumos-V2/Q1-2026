// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./SwapNet.sol";

contract PoC_Ham3798 is SwapNetBase {
    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.UNKNOWN);
        addAttackVector(AttackVector.UNKNOWN);
        addMitigation(Mitigation.UNKNOWN);
    }
}
