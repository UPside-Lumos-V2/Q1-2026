# LumosKit Run Report — arbitrum 0x445b7204…9a2555

_Deterministic final report assembled from existing LumosKit outputs; this finalize step does not call an agent._

## Case overview

- **Chain**: arbitrum (chain_id=42161)
- **Tx hash**: `0x445b7204e7f12bf6b005847daed813783dd22f70a9af7a1e8bf172a7279a2555`
- **Block**: 450305694
- **Status**: `pass`
- **Elapsed**: 636.58s (636576 ms)
- **Finding**: ETHTornado withdrawal settled a pre-existing note entitlement; upstream defect is not proven by supplied artifacts

## Pipeline timing

- **Orchestrator wall time**: 588.83s (588827 ms)

- **Current stage-duration sum**: 636.58s (636576 ms)

| Stage | Artifact | Duration | Status |
|---|---|---:|---|
| `1` | `cefg` | 3.59s (3594 ms) | `success` |
| `2` | `localize` | 4 ms | `success` |
| `3` | `lift` | 6 ms | `success` |
| `4` | `flow_context` | 1.74s (1739 ms) | `success` |
| `5` | `enrich` | 3.12s (3123 ms) | `success` |
| `6` | `context_pack` | 1 ms | `success` |
| `7` | `asset_delta` | 26 ms | `success` |
| `8` | `poc_sketch` | 9 ms | `success` |
| `9` | `semantic` | 8 ms | `success` |
| `agent_poc` | `agent_poc` | 39.24s (39239 ms) | `success` |
| `rca` | `rca` | 588.83s (588827 ms) | `success` |

## Reproduction quality

- **PoC status**: `verified`
- **Forge build**: `pass`
- **Forge test**: `pass`
- **Proof kind**: `economic_proof`
- **RCA status**: `blocked` / `blocked`
- **RCA confidence**: `low`

## Economic reproduction

- **Basis**: incident profit oracle usd
- **Verdict**: close — PoC reproduces the incident within the 80–110% net-loss band.
- **Incident net loss**: $0.00
- **PoC net reproduced**: $0.31
- **USD ratio**: 1.054x

## Attack narrative

_No standalone `attack_flow.md` was available; this section is assembled from RCA `attack_summary` fields._

| Field | Value |
|---|---|
| Entry function | withdraw(bytes,bytes32,bytes32,address,address,uint256,uint256) |
| Callback is root cause | false |

## Multi-leg reconciliation

_No asset legs were recorded._

## Root cause analysis

- **Title**: ETHTornado withdrawal settled a pre-existing note entitlement; upstream defect is not proven by supplied artifacts
- **Severity**: `low`
- **Confidence**: `low`
- **Violated invariant**: Only a holder of a valid, unspent deposited note for a known Merkle root may cause ETHTornado to pay one denomination split between recipient and relayer.

### Final root cause

Frame 2 calls ETHTornado/Tornado withdraw(bytes,bytes32,bytes32,address,address,uint256,uint256), which reaches the visible payout branch after fee, nullifier, known-root, and verifier-proof checks. ETHTornado._processWithdraw then pays one denomination split between recipient and relayer, matching the observed native transfers. The supplied artifacts prove the settlement path and attacker profit, but do not prove an in-transaction bug in the payout primitive. If the payout was unauthorized, the missing cause lies in prior note/root provenance or verifier semantics rather than the visible native transfer calls.

### Affected contracts

| Address | Name | Role | Implementation |
|---|---|---|---|
| `0x84443cfd09a48af6ef360c6976c5392ac5023a1f` | `ETHTornado` | `visible payout contract; upstream cause unproven` | `—` |

### Recommended fixes

- Verify the provenance of the accepted root and nullifier before attributing a patch; if verifier or root-registration evidence proves invalid entitlement, enforce the note/root invariant at that upstream branch rather than changing downstream native transfer calls.
- Operationally audit the verifier contract and all prior deposits/root updates for this pool, and pause withdrawals for roots whose deposit provenance cannot be established from trusted records.

### Limitations

- artifacts/agent_poc/attack_flow.md is absent; PoC flow was taken from PoC.t.sol, pseudocode, trace_facts, fund_flows, and frontier artifacts.
- prior_state_provenance_gap: supplied artifacts do not prove how the accepted Merkle root and note/nullifier entitlement were created.
- tx_scope_gap: decisive prior deposit/root/verifier provenance, if any, is outside the supplied current-transaction artifacts.
- Verifier contract source and proof-system semantics are not present, so an invalid-proof or verifier-bypass claim would be speculative.
- Because the exact vulnerable upstream branch is missing, the report is partial and cannot provide a patchable line-level root cause.

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
