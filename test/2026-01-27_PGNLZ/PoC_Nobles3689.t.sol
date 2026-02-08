// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./PGNLZBase.sol";

contract PoC_Nobles3689 is PGNLZBase {
    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.UNKNOWN);
        addAttackVector(AttackVector.UNKNOWN);
        addMitigation(Mitigation.UNKNOWN);
    }
}
