// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

// success
contract KycSBTFeeTest is KycSBTTest {
    function testInitialFees() public {
        assertEq(kycSBT.registrationFee(), 2 ether, "Initial registration fee should be 2 HSK");
        assertEq(kycSBT.ensFee(), 2 ether, "Initial ENS fee should be 2 HSK");
    }

    function testSetRegistrationFee() public {
        uint256 newFee = 3 ether;
        
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit RegistrationFeeUpdated(newFee);
        
        kycSBT.setRegistrationFee(newFee);
        assertEq(kycSBT.registrationFee(), newFee, "Registration fee not updated");
        vm.stopPrank();
    }

    function testSetEnsFee() public {
        uint256 newFee = 3 ether;
        
        vm.startPrank(owner);
        
        // Expect event emission
        vm.expectEmit(true, false, false, true, address(kycSBT));
        emit EnsFeeUpdated(newFee);
        
        kycSBT.setEnsFee(newFee);
        
        // Verify fee update
        assertEq(kycSBT.ensFee(), newFee, "ENS fee not updated");
        
        vm.stopPrank();
    }

    function testSetEnsFeeEvent() public {
        uint256 newFee = 3 ether;
        
        vm.startPrank(owner);
        
        // Record logs for verification
        vm.recordLogs();
        
        kycSBT.setEnsFee(newFee);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        require(entries.length > 0, "No events emitted");
        
        // Verify event signature and data
        bytes32 expectedTopic = keccak256("EnsFeeUpdated(uint256)");
        assertEq(entries[0].topics[0], expectedTopic, "Wrong event signature");
        
        uint256 emittedFee = abi.decode(entries[0].data, (uint256));
        assertEq(emittedFee, newFee, "Wrong fee in event");
        
        vm.stopPrank();
    }

    function testSetFeeNotOwner() public {
        vm.startPrank(user);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.setRegistrationFee(3 ether);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.setEnsFee(3 ether);
        
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        // First request KYC to generate fees
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();
        
        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
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

    function testInsufficientTotalFee() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();
        
        vm.startPrank(user);
        vm.deal(user, totalFee - 1);
        
        vm.expectRevert("KycSBT.requestKyc: Insufficient fee");
        kycSBT.requestKyc{value: totalFee - 1}(ensName);
        vm.stopPrank();
    }

    function testExcessFeeRefund() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();
        uint256 excess = 1 ether;
        
        // Start with clean state
        vm.deal(address(kycSBT), 0);
        vm.deal(user, 0);
        
        vm.startPrank(user);
        
        // Set initial balance and record it
        vm.deal(user, totalFee + excess);
        uint256 balanceBefore = user.balance;
        
        // Send transaction with excess fee
        kycSBT.requestKyc{value: totalFee + excess}(ensName);
        
        // Verify user balance after refund
        assertEq(
            user.balance, 
            balanceBefore - totalFee, 
            "Excess fee should be refunded"
        );
        
        // Verify contract balance
        assertEq(
            address(kycSBT).balance,
            totalFee,
            "Contract should only keep required fee"
        );
        
        vm.stopPrank();
    }

    function testSetBothFees() public {
        uint256 newRegFee = 3 ether;
        uint256 newEnsFee = 4 ether;
        
        vm.startPrank(owner);
        
        // Test registration fee update
        vm.expectEmit(true, false, false, true, address(kycSBT));
        emit RegistrationFeeUpdated(newRegFee);
        kycSBT.setRegistrationFee(newRegFee);
        assertEq(kycSBT.registrationFee(), newRegFee, "Registration fee not updated");
        
        // Test ENS fee update
        vm.expectEmit(true, false, false, true, address(kycSBT));
        emit EnsFeeUpdated(newEnsFee);
        kycSBT.setEnsFee(newEnsFee);
        assertEq(kycSBT.ensFee(), newEnsFee, "ENS fee not updated");
        
        // Verify total fee
        assertEq(_getTotalFee(), newRegFee + newEnsFee, "Total fee incorrect");
        
        vm.stopPrank();
    }
} 