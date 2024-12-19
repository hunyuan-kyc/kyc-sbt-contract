// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/interfaces/IKycSBT.sol";

contract KycSBTTest is Test {
    KycSBT public kycSBT;
    KycResolver public resolver;
    ENS public ens;

    address public owner = address(1);
    address public admin = address(2);
    address public user = address(3);

    // 定义所有事件
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
}