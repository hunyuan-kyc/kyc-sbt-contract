// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
    address public user = address(3);

    event KycRequested(address indexed user, string ensName);
    event KycStatusUpdated(address indexed user, IKycSBT.KycStatus status);
    event KycLevelUpdated(address indexed user, IKycSBT.KycLevel oldLevel, IKycSBT.KycLevel newLevel);
    event AddrChanged(bytes32 indexed node, address addr);
    event KycStatusChanged(bytes32 indexed node, bool isValid, uint8 level);
    event KycRevoked(address indexed user);
    event KycRestored(address indexed user);
    event ValidityPeriodUpdated(uint256 newPeriod);

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy ENS Registry
        ens = ENS(address(new ENSRegistry()));
        
        // Deploy resolver
        resolver = new KycResolver(ens);
        
        // Deploy and initialize KYC SBT
        kycSBT = new KycSBT();
        kycSBT.initialize();
        
        // Configure ENS and resolver
        kycSBT.setENSAndResolver(address(ens), address(resolver));
        
        // Set up ENS domain
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        ENSRegistry(address(ens)).setSubnodeOwner(bytes32(0), keccak256("hsk"), owner);
        
        // Set resolver
        ens.setResolver(hskNode, address(resolver));
        
        // Authorize KYC SBT contract to operate resolver
        resolver.transferOwnership(address(kycSBT));
        
        // Transfer .hsk domain ownership to KYC SBT
        ENSRegistry(address(ens)).setSubnodeOwner(bytes32(0), keccak256("hsk"), address(kycSBT));
        
        vm.stopPrank();
    }

    function testInitialize() public {
        assertEq(kycSBT.owner(), owner, "Owner should be set correctly");
        assertEq(kycSBT.registrationFee(), 0.01 ether, "Registration fee should be 0.01 ether");
        assertEq(kycSBT.minNameLength(), 5, "Min name length should be 5");
        assertEq(kycSBT.validityPeriod(), 365 days, "Validity period should be 365 days");
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

        // Verify state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(storedName, ensName, "ENS name mismatch");
        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");
        assertEq(uint8(kycLevel), uint8(IKycSBT.KycLevel.BASIC), "Level should be BASIC");
        assertGt(createTime, 0, "Create time should be set");

        vm.stopPrank();
    }

    function testRevokeAndRestore() public {
        // First request KYC
        string memory ensName = "alice1.hsk";
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);

        // Test revocation
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);
        kycSBT.revokeKyc(user);

        // Verify revoked state
        (
            string memory storedName,
            IKycSBT.KycLevel kycLevel,
            IKycSBT.KycStatus kycStatus,
            uint256 createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.REVOKED), "Status should be REVOKED");

        // Test restoration
        vm.expectEmit(true, true, true, true);
        emit KycRestored(user);
        kycSBT.restoreKyc(user);

        // Verify restored state
        (
            storedName,
            kycLevel,
            kycStatus,
            createTime
        ) = kycSBT.getKycInfo(user);

        assertEq(uint8(kycStatus), uint8(IKycSBT.KycStatus.APPROVED), "Status should be APPROVED");

        vm.stopPrank();
    }
} 