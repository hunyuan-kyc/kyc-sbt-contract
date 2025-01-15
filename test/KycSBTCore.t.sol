// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTCoreTest is KycSBTTest {
    function testRequestKyc() public {
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: fee}(ensName);

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

    function testRevokeKyc() public {
        // First request KYC
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);

        // Test self-revocation
        bytes32 node = keccak256(bytes(ensName));
        
        // Expect events in correct order
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
        // Setup: Request and revoke KYC
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        kycSBT.revokeKyc(user);

        // Test self-restoration (temporary for testing)
        vm.expectEmit(true, true, true, true);
        emit KycRestored(user);
        
        kycSBT.restoreKyc(user);

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
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Test owner revocation
        vm.startPrank(owner);
        bytes32 node = keccak256(bytes(ensName));
        
        // Expect events in correct order
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
    }
} 