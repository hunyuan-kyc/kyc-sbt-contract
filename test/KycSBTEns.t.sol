// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

contract KycSBTEnsTest is KycSBTTest {
    function testApproveShortName() public {
        string memory shortName = "abc.hsk";
        
        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true, address(kycSBT));
        emit EnsNameApproved(user, shortName);
        kycSBT.approveEnsName(user, shortName);
        vm.stopPrank();
        
        assertTrue(kycSBT.isEnsNameApproved(user, shortName), "Short name not approved");
    }

    function testRequestShortNameWithoutApproval() public {
        string memory shortName = "abc.hsk";
        uint256 totalFee = kycSBT.getTotalFee();
        
        vm.startPrank(user);
        vm.deal(user, totalFee);
        
        vm.expectRevert("KycSBT: Short name not approved for sender");
        kycSBT.requestKyc{value: totalFee}(shortName);
        
        vm.stopPrank();
    }

    function testRequestApprovedShortName() public {
        string memory shortName = "abc.hsk";
        uint256 totalFee = kycSBT.getTotalFee();
        
        // Approve short name first
        vm.prank(owner);
        kycSBT.approveEnsName(user, shortName);
        
        // Request KYC with approved short name
        vm.startPrank(user);
        vm.deal(user, totalFee);
        
        kycSBT.requestKyc{value: totalFee}(shortName);
        
        // Verify KYC status
        (
            string memory storedName,
            IKycSBT.KycLevel level,
            IKycSBT.KycStatus status,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);
        
        assertEq(storedName, shortName, "ENS name not stored");
        assertEq(uint8(level), uint8(IKycSBT.KycLevel.BASIC), "Incorrect KYC level");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Incorrect KYC status");
        
        vm.stopPrank();
    }

    function testApproveShortNameNotOwner() public {
        string memory shortName = "abc.hsk";
        
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.approveEnsName(user, shortName);
        vm.stopPrank();
    }

    function testApproveShortNameToAnotherUser() public {
        string memory shortName = "abc.hsk";
        address anotherUser = address(4);
        uint256 totalFee = kycSBT.getTotalFee();
        
        // First approve name for another user
        vm.startPrank(owner);
        kycSBT.approveEnsName(anotherUser, shortName);
        vm.stopPrank();
        
        // Try to use the name with a different user
        vm.startPrank(user);
        vm.deal(user, totalFee);
        
        vm.expectRevert("KycSBT: Short name not approved for sender");
        kycSBT.requestKyc{value: totalFee}(shortName);
        
        vm.stopPrank();
        
        // Verify the name is still approved for the original user
        assertTrue(kycSBT.isEnsNameApproved(anotherUser, shortName), "Name should still be approved for original user");
        assertFalse(kycSBT.isEnsNameApproved(user, shortName), "Name should not be approved for other user");
    }

    function testApproveEmptyName() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Empty name");
        kycSBT.approveEnsName(user, "");
        vm.stopPrank();
    }

    function testApproveToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Zero address");
        kycSBT.approveEnsName(address(0), "abc.hsk");
        vm.stopPrank();
    }

    function testApproveAlreadyRegisteredName() public {
        string memory shortName = "abc.hsk";
        uint256 totalFee = kycSBT.getTotalFee();
        
        // First approve and register for user1
        vm.startPrank(owner);
        kycSBT.approveEnsName(user, shortName);
        vm.stopPrank();
        
        vm.startPrank(user);
        vm.deal(user, totalFee);
        kycSBT.requestKyc{value: totalFee}(shortName);
        vm.stopPrank();
        
        // Try to approve same name for another user
        address user2 = address(5);
        vm.startPrank(owner);
        vm.expectRevert("KycSBT: Name already registered");
        kycSBT.approveEnsName(user2, shortName);
        vm.stopPrank();
    }

    function testRequestKycNameTooShort() public {
        string memory shortName = "a.hsk";  // Too short
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);

        vm.expectRevert("KycSBT: Short name not approved for sender");
        kycSBT.requestKyc{value: totalFee}(shortName);

        vm.stopPrank();
    }

    function testRequestKycInvalidSuffix() public {
        string memory invalidName = "alice.eth";  // Wrong suffix
        uint256 totalFee = _getTotalFee();

        vm.startPrank(user);
        vm.deal(user, totalFee);

        vm.expectRevert("KycSBT: Invalid suffix");
        kycSBT.requestKyc{value: totalFee}(invalidName);

        vm.stopPrank();
    }

    function testDuplicateRequest() public {
        string memory ensName = "alice1.hsk";
        uint256 totalFee = _getTotalFee();

        // First request
        vm.startPrank(user);
        vm.deal(user, totalFee * 2);  // Double the fee for two attempts
        kycSBT.requestKyc{value: totalFee}(ensName);

        // Second request with same name
        vm.expectRevert("KycSBT: Name already registered");
        kycSBT.requestKyc{value: totalFee}(ensName);

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
} 