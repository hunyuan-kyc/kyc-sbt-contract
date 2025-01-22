// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTCoreTest is KycSBTTest {
    function testRequestKycNormalName() public {
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 totalFee = _getTotalFee();

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
        assertEq(uint8(kycLevel), uint8(IKycSBT.KycLevel.BASIC), "Level should be BASIC");
        assertGt(createTime, 0, "Create time should be set");

        vm.stopPrank();
    }

    function testRequestKycShortName() public {
        string memory label = "abc";  // 3 characters
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 totalFee = _getTotalFee();

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
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.PENDING), "Status should be PENDING");
        assertEq(uint8(kycLevel), uint8(IKycSBT.KycLevel.BASIC), "Level should be BASIC");
        assertGt(createTime, 0, "Create time should be set");

        vm.stopPrank();
    }

    function testApproveKyc() public {
        // First request KYC with short name
        string memory ensName = "abc.hsk";
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        vm.stopPrank();

        // Test owner approval
        vm.startPrank(owner);
        
        bytes32 node = keccak256(bytes(ensName));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(node, true, uint8(IKycSBT.KycLevel.BASIC));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.APPROVED);
        
        vm.expectEmit(true, true, true, true);
        emit AddressApproved(user, IKycSBT.KycLevel.BASIC);
        
        kycSBT.approveKyc(user);

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
        vm.stopPrank();
    }

    function testApproveKycNotOwner() public {
        string memory ensName = "abc.hsk";
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.approveKyc(user);
        vm.stopPrank();
    }

    function testRevokeKyc() public {
        // First request KYC
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);

        // Test self-revocation
        bytes32 node = keccak256(bytes(ensName));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(node, false, uint8(IKycSBT.KycLevel.BASIC));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        
        kycSBT.revokeKyc(user);

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.REVOKED), "Status should be REVOKED");
        vm.stopPrank();

        // Test owner revocation should fail when already revoked
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Not approved");
        kycSBT.revokeKyc(user);
        vm.stopPrank();
    }

    function testRestoreKyc() public {
        // First request KYC
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        kycSBT.revokeKyc(user);

        // Test restoration
        vm.expectEmit(true, true, true, true);
        emit KycRestored(user);
        
        kycSBT.restoreKyc(user);

        (
            ,
            ,
            IKycSBT.KycStatus kycStatus,
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
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

    // Add new test for owner revocation
    function testOwnerRevokeKyc() public {
        // First request KYC
        string memory ensName = "alice2.hsk";
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName);
        vm.stopPrank();

        // Test owner revocation
        vm.startPrank(owner);
        bytes32 node = keccak256(bytes(ensName));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(node, false, uint8(IKycSBT.KycLevel.BASIC));
        
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
} 