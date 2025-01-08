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
        // Test pause by owner
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();
        assertTrue(kycSBT.paused());

        // Test pause by admin
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
        // Pause first
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());

        // Test unpause
        kycSBT.emergencyUnpause();
        assertFalse(kycSBT.paused());
        vm.stopPrank();
    }

    function testEmergencyUnpauseNotOwner() public {
        // Pause first
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // Test admin cannot unpause
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        kycSBT.emergencyUnpause();
        vm.stopPrank();
    }

    function testPausedOperations() public {
        // Pause first
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // Test operations when paused
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
        kycSBT.removeAdmin(admin);  // admin is the only admin
        vm.stopPrank();
    }

    function testMultipleAdmins() public {
        address newAdmin1 = address(4);
        address newAdmin2 = address(5);
        
        vm.startPrank(owner);
        // Add two new admins
        kycSBT.addAdmin(newAdmin1);
        kycSBT.addAdmin(newAdmin2);
        
        // Verify admin count
        assertEq(kycSBT.adminCount(), 3);
        assertTrue(kycSBT.isAdmin(admin));
        assertTrue(kycSBT.isAdmin(newAdmin1));
        assertTrue(kycSBT.isAdmin(newAdmin2));

        // Remove an admin
        kycSBT.removeAdmin(newAdmin1);
        assertEq(kycSBT.adminCount(), 2);
        assertFalse(kycSBT.isAdmin(newAdmin1));
        vm.stopPrank();
    }

    function testPausedAdminOperations() public {
        // Pause contract first
        vm.startPrank(owner);
        kycSBT.emergencyPause();
        vm.stopPrank();

        // Test admin operations when paused
        vm.startPrank(admin);
        
        // Admins can still perform certain operations
        kycSBT.emergencyPause();  // This should be possible
        
        vm.stopPrank();
        
        // But user operations should be blocked
        vm.startPrank(user);
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.whenNotPaused: Contract is paused");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testAdminPermissions() public {
        // Test admin's permission scope
        vm.startPrank(admin);
        
        // Admins cannot perform owner-exclusive operations
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        kycSBT.setRegistrationFee(0.02 ether);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        kycSBT.emergencyUnpause();
        
        // But can perform admin operations
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());
        
        vm.stopPrank();
    }

    function testOwnerPrivileges() public {
        vm.startPrank(owner);
        
        // Owner can perform all operations
        kycSBT.setRegistrationFee(0.02 ether);
        assertEq(kycSBT.registrationFee(), 0.02 ether);
        
        kycSBT.emergencyPause();
        assertTrue(kycSBT.paused());
        
        kycSBT.emergencyUnpause();
        assertFalse(kycSBT.paused());
        
        vm.stopPrank();
    }
} 