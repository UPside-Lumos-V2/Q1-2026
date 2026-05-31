# LumosKit Run Report — ethereum 0x06cc0f36…24c6b4

_Deterministic final report assembled from existing LumosKit outputs; this finalize step does not call an agent._

## Case overview

- **Chain**: ethereum (chain_id=1)
- **Tx hash**: `0x06cc0f36159d7094359d88fe1d43cda601e8644282ba305c5ffbd013b524c6b4`
- **Block**: unknown
- **Status**: `pass`
- **Elapsed**: 133.36s (133361 ms)
- **Finding**: RCA blocked

## Signal context

- **Protocol claim**: Alephium TokenBridge
- **Detector source**: hack-detector:twitter:BlackHartInc
- **Detected at**: 2026-05-30T15:04:45Z
- **Published at**: 2026-05-30T15:04:45Z
- **Original alert**: https://x.com/BlackHartInc/status/2060739195883139458
- **Source id**: tw:2060739195883139458
- **Lumos signal id**: manual-blackhart-2060739195883139458
- **Incident group id**: manual-alephium-tokenbridge-2026-05-30
- **Claimed loss**: 815000

Detector summary:

> Alephium TokenBridge on Ethereum was drained for approximately $815K. The incident minted 13.76M unbacked wrapped ALPH and unlocked USDT, USDC, WBTC, and WETH custody reserves through forged bridge approvals attributed to compromised guardian authority.


## Pipeline timing

- **Orchestrator wall time**: 150 ms

- **Current stage-duration sum**: 133.36s (133361 ms)

| Stage | Artifact | Duration | Status |
|---|---|---:|---|
| `1` | `cefg` | 120.67s (120669 ms) | `success` |
| `2` | `localize` | 19 ms | `success` |
| `3` | `lift` | 52 ms | `success` |
| `4` | `flow_context` | 1.67s (1672 ms) | `success` |
| `5` | `enrich` | 4.61s (4609 ms) | `success` |
| `6` | `context_pack` | 2 ms | `success` |
| `7` | `asset_delta` | 23 ms | `success` |
| `8` | `poc_sketch` | 19 ms | `success` |
| `9` | `semantic` | 61 ms | `success` |
| `agent_poc` | `agent_poc` | 6.08s (6085 ms) | `success` |
| `rca` | `rca` | 150 ms | `success` |

## Reproduction quality

- **PoC status**: `verified`
- **Forge fmt**: `pass`
- **Forge build**: `pass`
- **Forge test**: `pass`
- **Proof kind**: `economic_proof`
- **RCA status**: `blocked` / `blocked`
- **RCA confidence**: `unknown`

## Economic reproduction

- **Basis**: incident profit oracle usd
- **Verdict**: exact — PoC reproduces 99–101% of incident net loss.
- **Incident net loss**: unknown
- **PoC net reproduced**: $547644.05
- **USD ratio**: 1.000x

## Attack narrative

_No attack-flow narrative artifact was available; see the PoC and RCA artifacts for raw evidence._

## Multi-leg reconciliation

_No asset legs were recorded._

## Root cause analysis

# RCA blocked

- stage: `rca`
- status: `blocked`
- validation: `blocked`
- blocker: PoC blocked: Generated PoC.t.sol builds and testPoC passes; readability findings were recorded as product warnings instead of blocking the economic PoC.

Internal artifacts are available under `artifacts/rca/`.

## Artifacts

| Artifact | Bundle path | Status |
|---|---|---|
| Bundle index | `README.md` | generated |
| Machine run summary | `report/run_summary.json` | generated |
| Final integrated report | `report/REPORT.md` | generated |
| RCA | `report/RCA.md` | generated fallback |
| RCA structured report | `report/report.json` | missing optional |
| PoC | `poc/PoC.t.sol` | included |
| PoC base support | `poc/LumosPoCBase.sol` | included |
| Asset deltas | `evidence/asset_deltas.json` | included |
| Fund flows | `evidence/fund_flows.json` | included |
| Asset delta graph | `visuals/asset_deltas.png` | included |
| Fund-flow graph | `visuals/fund_flows.png` | included |
