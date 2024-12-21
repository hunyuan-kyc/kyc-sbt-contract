// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

// success
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
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.addAdmin(newAdmin);
        vm.stopPrank();
    }

    function testAddExistingAdmin() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.addAdmin: Already admin");
        kycSBT.addAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveAdmin() public {
        address newAdmin = address(4);
        vm.startPrank(owner);
        kycSBT.addAdmin(newAdmin);
        
        kycSBT.removeAdmin(admin);
        vm.stopPrank();

        assertFalse(kycSBT.isAdmin(admin));
        assertEq(kycSBT.adminCount(), 1);
    }

    function testRemoveAdminNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.removeAdmin(admin);
        vm.stopPrank();
    }

    function testRemoveNonAdmin() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.removeAdmin: Not admin");
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
        vm.expectRevert("KycSBT.onlyAdmin: Not admin");
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
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
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
        vm.expectRevert("KycSBT.whenNotPaused: Contract is paused");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testCannotRemoveLastAdmin() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.removeAdmin: Cannot remove last admin");
        kycSBT.removeAdmin(admin);  // admin 是唯一的管理员
        vm.stopPrank();
    }

    function testMultipleAdmins() public {
        address newAdmin1 = address(4);
        address newAdmin2 = address(5);
        
        vm.startPrank(owner);
        // 添加两个新管理员
        kycSBT.addAdmin(newAdmin1);
        kycSBT.addAdmin(newAdmin2);
        
        // 验证管理员数量
        assertEq(kycSBT.adminCount(), 3);
        assertTrue(kycSBT.isAdmin(admin));
        assertTrue(kycSBT.isAdmin(newAdmin1));
        assertTrue(kycSBT.isAdmin(newAdmin2));

        // 移除一个管理员
        kycSBT.removeAdmin(newAdmin1);
        assertEq(kycSBT.adminCount(), 2);
        assertFalse(kycSBT.isAdmin(newAdmin1));
        vm.stopPrank();
    }

    function testPausedAdminOperations() public {
        // 先暂停合约
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // 测试暂停状态下的管理员操作
        vm.startPrank(admin);
        
        // 管理员仍然可以执行某些操作
        kycSBT.emergencyPause();  // 这应该可以执行
        
        vm.stopPrank();
        
        // 但用户操作应该被阻止
        vm.startPrank(user);
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.whenNotPaused: Contract is paused");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testAdminPermissions() public {
        // 测试管理员的权限范围
        vm.startPrank(admin);
        
        // 管理员不能执行 owner 专属操作
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        kycSBT.setRegistrationFee(0.02 ether);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        kycSBT.emergencyUnpause();
        
        // 但可以执行管理员操作
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());
        
        vm.stopPrank();
    }

    function testOwnerPrivileges() public {
        vm.startPrank(owner);
        
        // owner 可以执行所有操作
        kycSBT.setRegistrationFee(0.02 ether);
        assertEq(kycSBT.registrationFee(), 0.02 ether);
        
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());
        
        kycSBT.emergencyUnpause();
        assertFalse(kycSBT.paused());
        
        vm.stopPrank();
    }
} 