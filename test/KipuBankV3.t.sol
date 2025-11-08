// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MaliciousUSDC, ReentrantHelper} from "./ReentrancyAttack.sol";
import {MockUniswapRouter} from "./mocks/MockUniswapRouter.sol";
import {MockUniswapFactory} from "./mocks/MockUniswapFactory.sol";

/// @notice Unit tests for the KipuBankV3 contract using Foundry's Forge framework.
/// @dev Deploys mocks, configures the Uniswap factory/router behavior, and verifies core flows:
///      - direct USDC deposit
///      - ERC20 deposit + swap to USDC
///      - ETH deposit + swap to USDC
///      - bank cap enforcement
///      - withdraws and reentrancy protection
error ReentrancyGuardReentrantCall(); // Declared to use `.selector` in expectRevert checks

contract KipuBankV3Test is Test {
    /// @notice Mock USDC token used for positive tests.
    MockERC20 usdc;

    /// @notice Additional mock token used to simulate non-USDC deposits.
    MockERC20 tokenA;

    /// @notice Mock router that simulates Uniswap swap outputs.
    MockUniswapRouter router;

    /// @notice Mock factory to register token pairs.
    MockUniswapFactory factory;

    /// @notice Instance of the KipuBankV3 under test.
    KipuBankV3 bank;

    /// @notice Admin address used for role operations.
    address admin = address(0xABCD);

    /// @notice User address used as test actor.
    address user = address(0xBEEF);

    /// @notice Deploys mocks and the bank, mints test tokens and configures permissions.
    /// @dev Runs before each test case. Sets up:
    ///      - Mock USDC and tokenA
    ///      - Mock router and factory (factory registers tokenA<->USDC pair)
    ///      - KipuBankV3 with 1_000_000 USDC cap
    ///      - Grants token allowance and mints tokens for `user`
    function setUp() public {
        // Deploy mocks (USDC "normal" for most tests)
        usdc = new MockERC20("USDC", "USDC", 6);
        tokenA = new MockERC20("TKNA", "TKNA", 18);

        router = new MockUniswapRouter(address(usdc));
        factory = new MockUniswapFactory();

        // make factory return a dummy pair for tokenA <-> USDC
        factory.setPair(address(tokenA), address(usdc), address(0xCAFE));

        // bank cap = 1_000_000 USDC (6 decimals) - uses normal usdc here
        bank = new KipuBankV3(admin, address(usdc), address(router), address(factory), 1_000_000 * 10 ** 6);

        // allow tokenA
        vm.prank(admin);
        bank.setTokenAllowed(address(tokenA), true);

        // mint tokens for user
        tokenA.mint(user, 1_000 ether);
        usdc.mint(user, 10_000 * 10 ** 6);

        // give the router some USDC so that if router needs balance it has (not strictly necessary here)
        usdc.mint(address(router), 1_000_000 * 10 ** 6);
    }

    /// @notice Verifies direct USDC deposits update both user balance and total deposited.
    /// @dev Approves bank to pull USDC, performs deposit, then asserts amounts.
    function test_depositUsdc_direct() public {
        vm.startPrank(user);
        MockERC20(address(usdc)).approve(address(bank), 1_000 * 10 ** 6);
        bank.depositUsdc(1_000 * 10 ** 6);
        vm.stopPrank();

        assertEq(bank.balanceOfUsdc(user), 1_000 * 10 ** 6);
        assertEq(bank.totalDepositedUsd6(), 1_000 * 10 ** 6);
    }

    /// @notice Verifies depositing an ERC20 token is swapped to USDC and credited.
    /// @dev Sets router simulated output to 500 USDC, then deposits tokenA and asserts results.
    function test_depositTokenAndSwap_toUsdc() public {
        router.setSwapResult(500 * 10 ** 6);

        vm.startPrank(user);
        tokenA.approve(address(bank), 100 ether);
        bank.depositTokenAndSwap(address(tokenA), 100 ether, 1);
        vm.stopPrank();

        assertEq(bank.balanceOfUsdc(user), 500 * 10 ** 6);
        assertEq(bank.totalDepositedUsd6(), 500 * 10 ** 6);
    }

    /// @notice Verifies depositing ETH is swapped to USDC and credited.
    /// @dev Sets router simulated output to 200 USDC, funds user with 1 ETH, and checks balances.
    function test_depositEthAndSwap_toUsdc() public {
        router.setSwapResult(200 * 10 ** 6);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        bank.depositEthAndSwap{value: 1 ether}(1);
        vm.stopPrank();

        assertEq(bank.balanceOfUsdc(user), 200 * 10 ** 6);
        assertEq(bank.totalDepositedUsd6(), 200 * 10 ** 6);
    }

    /// @notice Ensures the bank cap is enforced and swaps that would exceed the cap revert.
    /// @dev Sets a low cap (100 USDC) and configures the router to return 200 USDC for a token swap.
    function test_cap_is_enforced() public {
        vm.prank(admin);
        bank.setBankCapUsd6(100 * 10 ** 6);

        router.setSwapResult(200 * 10 ** 6);

        vm.startPrank(user);
        tokenA.approve(address(bank), 100 ether);
        vm.expectRevert(bytes("Cap exceeded"));
        bank.depositTokenAndSwap(address(tokenA), 100 ether, 1);
        vm.stopPrank();
    }

    /// @notice Verifies withdraws decrement user balance and transfer USDC out.
    /// @dev Deposits 1000 USDC then withdraws 400; asserts internal and external balances.
    function test_withdrawUsdc() public {
        vm.startPrank(user);
        MockERC20(address(usdc)).approve(address(bank), 1000 * 10 ** 6);
        bank.depositUsdc(1000 * 10 ** 6);
        bank.withdrawUsdc(400 * 10 ** 6);
        vm.stopPrank();

        // internal bank balance
        assertEq(bank.balanceOfUsdc(user), 600 * 10 ** 6);

        // user's external USDC balance (10_000 - 1000 + 400 = 9_400)
        assertEq(usdc.balanceOf(user), 9_400 * 10 ** 6);
    }

    /// @notice Tests reentrancy protection by using a malicious USDC token that callbacks during transfer.
    /// @dev Deploys MaliciousUSDC and a ReentrantHelper, funds helper, deposits, then attempts withdraw which should revert.
    function test_reentrancy_protection_on_withdraw() public {
        // Deploy a malicious USDC token that will callback into the bank during transfer
        MaliciousUSDC malUSDC = new MaliciousUSDC("USDC", "USDC", 6);

        // Deploy a fresh bank that uses the malicious USDC token
        KipuBankV3 bankLocal = new KipuBankV3(admin, address(malUSDC), address(router), address(factory), 1_000_000 * 10 ** 6);

        // Make sure bankLocal allows the token (not strictly necessary for USDC but keep parity)
        vm.prank(admin);
        bankLocal.setTokenAllowed(address(malUSDC), true);

        // Deploy helper attacker that will be the recipient; register it in malicious token so the token knows who to callback
        ReentrantHelper helper = new ReentrantHelper(bankLocal, address(malUSDC));
        malUSDC.setAttacker(address(helper)); // token will callback to attacker during transfer
        malUSDC.setBankAddress(payable(address(bankLocal))); // IMPORTANT: inform token which bank to attack

        // Fund the helper with malicious USDC and approve bankLocal
        malUSDC.mint(address(helper), 1000 * 10 ** 6);

        vm.startPrank(address(helper));
        // approve bankLocal to pull tokens
        MockERC20(address(malUSDC)).approve(address(bankLocal), 1000 * 10 ** 6);

        // deposit into bankLocal (bankLocal will call transferFrom -> token will behave standard here)
        helper.depositToBank(1000 * 10 ** 6);
        vm.stopPrank();

        // Now trigger withdraw and expect the reentrancy revert to bubble up
        vm.prank(address(helper));
        vm.expectRevert(ReentrancyGuardReentrantCall.selector);
        helper.triggerWithdraw(amountToWithdrawSingleUnit()); // triggers withdraw on bankLocal
    }

    /// @notice Small helper to keep numeric constants readable.
    /// @dev Returns a single-unit withdraw amount (100 USDC, 6 decimals).
    /// @return uint256 Withdraw amount in USDC base units.
    function amountToWithdrawSingleUnit() internal pure returns (uint256) {
        return 100 * 10 ** 6; // 100 USDC (6 decimals)
    }
}
