// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./IncidentBase.sol";

/*
┌─────────────────────────────────────────────────────────┐
│  CrossCurve Replay 테스트                                │
│  실제 공격 tx의 calldata를 그대로 재현                    │
│                                                         │
│  Input Data 소스:                                        │
│  Etherscan → Tx 0x37d9b9... → Input Data 복사            │
│                                                         │
│  실행:                                                   │
│  forge test --match-path test/2026-02-01_CrossCurve/Replay.t.sol -vvvv │
└─────────────────────────────────────────────────────────┘
*/

contract ReplayTest is IncidentBase {
    // 공격자 EOA
    address constant ATTACKER_ADDR = 0x632400F42e96A5DEB547a179ca46b02C22CD25cD;

    // 호출 대상: Axelar Executor
    address constant REPLAY_TARGET = 0xB2185950F5A0A46687ac331916508aadA202e063;

    bytes constant INPUT_DATA =
        "0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2"; // TODO: 실제 calldata로 교체

    function testReplay() public {
        beneficiary = ATTACKER_ADDR;

        // 추적할 토큰: EYWA
        _logTokenBalance(EYWA_TOKEN, beneficiary, "[REPLAY] Before");

        uint256 gasBefore = gasleft();
        try this._executeReplay() {
            uint256 gasUsed = gasBefore - gasleft();
            (
                string memory symbol,
                uint256 balance,
                uint8 decimals
            ) = _getTokenData(EYWA_TOKEN, beneficiary);
            _logTokenBalance(EYWA_TOKEN, beneficiary, "[REPLAY] After");
            _writeExecutionResult("REPLAY", gasUsed, balance, symbol, decimals);
        } catch Error(string memory reason) {
            uint256 gasUsed = gasBefore - gasleft();
            _writePartialResult("REPLAY_FAILED", reason, gasUsed);
            emit log_string(
                string(abi.encodePacked("[REPLAY] Reverted: ", reason))
            );
            revert(reason);
        } catch (bytes memory) {
            uint256 gasUsed = gasBefore - gasleft();
            _writePartialResult("REPLAY_FAILED", "Low-level revert", gasUsed);
            emit log_string("[REPLAY] Low-level revert");
            revert("Low-level revert");
        }
    }

    function _executeReplay() external {
        vm.startPrank(ATTACKER_ADDR);
        (bool success, bytes memory returnData) = REPLAY_TARGET.call(
            INPUT_DATA
        );
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            }
            revert("Replay failed");
        }
        vm.stopPrank();
    }
}
