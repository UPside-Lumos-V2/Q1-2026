# LumosKit Run Report — arbitrum 0x20db7891…57e10f

_Deterministic final report assembled from existing LumosKit outputs; this finalize step does not call an agent._

## Case overview

- **Chain**: arbitrum (chain_id=42161)
- **Tx hash**: `0x20db78913a51c3b3aece860ea142c240f3f8fa3b5bbf533a3d1d48eed857e10f`
- **Block**: 465420021
- **Status**: `pass`
- **Elapsed**: 829.89s (829893 ms)
- **Finding**: Stale vault period catch-up lets deposits mint receipts before price accrual and redeem them after repricing

## Pipeline timing

- **Orchestrator wall time**: 521.51s (521515 ms)

- **Current stage-duration sum**: 829.89s (829893 ms)

| Stage | Artifact | Duration | Status |
|---|---|---:|---|
| `1` | `cefg` | 32.67s (32669 ms) | `success` |
| `2` | `localize` | 141 ms | `success` |
| `3` | `lift` | 396 ms | `success` |
| `4` | `flow_context` | 15.91s (15914 ms) | `success` |
| `5` | `enrich` | 15.85s (15848 ms) | `success` |
| `6` | `context_pack` | 31 ms | `success` |
| `7` | `asset_delta` | 91 ms | `success` |
| `8` | `poc_sketch` | 91 ms | `success` |
| `9` | `semantic` | 504 ms | `success` |
| `agent_poc` | `agent_poc` | 242.69s (242693 ms) | `success` |
| `rca` | `rca` | 521.51s (521515 ms) | `success` |

## Reproduction quality

- **PoC status**: `verified`
- **Forge build**: `pass`
- **Forge test**: `pass`
- **Proof kind**: `economic_proof`
- **RCA status**: `blocked` / `blocked`
- **RCA confidence**: `high`

## Economic reproduction

- **Basis**: holder-net USD loss
- **Verdict**: unpriced — raw PoC proof passed, but USD comparison is incomplete.
- **Incident net loss**: $14776.66
- **PoC net reproduced**: unknown
- **USD ratio**: unknown

## Attack narrative

_No standalone `attack_flow.md` was available; this section is assembled from RCA `attack_summary` fields._

| Field | Value |
|---|---|
| Entry function | attack() on 0x43514743caa5a7d4a8b07f5d25fb242391bbc8da / tx input selector 0xf1f58442 |
| Funding source | nested Aave, Balancer, Uniswap V3, and Algebra flash loans |
| Public entrypoint | withdraw(uint256) |
| Attacker callbacks | executeOperation, receiveFlashLoan, uniswapV3FlashCallback, algebraFlashCallback |
| Callback is root cause | false |

## Multi-leg reconciliation

_Top incident drain/loss legs are shown first; gain and mechanical legs remain available in `report/run_summary.json`._

| Direction | Holder | Role | Token | Delta | USD value |
|---|---|---|---|---:|---:|
| loss | `0x80e1a981285181686a3951b05ded454734892a09` | `storage_contract` | `USDC` | -14778.31337 | -$14776.66 |

_… +9 more legs in `report/run_summary.json`._

## Root cause analysis

- **Title**: Stale vault period catch-up lets deposits mint receipts before price accrual and redeem them after repricing
- **Severity**: `high`
- **Confidence**: `high`
- **Violated invariant**: Before minting receipt tokens for a deposit, the vault's currentPeriod/tokenPrice must be fully caught up to the current epoch, or freshly minted receipts must not be redeemable at a later catch-up price for more underlying than the deposit plus legitimate time-accrued entitlement.

### Final root cause

The Vault implementation behind proxy 0x80e1a981285181686a3951b05ded454734892a09 lets deposit(uint256) mint USDF receipt tokens after a capped _compute() call that advances at most 30 periods. If the vault is more than 30 periods stale, the deposit mints against a stale _records[currentPeriod].tokenPrice; the attacker can then call public compute() to advance tokenPrice and call withdraw(uint256), whose toErc20Amount() redeems the same freshly minted receipts at the higher post-catch-up price. This violates the share-pricing invariant that a deposit must not gain immediate redemption value solely from accounting catch-up performed after the mint.

### Affected contracts

| Address | Name | Role | Implementation |
|---|---|---|---|
| `0x80e1a981285181686a3951b05ded454734892a09` | `Vault proxy` | `primary vulnerable contract` | `0x038c8535269e4adc083ba90388f15788174d7da7` |
| `0xae48b7c8e096896e32d53f10d0bf89f82ec7b987` | `USDF ReceiptToken proxy/token` | `receipt token whose authorized mint/burn reflects the vault accounting error` | `0xf8a13864378c8eb6883a6c98b5b23ea068d8c25f` |

### Recommended fixes

- In Vault.deposit(uint256), require _compute() to fully advance currentPeriod to DateUtils.diffDays(_startOfYearTimestamp, block.timestamp) before computing numberOfReceiptTokens, or revert deposits while catch-up remains incomplete.
- Remove or redesign the 30-period break in _compute() for value-bearing entrypoints, or separate bounded keeper catch-up from deposit/withdraw pricing so shares cannot be minted in a stale period and redeemed after public catch-up.
- Add an invariant test that deposit -> compute -> withdraw in the same transaction cannot return more underlying than the deposited principal plus explicitly accrued entitlement.

### Limitations

- artifacts/agent_poc/attack_flow.md was unavailable/read-error in the supplied artifact set; PoC.t.sol and result.json provided the call sequence and verified execution instead. This does not affect the selected causal claim.
- Exact historical APR/currentPeriod storage values were not decoded from raw storage because the source and trace already establish the exploitable branch and invariant; this does not affect the patch direction.

## Artifacts

| Artifact | Bundle path | Status |
|---|---|---|
| Bundle index | `README.md` | generated |
| Machine run summary | `report/run_summary.json` | generated |
| Final integrated report | `report/REPORT.md` | generated |
| RCA | `report/RCA.md` | included |
| RCA structured report | `report/report.json` | included |
| PoC | `poc/PoC.t.sol` | included |
| PoC base support | `poc/LumosPoCBase.sol` | included |
| Asset deltas | `evidence/asset_deltas.json` | included |
| Fund flows | `evidence/fund_flows.json` | included |
| Asset delta graph | `visuals/asset_deltas.png` | included |
| Fund-flow graph | `visuals/fund_flows.png` | included |
