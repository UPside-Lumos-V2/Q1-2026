// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/interfaces.sol";

/*
┌─────────────────────────────────────────────────────────────────────┐
│  CrossCurve (EYWA) Bridge Exploit — 2026-02-01                     │
│                                                                     │
│  취약점: Axelar GMP SDK의 expressExecute() 호출자 검증 부재          │
│  공격자가 위조된 크로스체인 메시지로 PortalV2에서 토큰 unlock         │
│                                                                     │
│  MethodID: 0x65657636                                               │
│  expressExecute(bytes32,string,string,bytes)                        │
│                                                                     │
│  Phalcon: 공격 tx에서 EYWA ~10억개 탈취 확인                         │
│  ExpressExecuted 이벤트 → sourceChain: "berachain" (위조)            │
└─────────────────────────────────────────────────────────────────────┘
*/

// ==================== 분류 태깅 enum ====================
enum VulnerabilityType {
    NONE,
    REENTRANCY,
    INTEGER_OVERFLOW,
    ACCESS_CONTROL,
    PRICE_MANIPULATION,
    FLASH_LOAN,
    LOGIC_ERROR,
    OTHER
}

enum AttackVector {
    NONE,
    DIRECT_THEFT,
    PRICE_DISTORTION,
    FLASH_LOAN_ATTACK,
    GOVERNANCE_ATTACK,
    INSECURE_INTERFACE,
    REPLAY_ATTACK,
    OTHER
}

enum Mitigation {
    NONE,
    INPUT_VALIDATION,
    ACCESS_CONTROL,
    REENTRANCY_GUARD,
    PRICE_ORACLE,
    TIMELOCK,
    PAUSE_MECHANISM,
    OTHER
}

// ==================== 커스텀 인터페이스 ====================
interface IAxelarExecutor {
    function expressExecute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external;
}

// ==================== Base 컨트랙트 ====================
abstract contract IncidentBase is BaseTest {
    // ==================== 주소 상수 ====================
    address constant AXELAR_EXECUTOR =
        0xB2185950F5A0A46687ac331916508aadA202e063;
    address constant EYWA_TOKEN = 0x8cb8C4263EB26b2349d74ea2cB1B27bc40709e12;
    address constant ATTACKER_EOA = 0x632400F42e96A5DEB547a179ca46b02C22CD25cD;
    address constant FAKE_SOURCE = 0x5eEdDcE72530e4fC96d43E3d70Fe09aD0D037175;

    // ==================== 상태 변수 ====================
    bytes32 txHash; // upstream BaseTest에 없으므로 여기서 선언

    // 분류 태깅 (exploit modifier에서 사용)
    VulnerabilityType[] private _vulnerabilities;
    AttackVector[] private _attackVectors;
    Mitigation[] private _mitigations;

    struct ProfitEntry {
        address token;
        uint256 amount;
    }
    ProfitEntry[] private _profits;

    // ==================== 인터페이스 바인딩 ====================
    IAxelarExecutor executor = IAxelarExecutor(AXELAR_EXECUTOR);
    IERC20 eywa = IERC20(EYWA_TOKEN);

    // ==================== setUp ====================
    function setUp() public virtual {
        vm.createSelectFork("mainnet", 24363853);

        target = AXELAR_EXECUTOR;
        txHash = bytes32(
            0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2
        );
        fundingToken = EYWA_TOKEN;

        vm.label(AXELAR_EXECUTOR, "Axelar Executor");
        vm.label(EYWA_TOKEN, "EYWA Token");
        vm.label(ATTACKER_EOA, "Attacker EOA");
        vm.label(FAKE_SOURCE, "Fake Source (Berachain)");
    }

    // ==================== 분류 태깅 함수 ====================
    function addVulnerability(VulnerabilityType v) internal {
        _vulnerabilities.push(v);
    }
    function addAttackVector(AttackVector a) internal {
        _attackVectors.push(a);
    }
    function addMitigation(Mitigation m) internal {
        _mitigations.push(m);
    }
    function addProfit(address token, uint256 amount) internal {
        _profits.push(ProfitEntry(token, amount));
    }

    // ==================== 토큰 헬퍼 ====================
    function _getTokenData(
        address token,
        address account
    )
        internal
        view
        returns (string memory symbol, uint256 balance, uint8 decimals)
    {
        if (token == address(0)) {
            symbol = getChainSymbol(block.chainid);
            balance = account.balance;
            decimals = 18;
        } else {
            try IERC20(token).symbol() returns (string memory s) {
                symbol = s;
            } catch {
                symbol = "???";
            }
            balance = IERC20(token).balanceOf(account);
            try IERC20(token).decimals() returns (uint8 d) {
                decimals = d;
            } catch {
                decimals = 18;
            }
        }
    }

    function _logTokenBalance(
        address token,
        address account,
        string memory label
    ) internal {
        (string memory symbol, uint256 balance, uint8 decimals) = _getTokenData(
            token,
            account
        );
        emit log_named_decimal_uint(
            string(abi.encodePacked(label, " ", symbol, " Balance")),
            balance,
            decimals
        );
    }

    // ==================== 결과 출력 (로그 전용, vm.writeFile 미사용) ====================
    function _writeExecutionResult(
        string memory tag,
        uint256 gasUsed,
        uint256 profit,
        string memory symbol,
        uint8 decimals
    ) internal {
        emit log_named_string("Tag", tag);
        emit log_named_uint("Gas Used", gasUsed);
        emit log_named_decimal_uint(
            string(abi.encodePacked("Profit (", symbol, ")")),
            profit,
            decimals
        );
    }

    function _writePartialResult(
        string memory tag,
        string memory reason,
        uint256 gasUsed
    ) internal {
        emit log_named_string("Tag", tag);
        emit log_named_string("Revert Reason", reason);
        emit log_named_uint("Gas Used", gasUsed);
    }

    // ==================== exploit modifier ====================
    modifier exploit() {
        address user = beneficiary == address(0) ? address(this) : beneficiary;
        uint256 gasBefore = gasleft();
        vm.deal(user, 0);

        _;

        uint256 gasUsed = gasBefore - gasleft();

        // 결과 로깅 (vm.writeFile 미사용 — foundry.toml에서 write 미허용)
        (string memory symbol, uint256 balance, uint8 decimals) = _getTokenData(
            fundingToken,
            user
        );
        emit log_named_uint("[EXPLOIT] Gas Used", gasUsed);
        emit log_named_decimal_uint(
            string(abi.encodePacked("[EXPLOIT] Final Balance (", symbol, ")")),
            balance,
            decimals
        );

        for (uint256 i = 0; i < _profits.length; i++) {
            (string memory sym, , uint8 dec) = _getTokenData(
                _profits[i].token,
                user
            );
            emit log_named_decimal_uint(
                string(abi.encodePacked("[EXPLOIT] Profit (", sym, ")")),
                _profits[i].amount,
                dec
            );
        }

        delete _vulnerabilities;
        delete _attackVectors;
        delete _mitigations;
        delete _profits;
    }
}
