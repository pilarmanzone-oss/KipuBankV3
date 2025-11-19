// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapRouter} from "./mocks/MockUniswapRouter.sol";
import {MockUniswapFactory} from "./mocks/MockUniswapFactory.sol";

/// @notice Additional tests to increase branch coverage for KipuBankV3
/// @dev These tests target uncovered branches to get coverage above 50%
contract KipuBankV3AdditionalTests is Test {
    MockERC20 usdc;
    MockERC20 tokenA;
    MockUniswapRouter router;
    MockUniswapFactory factory;
    KipuBankV3 bank;
    
    address admin = address(0xABCD);
    address user = address(0xBEEF);
    address nonAdmin = address(0xDEAD);

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        tokenA = new MockERC20("TKNA", "TKNA", 18);
        router = new MockUniswapRouter(address(usdc));
        factory = new MockUniswapFactory();
        
        factory.setPair(address(tokenA), address(usdc), address(0xCAFE));
        
        bank = new KipuBankV3(admin, address(usdc), address(router), address(factory), 1_000_000 * 10 ** 6);
        
        vm.prank(admin);
        bank.setTokenAllowed(address(tokenA), true);
        
        tokenA.mint(user, 1_000 ether);
        usdc.mint(user, 10_000 * 10 ** 6);
        usdc.mint(address(router), 1_000_000 * 10 ** 6);
    }

    // ===================================================================
    // CONSTRUCTOR VALIDATION BRANCHES
    // ===================================================================

    /// @notice Test constructor revert when admin address is zero
    function test_constructor_revert_admin_zero() public {
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        new KipuBankV3(address(0), address(usdc), address(router), address(factory), 1_000_000 * 10 ** 6);
    }

    /// @notice Test constructor revert when USDC address is zero
    function test_constructor_revert_usdc_zero() public {
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        new KipuBankV3(admin, address(0), address(router), address(factory), 1_000_000 * 10 ** 6);
    }

    /// @notice Test constructor revert when router address is zero
    function test_constructor_revert_router_zero() public {
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        new KipuBankV3(admin, address(usdc), address(0), address(factory), 1_000_000 * 10 ** 6);
    }

    /// @notice Test constructor revert when factory address is zero
    function test_constructor_revert_factory_zero() public {
        vm.expectRevert(KipuBankV3.InvalidAddress.selector);
        new KipuBankV3(admin, address(usdc), address(router), address(0), 1_000_000 * 10 ** 6);
    }

    // ===================================================================
    // ACCESS CONTROL BRANCHES
    // ===================================================================

    /// @notice Test non-admin cannot call setTokenAllowed
    function test_setTokenAllowed_revert_not_admin() public {
        vm.prank(nonAdmin);
        vm.expectRevert(KipuBankV3.NotAdmin.selector);
        bank.setTokenAllowed(address(tokenA), false);
    }

    /// @notice Test non-admin cannot call setBankCapUsd6
    function test_setBankCapUsd6_revert_not_admin() public {
        vm.prank(nonAdmin);
        vm.expectRevert(KipuBankV3.NotAdmin.selector);
        bank.setBankCapUsd6(500_000 * 10 ** 6);
    }

    // ===================================================================
    // DEPOSIT ETH BRANCHES
    // ===================================================================

    /// @notice Test depositEthAndSwap reverts when USDC not allowed
    function test_depositEthAndSwap_revert_token_not_allowed() public {
        vm.prank(admin);
        bank.setTokenAllowed(address(usdc), false);

        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(KipuBankV3.TokenNotAllowed.selector);
        bank.depositEthAndSwap{value: 1 ether}(1);
    }

    /// @notice Test depositEthAndSwap reverts with zero amountOutMin
    function test_depositEthAndSwap_revert_amountOutMin_zero() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(KipuBankV3.AmountOutMinZero.selector);
        bank.depositEthAndSwap{value: 1 ether}(0);
    }

    /// @notice Test depositEthAndSwap reverts with zero ETH value
    function test_depositEthAndSwap_revert_zero_eth() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.ZeroEth.selector);
        bank.depositEthAndSwap{value: 0}(1);
    }

    // ===================================================================
    // DEPOSIT TOKEN BRANCHES
    // ===================================================================

    /// @notice Test depositTokenAndSwap reverts with address(0) token
    function test_depositTokenAndSwap_revert_token_address_zero() public {
        vm.prank(user);
        // TokenNotAllowed comes first, before UnsupportedToken check
        vm.expectRevert(KipuBankV3.TokenNotAllowed.selector);
        bank.depositTokenAndSwap(address(0), 100 ether, 1);
    }

    /// @notice Test depositTokenAndSwap reverts with amountOutMin zero
    function test_depositTokenAndSwap_revert_amountOutMin_zero() public {
        vm.startPrank(user);
        tokenA.approve(address(bank), 100 ether);
        vm.expectRevert(KipuBankV3.AmountOutMinZero.selector);
        bank.depositTokenAndSwap(address(tokenA), 100 ether, 0);
        vm.stopPrank();
    }

    /// @notice Test depositTokenAndSwap reverts when token is not supported by factory
    function test_depositTokenAndSwap_revert_unsupported_token() public {
        MockERC20 tokenB = new MockERC20("B", "B", 18);
        
        // Allow the token but don't register a pair in factory
        vm.prank(admin);
        bank.setTokenAllowed(address(tokenB), true);
        
        // Factory will return address(0) for non-existent pair
        // The _isTokenSupported check will return false, triggering UnsupportedToken
        
        vm.startPrank(user);
        tokenB.mint(user, 100 ether);
        tokenB.approve(address(bank), 100 ether);
        vm.expectRevert(KipuBankV3.UnsupportedToken.selector);
        bank.depositTokenAndSwap(address(tokenB), 100 ether, 1);
        vm.stopPrank();
    }

    /// @notice Test depositTokenAndSwap with USDC directly (bypass swap path)
    function test_depositTokenAndSwap_usdc_direct_path() public {
        vm.startPrank(user);
        usdc.approve(address(bank), 1000 * 10 ** 6);
        bank.depositTokenAndSwap(address(usdc), 1000 * 10 ** 6, 1);
        vm.stopPrank();
        
        assertEq(bank.balanceOfUsdc(user), 1000 * 10 ** 6);
    }

    /// @notice Test depositTokenAndSwap with USDC reverts when cap exceeded
    function test_depositTokenAndSwap_usdc_revert_cap_exceeded() public {
        vm.prank(admin);
        bank.setBankCapUsd6(500 * 10 ** 6);
        
        vm.startPrank(user);
        usdc.approve(address(bank), 1000 * 10 ** 6);
        vm.expectRevert(KipuBankV3.CapExceeded.selector);
        bank.depositTokenAndSwap(address(usdc), 1000 * 10 ** 6, 1);
        vm.stopPrank();
    }

    // ===================================================================
    // WITHDRAWAL BRANCHES
    // ===================================================================

    /// @notice Test withdrawUsdc reverts with zero amount
    function test_withdrawUsdc_revert_zero_amount() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.InvalidAmount.selector);
        bank.withdrawUsdc(0);
    }

    /// @notice Test withdrawUsdc reverts with insufficient balance
    function test_withdrawUsdc_revert_insufficient_balance() public {
        vm.startPrank(user);
        usdc.approve(address(bank), 100 * 10 ** 6);
        bank.depositUsdc(100 * 10 ** 6);
        
        vm.expectRevert(KipuBankV3.InsufficientBalance.selector);
        bank.withdrawUsdc(200 * 10 ** 6);
        vm.stopPrank();
    }

    // ===================================================================
    // RECEIVE / FALLBACK BRANCHES
    // ===================================================================

    /// @notice Test receive() reverts on direct ETH transfer
    function test_receive_revert() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(KipuBankV3.UseDepositEthAndSwap.selector);
        (bool success, ) = payable(address(bank)).call{value: 1 ether}("");
        success; // Suppress unused variable warning
    }

    /// @notice Test fallback() reverts on unknown function call
    function test_fallback_revert() public {
        vm.prank(user);
        vm.expectRevert(KipuBankV3.UnknownCall.selector);
        (bool success, ) = address(bank).call(abi.encodeWithSignature("nonExistentFunction()"));
        success; // Suppress unused variable warning
    }

    // ===================================================================
    // EDGE CASES
    // ===================================================================

    /// @notice Test depositUsdc at exact cap limit
    function test_depositUsdc_at_exact_cap() public {
        uint256 cap = bank.bankCapUsd6();
        
        // Mint enough USDC for the user to reach cap
        usdc.mint(user, cap);
        
        vm.startPrank(user);
        usdc.approve(address(bank), cap);
        bank.depositUsdc(cap);
        vm.stopPrank();
        
        assertEq(bank.totalDepositedUsd6(), cap);
    }

    /// @notice Test depositUsdc exceeds cap by 1
    function test_depositUsdc_revert_exceed_cap_by_one() public {
        uint256 cap = bank.bankCapUsd6();
        
        vm.startPrank(user);
        usdc.approve(address(bank), cap + 1);
        vm.expectRevert(KipuBankV3.CapExceeded.selector);
        bank.depositUsdc(cap + 1);
        vm.stopPrank();
    }

    /// @notice Test multiple deposits approaching cap
    function test_multiple_deposits_approaching_cap() public {
        vm.prank(admin);
        bank.setBankCapUsd6(1000 * 10 ** 6);
        
        vm.startPrank(user);
        usdc.approve(address(bank), 1000 * 10 ** 6);
        
        // First deposit: 600 USDC
        bank.depositUsdc(600 * 10 ** 6);
        assertEq(bank.totalDepositedUsd6(), 600 * 10 ** 6);
        
        // Second deposit: 300 USDC (total 900)
        bank.depositUsdc(300 * 10 ** 6);
        assertEq(bank.totalDepositedUsd6(), 900 * 10 ** 6);
        
        // Third deposit: 101 USDC would exceed cap
        vm.expectRevert(KipuBankV3.CapExceeded.selector);
        bank.depositUsdc(101 * 10 ** 6);
        vm.stopPrank();
    }

    /// @notice Test balanceOfUsdc view function
    function test_balanceOfUsdc_view() public {
        vm.startPrank(user);
        usdc.approve(address(bank), 500 * 10 ** 6);
        bank.depositUsdc(500 * 10 ** 6);
        vm.stopPrank();
        
        uint256 balance = bank.balanceOfUsdc(user);
        assertEq(balance, 500 * 10 ** 6);
    }

    /// @notice Test balanceOfUsdc for address with no deposits
    function test_balanceOfUsdc_zero_balance() public view {
        uint256 balance = bank.balanceOfUsdc(nonAdmin);
        assertEq(balance, 0);
    }
}