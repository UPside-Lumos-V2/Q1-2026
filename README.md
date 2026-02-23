# DeFi Security Incident Template

Simplified template for analyzing DeFi security incidents with Foundry.

## Case Study: Aperture Finance (Arbitrary External Call via Split Spender/Target)

This repo now includes a reproduced PoC for the Aperture Finance incident (`test/2026-01-25_Aperture_Finance/Aperture_Finance.sol`).

### What the exploit demonstrates

- The target contract executes a user-supplied swap descriptor during a mint flow.
- The descriptor separates:
  - `approve` spender (looks like a router)
  - actual low-level call target
  - raw calldata payload
- Because the actual call target and payload are not constrained tightly enough, an attacker can route execution to an ERC20 token contract and call `transferFrom(...)` instead of a swap.

### Exploit shape (high level)

1. Wrap `msg.value` into WETH (normal-looking flow).
2. Approve a router-like spender for a small WETH amount.
3. Execute a low-level call against `WBTC` with payload `transferFrom(victim, attacker, amount)`.
4. Continue mint flow so the transaction appears structurally valid.

### Why this PoC is useful

- It replays the original attack calldata byte-for-byte.
- It includes a mutation test that changes only the **actual low-level call target** and shows the exploit fails, isolating the root cause.

## Workflow

```
Issue 생성
    ↓
Fetch Metadata (Infura/Public RPC)
    ├─ Block, Date, Attacker, Target
    ├─ Gas Used, Logs Count
    └─ FlashLoan 탐지
    ↓
Generate Templates
    ├─ {Protocol}.sol (단일 PoC 파일)
    └─ README.md (메타데이터 포함)
    ↓
Commit & Push
    ↓
Notify (간소화된 알림)
```

## Quick Start

### 1. Issue 생성
Create an issue with `security-incident` label and fill in:
- Protocol name
- Transaction hash
- Chain ID
- Assignees

### 2. 브랜치 체크아웃
```bash
git fetch origin
git checkout incident/{date}_{protocol}
```

### 3. PoC 작성
Bot이 생성한 단일 파일에서 작업: `test/{date}_{protocol}/{Protocol}.sol`

```bash
cd test/2026-01-25_TrueBit
# TrueBit.sol 파일이 생성되어 있음
forge test -vvv
```

## Generated Template Structure

Bot이 생성하는 파일 구조:

```
test/2026-01-25_TrueBit/
├── TrueBit.sol       # ← 여기서 PoC 작성
└── README.md         # 사건 메타데이터
```

**TrueBit.sol** (자동 생성됨):
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: TrueBit
@Date: 2026-01-25
@Attacker: 0x6cAad74121bF602e71386505A4687f310e0D833e
@Target: 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2
@TxHash: 0xc15df1d131e98d24aa0f107a67e33e66cf2ea27903338cc437a3665b6404dd57
@ChainId: 1
@GasUsed: 518705
*/

contract TrueBitTest is BaseTest {
    function setUp() public {
        vm.createSelectFork("mainnet", 24191018);
        target = 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2;
    }

    function testExploit() public balanceLog {
        // TODO: Implement exploit
        // Set beneficiary if needed: beneficiary = address(0x123);
        // Profit will be automatically calculated and logged
    }
}
```

## Writing Your PoC

### Basic Template
```solidity
function testExploit() public balanceLog {
    // 1. Setup
    beneficiary = address(this);
    fundingToken = address(0); // ETH

    // 2. Get initial funds
    vm.deal(address(this), 1 ether);

    // 3. Implement exploit logic
    // ...

    // 4. Profit automatically logged by balanceLog modifier
}
```

### Real-World Example (참고용)

오디터가 작성하는 실제 PoC 예시:

```solidity
contract TrueBitExpTest is BaseTest {
    IPOOL constant POOL = IPOOL(0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2);
    IERC20 constant TRU = IERC20(0xf65B5C5104c4faFD4b709d9D60a185eAE063276c);

    function setUp() public {
        vm.createSelectFork("mainnet", 24_191_018);
    }

    function testExploit() public balanceLog {
        vm.deal(address(this), 1 ether);

        emit log_named_uint("Starting balance", address(this).balance / 1e18);

        while (address(POOL).balance >= 0.1 ether) {
            uint256 reserve = POOL.reserve();
            uint256 totalSupply = TRU.totalSupply();
            uint256 amount = solveForAmount(reserve, totalSupply);
            uint256 price = POOL.getPurchasePrice(amount);

            POOL.buyTRU{value: price}(amount);
            TRU.approve(address(POOL), amount);
            POOL.sellTRU(amount);
        }

        emit log_named_uint("Final balance", address(this).balance / 1e18);
    }

    function solveForAmount(uint256 reserve, uint256 totalSupply)
        public pure returns (uint256)
    {
        // Complex calculation logic...
    }
}
```

## Available Utilities

### BaseTest Variables
- `fundingToken` - Token address for profit calculation (address(0) for native)
- `target` - Target contract address (auto-set from tx metadata)
- `beneficiary` - Address to track balance (defaults to `address(this)`)

### BaseTest Functions
- `getChainSymbol(chainId)` - Get native token symbol
  ```solidity
  string memory symbol = getChainSymbol(block.chainid); // "ETH", "BNB", etc.
  ```

### BaseTest Modifiers
- `balanceLog` - Auto-logs before/after balances and profit
  ```solidity
  function testExploit() public balanceLog {
      // Your code here
      // Profit automatically calculated
  }
  ```

### Foundry Cheatcodes (자주 사용)
```solidity
// Deal ETH
vm.deal(address(this), 100 ether);

