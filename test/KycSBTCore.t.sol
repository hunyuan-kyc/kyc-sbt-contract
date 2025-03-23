// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTCoreTest is KycSBTTest {
    function testRequestKycNormalName() public {
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 totalFee = _getTotalFee();

        // First approve the user
        vm.prank(owner);
        kycSBT.approveKyc(user, 1); // Approve with BASIC level

        vm.startPrank(user);
        vm.deal(user, totalFee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: totalFee}(ensName);

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, ensName, "ENS name mismatch");
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
        assertEq(uint8(kycLevel), 1, "Level should be BASIC");
        assertGt(createTime, 0, "Create time should be set");

        vm.stopPrank();
    }

    function testRevokeKyc() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve the user
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);

        // Test self-revocation
        bytes32 node = keccak256(bytes(ensName));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        
        kycSBT.revokeKyc(user);

        // Verify state
        (
            ,
            ,
            IKycSBT.KycStatus kycStatus,
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.REVOKED), "Status should be REVOKED");
        vm.stopPrank();

        // Test owner revocation should fail when already revoked
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Not approved");
        kycSBT.revokeKyc(user);
        vm.stopPrank();
    }

    function testOwnerRevokeKyc() public {
        string memory ensName = "alice2.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve the user
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        vm.stopPrank();

        // Test owner revocation
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        
        kycSBT.revokeKyc(user);

        (
            ,
            ,
            IKycSBT.KycStatus kycStatus,
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.REVOKED), "Status should be REVOKED");
        vm.stopPrank();
    }

    function testSetValidityPeriod() public {
        uint256 newPeriod = 180 days;
        
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ValidityPeriodUpdated(newPeriod);
        
        kycSBT.setValidityPeriod(newPeriod);
        assertEq(kycSBT.validityPeriod(), newPeriod, "Validity period not updated");
        vm.stopPrank();
    }

    function testSetValidityPeriodNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.setValidityPeriod(180 days);
        vm.stopPrank();
    }

    function testSetInvalidValidityPeriod() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Invalid period");
        kycSBT.setValidityPeriod(0);
        vm.stopPrank();
    }

    function testApproveNewUser() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit KycApprovalPending(user, 2);
        
        kycSBT.approveKyc(user, 2);
        
        assertEq(kycSBT.pendingApprovals(user), 2, "Pending approval not set");
        
        vm.stopPrank();
    }


    function testApproveAfterRevoke() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve and register
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        
        // Revoke KYC
        kycSBT.revokeKyc(user);
        vm.stopPrank();

        // Re-approve with new level
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.APPROVED);
        
        vm.expectEmit(true, true, true, true);
        emit AddressApproved(user, IKycSBT.KycLevel(3));
        
        kycSBT.approveKyc(user, 3);

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, ensName, "ENS name should remain unchanged");
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
        assertEq(uint8(kycLevel), 3, "Level should be updated to 3");

        // Verify isHuman returns correct values
        (bool isHuman, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isHuman, "Should be verified as human");
        assertEq(level, 3, "Should have level 3");
        
        vm.stopPrank();
    }
} 