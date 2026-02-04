// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./Aperture_FinanceBase.sol";

contract PoC_Ham3798 is Aperture_FinanceBase {
    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.UNKNOWN);
        addAttackVector(AttackVector.UNKNOWN);
        addMitigation(Mitigation.UNKNOWN);
    }
}
