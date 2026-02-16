# CrossCurve (EYWA) Bridge Exploit — 2026-02-01

## 1. 사건 개요

| 항목 | 내용 |
|---|---|
| **프로토콜** | CrossCurve (구 EYWA.fi) — Curve 기반 크로스체인 유동성 프로토콜 |
| **날짜** | 2026-02-01 18:38:23 UTC |
| **체인** | Ethereum Mainnet (+ BSC, Arbitrum 등 멀티체인 피해) |
| **피해 규모** | ~$3,000,000 (1차) + $140,762 (2차 봇 추가 탈취) |
| **Tx Hash** | `0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2` |
| **Block** | 24363854 |
| **Gas Used** | 618,071 |

---

## 2. 관련 주소

| 역할 | 주소 | 비고 |
|---|---|---|
| **공격자 EOA** | `0x632400F42e96A5DEB547a179ca46b02C22CD25cD` | 직접 tx 서명 |
| **타겟 (Axelar Executor)** | `0xB2185950F5A0A46687ac331916508aadA202e063` | `expressExecute()` 호출 대상 |
| **ReceiverAxelar** | Axelar Executor를 통해 호출됨 | 실제 취약 컨트랙트 |
| **PortalV2 (Eywa CLP Portal)** | 토큰 보관 컨트랙트 | unlock으로 자금 유출 |
| **EYWA 토큰** | `0x8cb8c4263eb26b2349d74ea2cb1b27bc40709e12` | 주 탈취 토큰 |
| **Berachain 소스 주소** | `0x5eEdDcE72530e4fC96d43E3d70Fe09aD0D037175` | 위조된 소스 체인 주소 |

---

## 3. 취약점 분석

### 3.1 근본 원인: Axelar GMP SDK `expressExecute` 검증 부재

CrossCurve는 크로스체인 메시지 전달에 **Axelar General Message Passing (GMP)** SDK v5.10.0을 사용했다.

핵심 취약점은 `AxelarExpressExecutable` 컨트랙트의 `expressExecute()` 함수에 **호출자 검증 로직이 없었다**는 것이다.

```
정상 흐름:
  Axelar Gateway → validateContractCall() → execute() → PortalV2.unlock()
  (게이트웨이가 메시지 출처를 검증)

공격 흐름:
  공격자 EOA → expressExecute() → PortalV2.unlock()
  (게이트웨이 검증 우회, 누구나 직접 호출 가능)
```

### 3.2 expressExecute의 설계 결함

`expressExecute`는 원래 "빠른 실행"을 위한 기능으로, Axelar 릴레이어 확인 전에 자금을 미리 보내주는 역할이었다. 하지만:

1. **공개 호출 가능**: 누구나 `expressExecute(commandId, sourceChain, sourceAddress, payload)`를 호출할 수 있었음
2. **Gateway 검증 스킵**: 정상 `execute()`와 달리, gateway의 `validateContractCall()`을 호출하지 않음
3. **Payload 위조 가능**: `sourceChain`, `sourceAddress`, `payload`를 공격자가 임의로 조작 가능

### 3.3 공격 흐름 (단계별)

```
1. 공격자가 악의적 payload를 조작
   - sourceChain: "berachain" (위조)
   - sourceAddress: 0x5eEdDcE7... (위조)
   - payload: PortalV2.unlock()을 트리거하는 데이터

2. Axelar Executor (0xB218...)의 expressExecute() 직접 호출
   - Gateway 검증 없이 즉시 실행됨

3. ReceiverAxelar가 payload를 디코딩 → PortalV2.unlock() 호출

4. PortalV2에서 공격자에게 토큰 전송
   - ~999,787,453 EYWA → 공격자
   - ~99,989 EYWA → 추가 주소

5. 반복하여 다른 체인의 자산도 탈취
```

---

## 4. 탈취 자산 상세

CrossCurve 공식 트윗(26/2/3)에서 공개한 피해 목록:

| 자산 | 수량 | 비고 |
|---|---|---|
| EYWA (Mainnet) | ~1,000,000,000 | 거래소 동결로 일부 무력화 |
| USDT | ~$815,000 | |
| WETH | 123 ETH | |
| CRV | 239,000 | |
| USDC | 미공개 | |
| USDB | 미공개 | |
| frxUSD | 미공개 | |
| **2차 봇 탈취** | $140,762 | 26/2/4 추가 공개 |

---

## 5. 사후 대응 타임라인

| 날짜 | 행동 |
|---|---|
| 2/1 | @DefimonAlerts 경고, 커뮤니티 최초 감지 |
| 2/2 | CrossCurve 공식 확인, 브릿지 긴급 중단, 사용자 상호작용 중단 요청 |
| 2/2 | 10% 화이트햇 바운티 제안 (72시간 기한), 공격자 주소 공개 |
| 2/2 | EYWA 토큰 동결 (XT거래소 협조), Arbitrum EYWA는 안전 확인 |
| 2/3 | 탈취 금액 상세 공개 |
| 2/4 | 봇에 의한 추가 탈취 $140,762 공개 |
| 2/5 | MixBytes 기술 분석 공개 — Axelar GMP SDK v5.10.0의 설계 결함 지적 |
| 2/6 | Treasury Grant Program(TGP) 발표 — 프로토콜 수익 + 재단 토큰 3년 락업으로 복구 |
| 2/13 | Aggregator 서비스 재개, Token/Consensus 브릿지는 여전히 중단 |

---

## 6. 분류 태깅 (BaseTest용)

```solidity
addVulnerability(VulnerabilityType.ACCESS_CONTROL);
// expressExecute()에 호출자 검증 없음

addAttackVector(AttackVector.INSECURE_INTERFACE);
// 공개(public) 함수를 통한 직접 호출, 메시지 위조

addMitigation(Mitigation.ACCESS_CONTROL);
// Gateway 검증을 expressExecute에도 적용했어야 함
```

---

## 7. PoC 작성 힌트

Phalcon/Etherscan에서 확인한 핵심 데이터:

```
Function: expressExecute(bytes32 commandId, string sourceChain, string sourceAddress, bytes payload)
MethodID: 0x65657636

To: 0xB2185950F5A0A46687ac331916508aadA202e063 (Axelar Executor)
From: 0x632400F42e96A5DEB547a179ca46b02C22CD25cD (Attacker)

결과:
  - ~999,787,453 EYWA → 공격자
  - 기타 토큰 탈취
```

**PoC 전략**:
1. Block 24363853 (공격 직전)에서 Mainnet 포크
2. `expressExecute()`를 위조 payload로 호출
3. EYWA 토큰 잔액 변동 확인

---

## 8. 참고 자료

- [DefimonAlerts 최초 경고](https://x.com/DefimonAlerts/status/2018055069762240741)
- [CrossCurve 공식 확인](https://x.com/crosscurvefi/status/2018063302199488687)
- [자금 반환 요청](https://x.com/crosscurvefi/status/2018091623909835018)
- [토큰 보완 조치](https://x.com/crosscurvefi/status/2018245440693477778)
- [탈취 금액 공개](https://x.com/crosscurvefi/status/2018350044001321401)
- [추가 봇 탈취](https://x.com/crosscurvefi/status/2018710180867850659)
- [MixBytes 기술 분석](https://x.com/MixBytes/status/2019096786325983527)
- [TGP 복구 프로그램](https://x.com/crosscurvefi/status/2019475142594744611)
- [서비스 재개](https://x.com/crosscurvefi/status/2022244125702021379)
- [Etherscan Tx](https://etherscan.io/tx/0x37d9b911ef710be851a2e08e1cfc61c2544db0f208faeade29ee98cc7506ccc2)
