// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/console.sol";
import "./KycSBTTest.sol";

// Test contract for core KYC functionality
contract KycSBTCoreTest is KycSBTTest {
    function testRequestKyc() public {
        string memory label = "alice1";  // 6 characters
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 expiry,
            bytes32 ensNode,
            bool whitelisted
        ) = kycSBT.kycInfos(user);

        assertEq(storedName, ensName, "ENS name mismatch");
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.PENDING), "Status should be PENDING");
        assertFalse(whitelisted, "Should not be whitelisted");
    }

    function testApproveKyc() public {
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // User requests KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Owner approves
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        vm.stopPrank();

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 expiry,
            bytes32 storedNode,
            bool whitelisted
        ) = kycSBT.kycInfos(user);

        assertTrue(whitelisted, "Should be whitelisted");
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
        
        (bool isValid, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isValid, "Should be valid human");
        assertEq(level, uint8(IKycSBT.KycLevel.BASIC), "Should have BASIC level");
    }

    function testRevokeKyc() public {
        // 1. Complete KYC request and approval process
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // User requests KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Owner approves KYC
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 2. Test KYC revocation
        bytes32 ensNode = keccak256(bytes(ensName));
        
        // Expect events in actual trigger order
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(ensNode, false, uint8(IKycSBT.KycLevel.BASIC));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        
        kycSBT.revokeKyc(user);

        // 3. Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 expiry,
            bytes32 storedNode,
            bool whitelisted
        ) = kycSBT.kycInfos(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.REVOKED), "Status should be REVOKED");
        assertFalse(whitelisted, "Should not be whitelisted");
        
        // 4. Verify ENS resolver state
        assertFalse(resolver.isValid(ensNode), "ENS KYC status should be invalid");
        assertEq(resolver.addr(ensNode), user, "ENS address should remain unchanged");

        vm.stopPrank();
    }

    function testIsHumanWithENS() public {
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // User requests KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Owner approves
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        vm.stopPrank();

        // Verify isHuman query
        (bool isValid, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isValid, "Should be valid human");
        assertEq(level, uint8(IKycSBT.KycLevel.BASIC), "Should have BASIC level");

        // Verify non-KYC user
        address nonKycUser = address(4);
        (isValid, level) = kycSBT.isHuman(nonKycUser);
        assertFalse(isValid, "Should not be valid human");
        assertEq(level, 0, "Should have NO level");
    }
} 