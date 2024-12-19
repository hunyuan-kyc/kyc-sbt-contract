// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTFeeTest is KycSBTTest {
    function testSetRegistrationFee() public {
        uint256 newFee = 0.02 ether;
        
        vm.startPrank(owner);
        kycSBT.setRegistrationFee(newFee);
        vm.stopPrank();

        assertEq(kycSBT.registrationFee(), newFee);
    }

    function testSetRegistrationFeeNotOwner() public {
        uint256 newFee = 0.02 ether;
        
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        kycSBT.setRegistrationFee(newFee);
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // 先进行一次 KYC 请求来产生费用
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 记录提现前的余额
        uint256 balanceBefore = owner.balance;
        uint256 contractBalance = address(kycSBT).balance;
        
        vm.startPrank(owner);
        kycSBT.withdrawFees();
        vm.stopPrank();

        // 验证提现后的余额
        assertEq(owner.balance, balanceBefore + contractBalance, "Owner balance not updated correctly");
        assertEq(address(kycSBT).balance, 0, "Contract balance should be 0");
    }

    function testWithdrawFeesNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        kycSBT.withdrawFees();
        vm.stopPrank();
    }

    function testWithdrawFeesNoBalance() public {
        vm.startPrank(owner);
        vm.expectRevert("No fees to withdraw");
        kycSBT.withdrawFees();
        vm.stopPrank();
    }

    // ... 其他费用相关测试 ...
} 