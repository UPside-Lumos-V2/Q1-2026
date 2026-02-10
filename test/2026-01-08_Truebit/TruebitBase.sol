// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/FeatureTypes.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: Truebit
@Date: 2026-01-08
@Attacker: 0x6C8EC8f14bE7C01672d31CFa5f2CEfeAB2562b50
@AttackContract: 0x1De399967B206e446B4E9AeEb3Cb0A0991bF11b8
@Target: 0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2
@TxHash: 0xcd4755645595094a8ab984d0db7e3b4aabde72a5c87c4f176a030629c47fb014
@ChainId: 1
@GasUsed: 481749
@Lost: ~8,535 ETH (~$26.5M)
@Vulnerability: Integer Overflow in getPurchasePrice() — Solidity 0.6.10, partial SafeMath (mul protected, add vulnerable)
*/

/// @notice Interface for the Truebit Purchase contract
/// @dev Function names verified via cast 4byte lookup against Phalcon trace:
///   getPurchasePrice(uint256) = 0xc59d5633  ← matched
///   buyTRU(uint256)           = 0xa0296215  ← from Phalcon Line 15
///   sellTRU(uint256)          = 0xc471b10b  ← from Phalcon Line 52
interface IPurchase {
    function getPurchasePrice(uint256 amount) external view returns (uint256);
    function buyTRU(uint256 amount) external payable;
    function sellTRU(uint256 amount) external;
}

abstract contract TruebitBase is BaseTest {
    // ==================== Addresses ====================
    address constant PURCHASE_PROXY =
        0x764C64b2A09b09Acb100B80d8c505Aa6a0302EF2; // proxy contract
    address constant PURCHASE_IMPL = 0xC186e6F0163e21be057E95aA135eDD52508D14d3; // implmentation contract(unverified)
    address constant TRU_TOKEN = 0xf65B5C5104c4faFD4b709d9D60a185eAE063276c; // $TRU(ERC20 토큰)
    address constant ATTACKER_EOA = 0x6C8EC8f14bE7C01672d31CFa5f2CEfeAB2562b50; // 공격자
    address constant ATTACKER_CONTRACT =
        0x1De399967B206e446B4E9AeEb3Cb0A0991bF11b8; // 공격자 mev bot

    IPurchase purchase = IPurchase(PURCHASE_PROXY);
    IERC20 tru = IERC20(TRU_TOKEN);

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 24_191_018); // -1 block fork
        target = PURCHASE_PROXY;
        txHash = 0xcd4755645595094a8ab984d0db7e3b4aabde72a5c87c4f176a030629c47fb014;

        // 라벨링
        vm.label(PURCHASE_PROXY, "Purchase (Proxy)");
        vm.label(PURCHASE_IMPL, "Purchase (Impl)");
        vm.label(TRU_TOKEN, "TRU Token");
        vm.label(ATTACKER_EOA, "Attacker EOA");
        vm.label(ATTACKER_CONTRACT, "Attacker MEV Bot");
    }
}
