// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

// Test contract for validation-related functionality
contract KycSBTValidationTest is KycSBTTest {
    function testRequestKycNameTooShort() public {
        string memory label = "abcd";  // 4 characters
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.requestKyc: Name too short");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testInvalidSuffix() public {
        string memory ensName = "alice1.eth";  // Correct length but wrong suffix
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.requestKyc: Invalid suffix");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testInsufficientFee() public {
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee / 2);  // Only send half of the required fee
        
        vm.expectRevert("KycSBT.requestKyc: Insufficient fee");
        kycSBT.requestKyc{value: fee / 2}(ensName);
        vm.stopPrank();
    }

    function testSetSuffix() public {
        string memory newSuffix = ".kyc";
        
        vm.startPrank(owner);
        kycSBT.setSuffix(newSuffix);
        vm.stopPrank();

        assertEq(kycSBT.suffix(), newSuffix);
    }

    function testSetSuffixNotOwner() public {
        string memory newSuffix = ".kyc";

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.setSuffix(newSuffix);
        vm.stopPrank();
    }

    function testSetInvalidSuffix() public {
        vm.startPrank(owner);
        
        // Test empty suffix
        vm.expectRevert("KycSBT.setSuffix: Invalid suffix");
        kycSBT.setSuffix("");

        // Test suffix without dot
        vm.expectRevert("KycSBT.setSuffix: Suffix must start with dot");
        kycSBT.setSuffix("hsk");
        
        vm.stopPrank();
    }

    function testRequestKycWithNewSuffix() public {
        // Set new suffix
        string memory newSuffix = ".kyc";
        vm.startPrank(owner);
        kycSBT.setSuffix(newSuffix);
        vm.stopPrank();

        // Request KYC with new suffix
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, newSuffix));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel level,
            IKycSBT.KycStatus status,
            uint256 expiry,
            bytes32 ensNode,
            bool whitelisted
        ) = kycSBT.kycInfos(user);

        assertEq(storedName, ensName, "ENS name mismatch");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.PENDING), "Status should be PENDING");
        assertFalse(whitelisted, "Should not be whitelisted");
    }
} 