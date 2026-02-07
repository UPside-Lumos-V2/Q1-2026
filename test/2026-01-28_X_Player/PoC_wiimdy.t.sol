// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./X_PlayerBase.sol";

contract PoC_wiimdy is X_PlayerBase {
    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.UNKNOWN);
        addAttackVector(AttackVector.UNKNOWN);
        addMitigation(Mitigation.UNKNOWN);
    }
}
