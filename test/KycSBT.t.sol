// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTMainTest is KycSBTTest {  // 改名并继承自 KycSBTTest
    function testInitialize() public {
        assertEq(kycSBT.registrationFee(), 2 ether, "Registration fee should be 2 HSK");
        assertEq(kycSBT.ensFee(), 2 ether, "ENS fee should be 2 HSK");
        assertEq(kycSBT.minNameLength(), 5, "Min name length should be 5");
        assertEq(kycSBT.validityPeriod(), 365 days, "Validity period should be 365 days");
    }

    function testRequestKyc() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve the user
        vm.prank(owner);
        kycSBT.approveKyc(user, 1); // Approve with BASIC level

        vm.startPrank(user);
        vm.deal(user, totalFee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: totalFee}(ensName);

        (bool isHuman, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isHuman, "Should be verified as human");
        assertEq(level, 1, "Should have BASIC level");

        vm.stopPrank();
    }
} 