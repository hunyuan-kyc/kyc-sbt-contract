// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTMainTest is KycSBTTest {
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

        bytes32 kycDataHash = keccak256(abi.encodePacked(uint256(1), uint256(19900101), keccak256(abi.encodePacked("test_salt"))));
        kycSBT.requestKyc{value: totalFee}(ensName, kycDataHash);

        (bool isHuman, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isHuman, "Should be verified as human");
        assertEq(level, 1, "Should have BASIC level");

        vm.stopPrank();
    }

    function testKycDataVerificationAndIsHuman() public {
        string memory ensName = "testuser.hsk";
        uint256 totalFee = _getTotalFee();

        // KYC Data
        uint256 countryCode = 1; // Example country code
        uint256 dateOfBirth = 20000101; // YYYYMMDD
        bytes32 salt = keccak256(abi.encodePacked("random_salt"));
        bytes32 kycDataHash = keccak256(abi.encodePacked(countryCode, dateOfBirth, salt));

        // Approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 2); // Approve with ADVANCED level

        // Request KYC with data hash
        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(ensName, kycDataHash);
        vm.stopPrank();

        // Verify isHuman
        (bool isHumanStatus, uint8 kycLevel) = kycSBT.isHuman(user);
        assertTrue(isHumanStatus, "User should be human");
        assertEq(kycLevel, 2, "KYC level should be ADVANCED");

        // Verify kycData with correct data
        assertTrue(kycSBT.verifyKycData(user, countryCode, dateOfBirth, salt), "KYC data verification should pass");

        // Verify kycData with incorrect countryCode
        assertFalse(kycSBT.verifyKycData(user, 2, dateOfBirth, salt), "KYC data verification should fail for wrong countryCode");

        // Verify kycData with incorrect dateOfBirth
        assertFalse(kycSBT.verifyKycData(user, countryCode, 20010101, salt), "KYC data verification should fail for wrong dateOfBirth");

        // Verify kycData with incorrect salt
        assertFalse(kycSBT.verifyKycData(user, countryCode, dateOfBirth, keccak256(abi.encodePacked("wrong_salt"))), "KYC data verification should fail for wrong salt");

        // Revoke KYC
        vm.prank(owner);
        kycSBT.revokeKyc(user);

        // Verify isHuman after revocation
        (isHumanStatus, kycLevel) = kycSBT.isHuman(user);
        assertFalse(isHumanStatus, "User should not be human after revocation");
        assertEq(kycLevel, 0, "KYC level should be 0 after revocation");
    }
}
