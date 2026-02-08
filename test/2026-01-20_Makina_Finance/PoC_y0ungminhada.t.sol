// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./Makina_FinanceBase.sol";

contract PoC_y0ungminhada is Makina_FinanceBase {
    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.UNKNOWN);
        addAttackVector(AttackVector.UNKNOWN);
        addMitigation(Mitigation.UNKNOWN);
    }
}
