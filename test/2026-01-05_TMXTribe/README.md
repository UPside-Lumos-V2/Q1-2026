# TMXTribe GLP Share-Price Exploit

## Incident Overview

| Field | Value |
|-------|-------|
| Date | 2026-01-05 |
| Protocol | TMXTribe (GLP wrapper) |
| Chain | Arbitrum |
| Loss | ≈$138K USDT equivalent |
| Root Cause | AUM manipulation between mint/redeem windows |

### Transaction Hash
| Chain | Tx Hash |
|-------|---------|
| Arbitrum | `0xc1d8582a754afdc00ba68d94772a31a266c0d0daff16276c5020d9a7b34ddbab` |

### Key Addresses
| Role | Address |
|------|---------|
| Attacker | `0x763a67E4418278f84c04383071fC00165C112661` |
| Mint & Stake Proxy | `0x6E7892aeCa5b77C23a17023F718Ff3524eE3Ba46` |
| Swap Proxy | `0x18f340f493f37869FcdbB9565767B00F18B9E425` |
| GLP Manager | `0xE80fB6F907b37E2ed46a634882420B8E21BCCfB1` |
| USDG Token | `0x9EC1f9f46636c293D03Aca25124749C231B1d598` |

---

## The Vulnerability

### What Was the Flaw?

TMXTribe wraps GMX GLP by minting **FSTLP** receipts via `mintAndStakeGlp()` and later burning them through the `unstakeAndRedeem` proxy. Both operations rely on the GLP manager’s `AUM / supply` pricing. The protocol **never locked or snapshotted AUM** between mint and redeem. If a user could inflate AUM in between, the already-minted receipts would later cash out at the higher price.

```solidity
(bool ok, ) = MINTANDSTAKE_PROXY.call(
    abi.encodeWithSignature(
        "mintAndStakeGlp(address,uint256,uint256,uint256)",
        address(USDT_TOKEN),
        stakeAmount,
        0,
        0
    )
); // <-- price uses current AUM
```

Immediately afterwards, the attacker called the swap proxy with a large USDT→USDG trade, which **counts as protocol TVL**, pushing AUM upward without increasing FSTLP supply. When redeeming, the inflated ratio was used:

```solidity
(bool ok, ) = UNSTAKEANDREDEEM_PROXY.call(abi.encodePacked(
    bytes4(0xf0d0711d),
    abi.encode(address(USDT_TOKEN)),
    abi.encode(fstlpBalance),
    ...
)); // <-- price now reflects manipulated AUM
```

### What Was Missing?

1. **Same-block price guardrails** – minting should not immediately profit from self-induced AUM changes.
2. **Supply/AUM rebalancing** – GLP wrappers must mint shares against net asset value recorded after swaps settle.
3. **TWAP or oracle-based pricing** – using spot AUM made the vault deterministic to manipulate.

---

## The Attack

### Step 1: Discounted FSTLP Mint
- Flash-loaned ~137,775 USDT and staked only 55,109 USDT through `mintAndStakeGlp`.
- Received FSTLP at the “pre-manipulation” NAV snapshot.

### Step 2: Inflate AUM with Swap Proxy
- Sent the remaining 82,665 USDT through `swap(address[],uint256,uint256,address)` (USDT→USDG).
- GMX counted the incoming USDG liquidity as assets, so `glpManager.getAums()` now reported a higher NAV.

### Step 3: Redeem at Pumped Price
- Called `unstakeAndRedeem` using a signed permit payload, redeeming FSTLP while AUM was elevated.
- Because FSTLP supply didn’t change but AUM increased, the attacker withdrew more USDT than deposited.

### Step 4: Clean Up
- Swapped leftover USDG back to USDT via the secondary swap proxy.
- Repaid the flash loan and kept the spread as profit.

---

## Attack Flow Diagram

```
┌──────────────────────────────────────────┐
│            TMXTribe / GMX Vault          │
├──────────────────────────────────────────┤
│ 1) mintAndStakeGlp (55k USDT) → FSTLP    │
│    NAV snapshot = low AUM                │
│                                          │
│ 2) swapProxy USDT→USDG (82k USDT)        │
│    GLP AUM increases immediately         │
│                                          │
│ 3) unstakeAndRedeem(FSTLP)               │
│    NAV uses inflated AUM → extra USDT    │
│                                          │
│ 4) secondary swap USDG→USDT              │
│    Flash loan repaid, profit locked      │
└──────────────────────────────────────────┘
```

---

## Lessons Learned

### For Developers
1. **Snapshot NAV per mint** – users should only redeem against the NAV recorded for their shares.
2. **Enforce TWAP pricing** – require time-weighted prices or multi-block delays before NAV updates affect withdrawals.
3. **Limit swap impact** – exclude protocol-owned liquidity or apply circuit breakers when AUM jumps beyond a threshold.
4. **Signature gating** – permit-based redeem flows should still validate current share pricing against manipulation windows.

### Recommended Fix

```solidity
function mint(uint256 amount) external {
    updateAUM(); // TWAP / oracle guarded
    uint256 price = cachedAum / totalSupply;
    _mint(msg.sender, amount * 1e18 / price);
}

function redeem(uint256 shares) external {
    require(block.timestamp > mintTimestamp[msg.sender] + DELAY, "cooldown");
    uint256 payout = shares * cachedAum / totalSupply;
    _burn(msg.sender, shares);
    transferUSDT(msg.sender, payout);
}
```

---

## Proof of Concept

```bash
git fetch origin && git checkout incident/2026-01-05_TMXTribe
forge test --match-test testExploit -vvvv
```

The PoC:
1. Mints FSTLP at the pre-manipulation NAV.
2. Calls `swap` to increase AUM.
3. Redeems with the signed payload to withdraw extra USDT.
4. Converts USDG back to repay capital, confirming net profit.

---

## Auditors
- [ ] @y0ungminhada

## Status
- [x] Workspace initialized
- [x] Root cause identified
- [x] PoC implemented
- [ ] Mitigation verified
