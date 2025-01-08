// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

// success
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
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.setRegistrationFee(newFee);
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // First request KYC to generate fees
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();
        
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
        
        // Record balance before withdrawal
        uint256 balanceBefore = owner.balance;
        uint256 contractBalance = address(kycSBT).balance;
        
        vm.startPrank(owner);
        kycSBT.withdrawFees();
        vm.stopPrank();

        // Verify balance after withdrawal
        assertEq(owner.balance, balanceBefore + contractBalance, "Owner balance not updated correctly");
        assertEq(address(kycSBT).balance, 0, "Contract balance should be 0");
    }

    function testWithdrawFeesNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.withdrawFees();
        vm.stopPrank();
    }

    function testWithdrawFeesNoBalance() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.withdrawFees: No fees to withdraw");
        kycSBT.withdrawFees();
        vm.stopPrank();
    }
} 