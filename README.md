# DeFi Security Incident Template

DeFi 해킹 사건 분석 및 ML 학습용 데이터셋 구축 템플릿.

## Quick Start

1. **Issue 생성**: `Security Incident` 템플릿으로 Protocol, Chain, Tx Hash 입력 + Assignee 지정
2. **브랜치 체크아웃**: `git fetch && git checkout incident/{date}_{protocol}`
3. **PoC 작성**: `PoC_{auditor}.t.sol` 수정
4. **테스트**: `forge test --match-contract PoC -vvv`
5. **결과**: `data/results/*.json`

## 분류 체계

3차원 분류 (DeFiTail + SCONE-bench 기반):

| 차원 | 설명 | 예시 |
|------|------|------|
| **VulnerabilityType** | 기술적 증상 | `REENTRANCY`, `FLASH_LOAN`, `ACCESS_CONTROL` |
| **AttackVector** | 공격 방식 + 수익화 | `REPETITION_ABUSE`, `PRICE_DISTORTION`, `DIRECT_THEFT` |
| **Mitigation** | 방어 기제 | `REENTRANCY_GUARD`, `ORACLE_HARDENING`, `PAUSABLE` |

## PoC 작성

```solidity
function testExploit() public exploit {
    // 분류 (복수 선택 가능)
    addVulnerability(VulnerabilityType.FLASH_LOAN);
    addVulnerability(VulnerabilityType.REENTRANCY);     // 복합 취약점
    
    addAttackVector(AttackVector.REPETITION_ABUSE);
    addAttackVector(AttackVector.PRICE_DISTORTION);     // 체인 공격
    
    addMitigation(Mitigation.ORACLE_HARDENING);
    addMitigation(Mitigation.REENTRANCY_GUARD);         // 복수 방어
    
    trackSlot(bytes32(uint256(0)));                     // 스토리지 추적
    
    // exploit 구현...
    
    // 수익 기록 (복수 토큰)
    addProfit(address(0), 100 ether);                   // ETH
    addProfit(USDC, 50_000e6);                          // USDC
}
```

## Replay 실패 시

| Revert | 해결 |
|--------|------|
| `Not Owner` | `vm.prank(owner)` |
| `Insufficient balance` | `vm.deal(addr, amt)` |
| `Allowance` | `token.approve()` |
| `Timelock` | `vm.warp(time)` |

실패해도 `partial_*.json`에 진단 정보 저장됨.

## 라벨

| 라벨 | 의미 |
|------|------|
| `verified` | Replay 성공 |
| `needs-manual-poc` | Replay 실패, 수동 PoC 필요 |
| `invalid-input` | tx hash 오류 |

## 지원 체인

Ethereum, Base, Arbitrum, Optimism, Polygon, BSC, Avalanche, Fantom, Linea, Blast, Celo, ZKsync, Mantle, opBNB, Scroll, Sei, Palm

## 요구사항

- [Foundry](https://github.com/foundry-rs/foundry)
- `INFURA_API_KEY` (선택)
