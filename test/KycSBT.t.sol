// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/interfaces/IKycSBT.sol";

// success
contract KycSBTTest is Test {
    KycSBT public kycSBT;
    KycResolver public resolver;
    ENS public ens;

    address public owner = address(1);
    address public admin = address(2);
    address public user = address(3);

    event KycRequested(address indexed user, string ensName);
    event AddressApproved(address indexed user, IKycSBT.KycLevel level);
    event KycStatusUpdated(address indexed user, IKycSBT.KycStatus status);
    event KycLevelUpdated(address indexed user, IKycSBT.KycLevel oldLevel, IKycSBT.KycLevel newLevel);
    event AddrChanged(bytes32 indexed node, address addr);
    event KycStatusChanged(bytes32 indexed node, bool isValid, uint8 level);
    event KycRevoked(address indexed user);

    function setUp() public {
        vm.startPrank(owner);
        
        // 1. 部署 ENS Registry
        ens = ENS(address(new ENSRegistry()));
        
        // 2. 部署解析器
        resolver = new KycResolver(ens);
        
        // 3. 部署并初始化 KycSBT
        kycSBT = new KycSBT();
        kycSBT.initialize();
        
        // 4. 设置 ENS 和解析器
        kycSBT.setENSAndResolver(address(ens), address(resolver));
        
        // 5. 设置 ENS 域名
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        ENSRegistry(address(ens)).setSubnodeOwner(bytes32(0), keccak256("hsk"), owner);
        
        // 6. 设置解析器
        ens.setResolver(hskNode, address(resolver));
        
        // 7. 添加管理员
        kycSBT.addAdmin(admin);
        
        // 8. 授权 KycSBT 合约可以操作 resolver
        resolver.transferOwnership(address(kycSBT));
        
        // 9. 将 .hsk 域名所有权转移给 KycSBT
        ENSRegistry(address(ens)).setSubnodeOwner(bytes32(0), keccak256("hsk"), address(kycSBT));
        
        vm.stopPrank();
    }

    function testInitialize() public {
        assertEq(kycSBT.owner(), owner, "Owner should be set correctly");
        assertEq(kycSBT.registrationFee(), 0.01 ether, "Registration fee should be 0.01 ether");
        assertEq(kycSBT.minNameLength(), 5, "Min name length should be 5");
        assertTrue(kycSBT.isAdmin(admin), "Admin should be set");
    }

    function testRequestKyc() public {
        string memory label = "alice";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);

        vm.expectEmit(true, true, true, true);
        emit KycRequested(user, ensName);
        
        kycSBT.requestKyc{value: fee}(ensName);

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

        vm.stopPrank();
    }

    // 测试名称长度验证
    function testRequestKycNameTooShort() public {
        string memory label = "abcd";  // 4个字符，不包括.hsk
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.requestKyc: Name too short");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testApproveKyc() public {
        // 先请求 KYC
        string memory label = "alice1";  // 使用5个字符的名称
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 测试批准
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit AddressApproved(user, IKycSBT.KycLevel.BASIC);
        
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        
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

        vm.stopPrank();
    }

    function testApproveKycWithENS() public {
        string memory label = "alice1";  // 使用5个字符的名称
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // 1. 用户申请 KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 2. owner 批准 KYC，同时会更新 ENS
        vm.startPrank(owner);
        
        // 预期 ENS 相关事件
        vm.expectEmit(true, true, true, true);
        emit AddrChanged(keccak256(bytes(ensName)), user);
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(keccak256(bytes(ensName)), true, uint8(IKycSBT.KycLevel.BASIC));
        
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 3. 验证 ENS 解析器状态
        assertEq(resolver.addr(keccak256(bytes(ensName))), user, "ENS address not set correctly");
        assertTrue(resolver.isValid(keccak256(bytes(ensName))), "ENS KYC status not valid");
        assertEq(resolver.kycLevel(keccak256(bytes(ensName))), uint8(IKycSBT.KycLevel.BASIC), "ENS KYC level not set correctly");

        vm.stopPrank();
    }

    function testRevokeKyc() public {
        // 1. 先完成 KYC 申请和批准流程
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();
        bytes32 ensNode = keccak256(bytes(ensName));

        // 用户申请 KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // owner 批准 KYC
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 2. 测试撤销 KYC
        // 预期事件，按照实际触发顺序排列
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(ensNode, false, uint8(IKycSBT.KycLevel.BASIC));  // 第一个事件
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);  // 第二个事件
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);  // 第三个事件
        
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

    function testRevokeKycRevert() public {
        // 测试撤销未批准的 KYC
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.revokeKyc: Not approved");
        kycSBT.revokeKyc(user);
        vm.stopPrank();

        // 测试非 owner 撤销
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        kycSBT.revokeKyc(user);
        vm.stopPrank();
    }

    function testIsHumanWithENS() public {
        // 1. 完成 KYC 流程
        testApproveKycWithENS();

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

    function _setupEnsName(string memory label) internal returns (bytes32) {
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        bytes32 labelHash = keccak256(bytes(label));
        bytes32 node = keccak256(abi.encodePacked(hskNode, labelHash));
        
        vm.startPrank(owner);
        ENSRegistry(address(ens)).setSubnodeOwner(hskNode, labelHash, owner);
        ens.setResolver(node, address(resolver));
        vm.stopPrank();
        
        return node;
    }
} 