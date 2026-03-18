// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");

    function setUp() public {
        vm.startPrank(owner);
        // vm.deal(owner, 3e18);
        // Deploy the RebaseToken contract
        rebaseToken = new RebaseToken();
        // Deploy the Vault contract, passing the address of the RebaseToken contract
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        // (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        // 2. Check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("Start balance:", startBalance);
        assertEq(startBalance, amount);
        // 3. Warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user1);
        assertGt(middleBalance, startBalance);
        // 4. Warp the time again by the same amount again and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user1);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user1), amount);
        // 2. Redeem
        vault.redeem(type(uint256).max);
        // 3. Check the balance is zero
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(address(user1).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.deal(user1, depositAmount);
        vm.prank(user1);
        vault.deposit{value: depositAmount}();
        assertEq(rebaseToken.balanceOf(user1), depositAmount);

        // 2. Warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user1);
        // 2. (b) Add the rewards to the vault
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        // 3. Redeem
        vm.prank(user1);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user1).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }
}
