# DeFi Security Incident Template

DeFi 해킹 사건 분석 및 ML 학습용 데이터셋 구축 템플릿.
(우선 간단한 라벨링 피처들만 수집하다가 피드백 받아서 고도화 예정)

## Workflow

```
[Issue 생성] ─── security-incident 라벨
      │
      ▼
[Bot] incident 브랜치 생성 + Replay 검증
      │
      ▼
[Auditor] PoC 작성 → PR to main
      │
      ├─ Compliance Check (봇 코멘트)
      │   - 보호 파일 수정 차단
      │   - 파일 삭제 경고
      │   - 타인 폴더 수정 경고
      │
      ▼
[Merge] → Data Mining → dataset.csv 자동 업데이트
```

## Quick Start

1. **Issue 생성**: `Security Incident` 템플릿 사용, Assignee 지정
2. **브랜치 체크아웃**: `git fetch && git checkout incident/{date}_{protocol}`
3. **PoC 작성**: `test/{date}_{protocol}/` 폴더에서 작업
4. **PR 생성**: main으로 PR → Compliance 봇이 검증
5. **Merge**: 데이터 자동 마이닝

## Data Flow

| 위치 | 용도 | 커밋 |
|------|------|------|
| `data/local/` | 로컬 테스트 결과 | X |
| `data/verified/` | CI 검증 결과 | X |
| `data/dataset.csv` | 공식 데이터셋 | O (봇) |

- tx_hash 기반 중복 방지
- main 머지 시에만 공식 데이터 생성

## PoC 작성

```solidity
function testExploit() public exploit {
    addVulnerability(VulnerabilityType.FLASH_LOAN);
    addAttackVector(AttackVector.PRICE_DISTORTION);
    addMitigation(Mitigation.ORACLE_HARDENING);

    // exploit 구현...

    addProfit(address(0), 100 ether);  // ETH
    addProfit(USDC, 50_000e6);         // ERC20
}
```

## 분류 체계

| 차원 | 설명 | 예시 |
|------|------|------|
| **VulnerabilityType** | 기술적 취약점 | `REENTRANCY`, `FLASH_LOAN`, `ACCESS_CONTROL` |
| **AttackVector** | 공격 방식 | `REPETITION_ABUSE`, `PRICE_DISTORTION`, `DIRECT_THEFT` |
| **Mitigation** | 방어 기제 | `REENTRANCY_GUARD`, `ORACLE_HARDENING`, `PAUSABLE` |

## Replay 실패 시

| Revert | 해결 |
|--------|------|
| `Not Owner` | `vm.prank(owner)` |
| `Insufficient balance` | `vm.deal(addr, amt)` |
| `NotActivated` | `foundry.toml`에서 `evm_version` 변경 |

## Compliance Rules

**차단 (VIOLATION)**
- `data/*`, `src/shared/*`, `.github/*` 수정

**경고 (WARNING)**
- 파일 삭제
- 다른 auditor 폴더 수정

## 지원 체인

Ethereum, Base, Arbitrum, Optimism, Polygon, BSC, Avalanche, Fantom, Linea, Blast, Celo, ZKsync, Mantle, opBNB, Scroll, Sei, Palm

## 요구사항

- [Foundry](https://github.com/foundry-rs/foundry)
- GitHub Secrets: `INFURA_API_KEY`

Fantom만 public RPC 사용 (Infura 미지원).