// Deal ERC20 tokens
deal(address(token), address(this), 1000e18);

// Prank as specific address
vm.startPrank(attackerAddress);
// ... calls here ...
vm.stopPrank();

// Fork at specific block
vm.createSelectFork("mainnet", blockNumber);

// Logging
emit log_named_uint("Value", value);
emit log_named_address("Address", addr);
```

## Supported Chains

| Chain | Chain ID | Native Token | RPC Alias |
|-------|----------|--------------|-----------|
| Ethereum | 1 | ETH | mainnet |
| Base | 8453 | ETH | base |
| Arbitrum | 42161 | ETH | arbitrum |
| Optimism | 10 | ETH | optimism |
| Polygon | 137 | MATIC | polygon |
| BSC | 56 | BNB | bsc |
| Avalanche | 43114 | AVAX | avalanche |
| Fantom | 250 | FTM | fantom |
| Linea | 59144 | ETH | linea |
| Blast | 81457 | ETH | blast |
| Celo | 42220 | CELO | celo |
| ZKsync | 324 | ETH | zksync |
| Mantle | 5000 | MNT | mantle |
| opBNB | 204 | BNB | opbnb |
| Scroll | 534352 | ETH | scroll |
| Sei | 1329 | SEI | sei |
| Palm | 11297108109 | PALM | palm |

## Setup

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Configure RPC endpoints** (optional)
   ```bash
   cp .env.example .env
   # Edit .env and add your INFURA_API_KEY or custom RPC URLs
   ```

   > **Note:** Public RPCs are used by default. Infura API key is optional but recommended for reliability.

3. **Verify installation**
   ```bash
   forge test -vvv
   ```

## Testing

```bash
# Run all tests
forge test -vvv

# Run specific test file
forge test --match-path test/2026-01-25_Protocol/Protocol.sol -vvv

# Run with detailed traces
forge test --match-test testExploit -vvvv

# Check formatting
forge fmt --check
```

## Project Structure

```
audit-template/
├── .env.example              # RPC configuration template
├── src/shared/
│   ├── BaseTest.sol          # Base test class (68 lines)
│   └── interfaces.sol        # Common DeFi interfaces
├── test/
│   └── {DATE}_{PROTOCOL}/
│       ├── {Protocol}.sol    # ← Single PoC file (you work here)
│       └── README.md         # Incident metadata
└── .github/workflows/
    ├── ci.yml                # Test & format checks
    └── on_security_incident.yml  # Automated template generation
```

## Best Practices

1. **Keep contract names meaningful**
   ```solidity
   // Good
   contract TrueBitExploit is BaseTest { ... }

   // Avoid generic names
   contract Test is BaseTest { ... }
   ```

2. **Add detailed comments**
   ```solidity
   // @KeyInfo - Total Lost: 8540 ETH
   // @Attacker: 0x6C8EC8f14bE7C01672d31CFa5f2CEfeAB2562b50
   // @Analysis: https://www.certik.com/resources/blog/...
   ```

3. **Use descriptive logs**
   ```solidity
   emit log_named_uint("Pool balance before", pool.balance);
   emit log_named_uint("Profit from iteration", profit);
   ```

4. **Test incrementally**
   ```bash
   # Test each step
   forge test --match-test testExploit -vvv
   ```

## Contributing

- Modify only your assigned `test/{date}_{protocol}/` directory
- Keep code clean and well-documented
- Test locally before pushing
- Use meaningful commit messages

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry Cheatcodes](https://book.getfoundry.sh/cheatcodes/)
- [DeFi Hack Labs](https://github.com/SunWeb3Sec/DeFiHackLabs)

## License

UNLICENSED
