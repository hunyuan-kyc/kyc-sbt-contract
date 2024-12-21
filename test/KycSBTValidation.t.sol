// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./KycSBTTest.sol";

//success
contract KycSBTValidationTest is KycSBTTest {
    function testRequestKycNameTooShort() public {
        string memory label = "abcd";  // 4个字符
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.requestKyc: Name too short");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testInvalidSuffix() public {
        string memory ensName = "alice1.eth";  // 正确长度但错误后缀
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
        vm.deal(user, fee / 2);  // 只发一半的费用
        
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
        
        // 测试空后缀
        vm.expectRevert("KycSBT.setSuffix: Invalid suffix");
        kycSBT.setSuffix("");

        // 测试不带点的后缀
        vm.expectRevert("KycSBT.setSuffix: Suffix must start with dot");
        kycSBT.setSuffix("hsk");
        
        vm.stopPrank();
    }

    function testRequestKycWithNewSuffix() public {
        // 设置新后缀
        string memory newSuffix = ".kyc";
        vm.startPrank(owner);
        kycSBT.setSuffix(newSuffix);
        vm.stopPrank();

        // 使用新后缀请求 KYC
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, newSuffix));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 验证状态
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