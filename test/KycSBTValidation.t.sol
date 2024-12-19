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
        
        vm.expectRevert("Name too short");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testInvalidSuffix() public {
        string memory ensName = "alice1.eth";  // 正确长度但错误后缀
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("Invalid suffix");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testInsufficientFee() public {
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee / 2);  // 只发送一半的费用
        
        vm.expectRevert("Insufficient fee");
        kycSBT.requestKyc{value: fee / 2}(ensName);
        vm.stopPrank();
    }
} 