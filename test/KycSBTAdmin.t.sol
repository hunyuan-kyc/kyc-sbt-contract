// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTAdminTest is KycSBTTest {
    function testAddAdmin() public {
        address newAdmin = address(4);
        
        vm.startPrank(owner);
        kycSBT.addAdmin(newAdmin);
        vm.stopPrank();

        assertTrue(kycSBT.isAdmin(newAdmin));
        assertEq(kycSBT.adminCount(), 2);
    }

    function testAddAdminNotOwner() public {
        address newAdmin = address(4);
        
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        kycSBT.addAdmin(newAdmin);
        vm.stopPrank();
    }

    function testAddExistingAdmin() public {
        vm.startPrank(owner);
        vm.expectRevert("Already admin");
        kycSBT.addAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveAdmin() public {
        vm.startPrank(owner);
        kycSBT.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(kycSBT.isAdmin(admin));
        assertEq(kycSBT.adminCount(), 0);
    }

    function testRemoveAdminNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        kycSBT.removeAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveNonAdmin() public {
        vm.startPrank(owner);
        vm.expectRevert("Not admin");
        kycSBT.removeAdmin(user);
        vm.stopPrank();
    }

    function testEmergencyPause() public {
        // 测试 owner 暂停
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();
        assertTrue(kycSBT.paused());

        // 测试 admin 暂停
        vm.startPrank(admin);
        kycSBT.emergencyPause();
        vm.stopPrank();
        assertTrue(kycSBT.paused());
    }

    function testEmergencyPauseNotAuthorized() public {
        vm.startPrank(user);
        vm.expectRevert("Not admin");
        kycSBT.emergencyPause();
        vm.stopPrank();
    }

    function testEmergencyUnpause() public {
        // 先暂停
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());

        // 测试解除暂停
        kycSBT.emergencyUnpause();
        assertFalse(kycSBT.paused());
        vm.stopPrank();
    }

    function testEmergencyUnpauseNotOwner() public {
        // 先暂停
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // 测试 admin 不能解除暂停
        vm.startPrank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        kycSBT.emergencyUnpause();
        vm.stopPrank();
    }

    function testPausedOperations() public {
        // 先暂停
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // 测试暂停状态下的操作
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        vm.expectRevert("Contract is paused");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }
} 