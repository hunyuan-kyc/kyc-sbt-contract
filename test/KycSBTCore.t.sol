// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/console.sol";
import "./KycSBTTest.sol";

// success
contract KycSBTCoreTest is KycSBTTest {
    function testRequestKyc() public {
        string memory label = "alice1";  // 6个字符
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 验证状态
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

        // 用户请求 KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // owner 批准
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        vm.stopPrank();

        // 验证状态
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
        // 1. 先完成 KYC 申请和批准流程
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // 用户申请 KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // owner 批准 KYC
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 2. 测试撤销 KYC
        bytes32 ensNode = keccak256(bytes(ensName));
        
        // 预期事件，按照实际触发顺序排列
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(ensNode, false, uint8(IKycSBT.KycLevel.BASIC));
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        
        kycSBT.revokeKyc(user);

        // 3. 验证状态
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
        
        // 4. 验证 ENS 解析器状态
        assertFalse(resolver.isValid(ensNode), "ENS KYC status should be invalid");
        assertEq(resolver.addr(ensNode), user, "ENS address should remain unchanged");

        vm.stopPrank();
    }

    function testIsHumanWithENS() public {
        // 1. 先完成 KYC 申请和批准流程
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // 用户申请 KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // owner 批准
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        vm.stopPrank();

        // 2. 验证 isHuman 查询
        (bool isValid, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isValid, "Should be valid human");
        assertEq(level, uint8(IKycSBT.KycLevel.BASIC), "Should have BASIC level");

        // 3. 验证非 KYC 用户
        address nonKycUser = address(4);
        (isValid, level) = kycSBT.isHuman(nonKycUser);
        assertFalse(isValid, "Should not be valid human");
        assertEq(level, 0, "Should have NO level");
    }
} 