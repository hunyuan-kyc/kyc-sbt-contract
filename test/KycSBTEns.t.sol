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
        
        // First approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);
        
        vm.startPrank(user);
        vm.deal(user, totalFee);
        
        vm.expectRevert("KycSBT: Short name not approved for sender");
        kycSBT.requestKyc{value: totalFee}(shortName);
        
        vm.stopPrank();
    }

    function testRequestApprovedShortName() public {
        string memory shortName = "abc.hsk";
        uint256 totalFee = kycSBT.getTotalFee();
        
        // First approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);
        
        // Then approve short name
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
        
        // First approve KYC for another user
        vm.prank(owner);
        kycSBT.approveKyc(anotherUser, 1);
        
        // Approve name for another user
        vm.prank(owner);
        kycSBT.approveEnsName(anotherUser, shortName);
        
        // Try to use the name with a different user
        vm.startPrank(user);
        vm.deal(user, totalFee);
        
        vm.expectRevert("KycSBT: Not approved");
        kycSBT.requestKyc{value: totalFee}(shortName);
        
        vm.stopPrank();
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
        uint256 totalFee = _getTotalFee();
        
        // First approve KYC for user1
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);
        
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

        // First approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

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

        // First approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        // First request
        vm.startPrank(user);
        vm.deal(user, totalFee * 2);  // Double the fee for two attempts
        kycSBT.requestKyc{value: totalFee}(ensName);

        // Approve KYC again for second request
        vm.stopPrank();
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        // Second request with same name
        vm.startPrank(user);
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

    function testMultipleRequestKyc() public {
        string memory firstEnsName = "alice1.hsk";
        string memory secondEnsName = "alice2.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve KYC
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        // First request
        vm.startPrank(user);
        vm.deal(user, totalFee * 2);  // Double the fee for two requests
        kycSBT.requestKyc{value: totalFee}(firstEnsName);

        // Verify first registration
        (
            string memory storedName,
            IKycSBT.KycLevel level,
            IKycSBT.KycStatus status,
            
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, firstEnsName, "First ENS name not stored correctly");
        assertEq(uint8(level), 1, "Incorrect KYC level after first request");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Incorrect status after first request");

        // Second request with different name
        kycSBT.requestKyc{value: totalFee}(secondEnsName);

        // Verify second registration
        (
            storedName,
            level,
            status,
            
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, secondEnsName, "Second ENS name not stored correctly");
        assertEq(uint8(level), 1, "KYC level should remain unchanged");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Status should remain approved");

        // Verify old name is no longer registered
        assertEq(kycSBT.ensNameToAddress(firstEnsName), address(0), "Old name should be unregistered");
        assertEq(kycSBT.ensNameToAddress(secondEnsName), user, "New name should be registered");

        vm.stopPrank();
    }

    function testMultipleRequestKycWithLevelChange() public {
        string memory firstEnsName = "alice1.hsk";
        string memory secondEnsName = "alice2.hsk";
        uint256 totalFee = _getTotalFee();

        // First approve KYC with level 1
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        // First request
        vm.startPrank(user);
        vm.deal(user, totalFee * 2);
        kycSBT.requestKyc{value: totalFee}(firstEnsName);
        vm.stopPrank();

        // Approve higher level
        vm.prank(owner);
        kycSBT.approveKyc(user, 2);

        // Second request with new level
        vm.startPrank(user);
        kycSBT.requestKyc{value: totalFee}(secondEnsName);

        // Verify updated level and new name
        (
            string memory storedName,
            IKycSBT.KycLevel level,
            IKycSBT.KycStatus status,
            
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, secondEnsName, "New ENS name not stored correctly");
        assertEq(uint8(level), 2, "KYC level should be updated to 2");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Status should remain approved");

        vm.stopPrank();
    }

    function testMultipleRequestKycWithSingleApproval() public {
        string memory firstEnsName = "alice1.hsk";
        string memory secondEnsName = "alice2.hsk";
        uint256 totalFee = _getTotalFee();

        // Single KYC approval
        vm.prank(owner);
        kycSBT.approveKyc(user, 1);

        // First request
        vm.startPrank(user);
        vm.deal(user, totalFee * 3);  // Triple the fee for three requests
        kycSBT.requestKyc{value: totalFee}(firstEnsName);

        // Verify first registration
        (
            string memory storedName,
            IKycSBT.KycLevel level,
            IKycSBT.KycStatus status,
            
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, firstEnsName, "First ENS name not stored correctly");
        assertEq(uint8(level), 1, "Incorrect KYC level after first request");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Incorrect status after first request");

        // Second request with different name (without additional approval)
        kycSBT.requestKyc{value: totalFee}(secondEnsName);

        // Verify second registration
        (
            storedName,
            level,
            status,
            
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, secondEnsName, "Second ENS name not stored correctly");
        assertEq(uint8(level), 1, "KYC level should remain unchanged");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Status should remain approved");

        // Verify name mappings
        assertEq(kycSBT.ensNameToAddress(firstEnsName), address(0), "Old name should be unregistered");
        assertEq(kycSBT.ensNameToAddress(secondEnsName), user, "New name should be registered");

        // Try third request to verify it still works
        string memory thirdEnsName = "alice3.hsk";
        kycSBT.requestKyc{value: totalFee}(thirdEnsName);

        (storedName, level, status, ) = kycSBT.getKycInfo(user);
        assertEq(storedName, thirdEnsName, "Third ENS name not stored correctly");
        assertEq(uint8(level), 1, "KYC level should still remain unchanged");
        assertEq(uint8(status), uint8(IKycSBT.KycStatus.APPROVED), "Status should still remain approved");

        assertEq(kycSBT.ensNameToAddress(secondEnsName), address(0), "Second name should be unregistered");
        assertEq(kycSBT.ensNameToAddress(thirdEnsName), user, "Third name should be registered");

        vm.stopPrank();
    }
} 