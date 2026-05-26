# LumosKit Run Report — bsc 0x3a9dd216…9f5937

_Deterministic final report assembled from existing LumosKit outputs; this finalize step does not call an agent._

## Case overview

- **Chain**: bsc (chain_id=56)
- **Tx hash**: `0x3a9dd216fb6314c013fa8c4f85bfbbe0ed0a73209f54c57c1aab02ba989f5937`
- **Block**: 52624701
- **Status**: `pass`
- **Elapsed**: 1293.00s (1292999 ms)
- **Finding**: FPC transfer hook mutates and syncs its own AMM pair reserves during pool transfers

## Pipeline timing

- **Orchestrator wall time**: 1235.19s (1235189 ms)

- **Current stage-duration sum**: 1293.00s (1292999 ms)

| Stage | Artifact | Duration | Status |
|---|---|---:|---|
| `1` | `cefg` | 13.38s (13384 ms) | `success` |
| `2` | `localize` | 17 ms | `success` |
| `3` | `lift` | 36 ms | `success` |
| `4` | `flow_context` | 22.79s (22787 ms) | `success` |
| `5` | `enrich` | 7.50s (7496 ms) | `success` |
| `6` | `context_pack` | 6 ms | `success` |
| `7` | `asset_delta` | 114 ms | `success` |
| `8` | `poc_sketch` | 24 ms | `success` |
| `9` | `semantic` | 43 ms | `success` |
| `agent_poc` | `agent_poc` | 13.90s (13902 ms) | `success` |
| `rca` | `rca` | 1235.19s (1235190 ms) | `success` |

## Reproduction quality

- **PoC status**: `verified`
- **Forge build**: `pass`
- **Forge test**: `pass`
- **Proof kind**: `economic_proof`
- **RCA status**: `complete` / `complete`
- **RCA confidence**: `high`

## Economic reproduction

- **Basis**: holder-net USD loss
- **Verdict**: unpriced — raw PoC proof passed, but USD comparison is incomplete.
- **Incident net loss**: $4675043.60
- **PoC net reproduced**: unknown
- **USD ratio**: unknown

## Attack narrative

_No standalone `attack_flow.md` was available; this section is assembled from RCA `attack_summary` fields._

| Field | Value |
|---|---|
| Entry function | 0x1921e20f |
| Funding source | PancakeV3 flash(address,uint256,uint256,bytes) |
| Attacker callbacks | pancakeV3FlashCallback(uint256,uint256,bytes) and pair callback selector 0x84800812 |
| Callback is root cause | false |

## Multi-leg reconciliation

_Top incident drain/loss legs are shown first; gain and mechanical legs remain available in `report/run_summary.json`._

| Direction | Holder | Role | Token | Delta | USD value |
|---|---|---|---|---:|---:|
| loss | `0xa1e08e10eb09857a8c6f2ef6cca297c1a081ed6b` | `storage_contract` | `USDT` | -4673883.527140201011205321 | -$4675043.60 |
| loss | `0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae` | `storage_contract` | `WBNB` | -736.219506142794922024 | -$484459.71 |
| loss | `0xa1e08e10eb09857a8c6f2ef6cca297c1a081ed6b` | `storage_contract` | `FPC` | -715946.619259251851600417 | N/A |

_… +6 more legs in `report/run_summary.json`._

## Root cause analysis

- **Title**: FPC transfer hook mutates and syncs its own AMM pair reserves during pool transfers
- **Severity**: `critical`
- **Confidence**: `high`
- **Violated invariant**: A token transfer hook must not move tokens out of its own AMM pair and force pair sync while a transfer involving that pair is still being processed.

### Final root cause

The FPC Token._update sell branch for transfers involving its USDT pool calls burnLpToken(value * 65 / 100) before the transfer into the pool is finalized. burnLpToken moves FPC directly out of the PancakePair and calls sync() on that same pair, so the pair's reserve baseline is changed from inside the token transfer hook rather than by the AMM's normal swap/mint/burn/sync boundary. The attacker triggers this during the router transferFrom/swap flow, distorting pair accounting and enabling USDT/FPC extraction followed by profit routing.

### Affected contracts

| Address | Name | Role | Implementation |
|---|---|---|---|
| `0xb192d4a737430aa61cea4ce9bfb6432f7d42592f` | `Token` | `primary vulnerable contract` | `—` |
| `0xa1e08e10eb09857a8c6f2ef6cca297c1a081ed6b` | `PancakePair` | `affected FPC/USDT AMM pair` | `—` |

### Recommended fixes

- Remove the pair-balance mutation and IUniswapV2Pair(usdtPool).sync() call from burnLpToken when _update is processing a transfer where from == usdtPool or to == usdtPool.
- If pool-burn mechanics must remain, execute them only through an explicit non-reentrant maintenance function outside swap/transfer paths and after checking that AMM reserves cannot be manipulated mid-transaction.
- Do not let ERC20 transfer hooks call AMM sync/skim/swap/mint/burn on the token's own liquidity pair while a transfer involving that pair is active.

### Limitations

- Helper selector 0xc07a5a35 on 0xc2a81942627f6929521397eef6173f271d1fb456 is unresolved in selector_db, but it is downstream of the source-backed FPC transfer-hook accounting defect and does not affect the selected causal claim.

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
