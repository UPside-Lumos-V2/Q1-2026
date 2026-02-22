# Gyroscope Incident

| Field | Value |
|-------|-------|
| Date | 2026-01-30 |
| Chain | 42161 |
| Block | 426912214 |
| Tx | `0x51c22898a9b9f519a10b0a0be89b9d51c0248adb80cc0f89e57437e15e6c60c7` |
| Attacker | `0x7DD4075A6eAe9f18309F112364f0394C2DfA8102` |
| Target | `0xCA5d8F8a8d49439357d3CF46Ca2e720702F132b8` |
| Gas Used | 191584 |
| Logs | 5 |

## Auditors
- [ ] @wiimdy

## Status
- [x] Workspace initialized
- [ ] Analysis complete

## Workspace
```bash
git fetch origin && git checkout incident/2026-01-30_Gyroscope
forge test -vvv
```
