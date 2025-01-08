// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/interfaces/IKycSBT.sol";

// Test contract for KycSBT
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
        
        // 1. Deploy ENS Registry
        ens = ENS(address(new ENSRegistry()));
        
        // 2. Deploy resolver
        resolver = new KycResolver(ens);
        
        // 3. Deploy and initialize KycSBT
        kycSBT = new KycSBT();
        kycSBT.initialize();
        
        // 4. Set ENS and resolver
        kycSBT.setENSAndResolver(address(ens), address(resolver));
        
        // 5. Set up ENS domain
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        ENSRegistry(address(ens)).setSubnodeOwner(bytes32(0), keccak256("hsk"), owner);
        
        // 6. Set resolver
        ens.setResolver(hskNode, address(resolver));
        
        // 7. Add admin
        kycSBT.addAdmin(admin);
        
        // 8. Authorize KycSBT contract to operate resolver
        resolver.transferOwnership(address(kycSBT));
        
        // 9. Transfer .hsk domain ownership to KycSBT
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

        // Verify state
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

    // Test name length validation
    function testRequestKycNameTooShort() public {
        string memory label = "abcd";  // 4 characters, excluding .hsk
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        
        vm.expectRevert("KycSBT.requestKyc: Name too short");
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();
    }

    function testApproveKyc() public {
        // First request KYC
        string memory label = "alice1";  // Use 5 character name
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Test approval
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit AddressApproved(user, IKycSBT.KycLevel.BASIC);
        
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);
        
        // Verify state
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
        string memory label = "alice1";  // Use 5 character name
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();

        // 1. User requests KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // 2. Owner approves KYC, which will also update ENS
        vm.startPrank(owner);
        
        // Expect ENS related events
        vm.expectEmit(true, true, true, true);
        emit AddrChanged(keccak256(bytes(ensName)), user);
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(keccak256(bytes(ensName)), true, uint8(IKycSBT.KycLevel.BASIC));
        
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 3. Verify ENS resolver state
        assertEq(resolver.addr(keccak256(bytes(ensName))), user, "ENS address not set correctly");
        assertTrue(resolver.isValid(keccak256(bytes(ensName))), "ENS KYC status not valid");
        assertEq(resolver.kycLevel(keccak256(bytes(ensName))), uint8(IKycSBT.KycLevel.BASIC), "ENS KYC level not set correctly");

        vm.stopPrank();
    }

    function testRevokeKyc() public {
        // 1. Complete KYC request and approval process
        string memory label = "alice1";
        string memory ensName = string(abi.encodePacked(label, ".hsk"));
        uint256 fee = kycSBT.registrationFee();
        bytes32 ensNode = keccak256(bytes(ensName));

        // User requests KYC
        vm.startPrank(user);
        vm.deal(user, fee);
        kycSBT.requestKyc{value: fee}(ensName);
        vm.stopPrank();

        // Owner approves KYC
        vm.startPrank(owner);
        kycSBT.approve(user, IKycSBT.KycLevel.BASIC);

        // 2. Test KYC revocation
        // Expect events in actual trigger order
        vm.expectEmit(true, true, true, true);
        emit KycStatusChanged(ensNode, false, uint8(IKycSBT.KycLevel.BASIC));  // First event
        
        vm.expectEmit(true, true, true, true);
        emit KycStatusUpdated(user, IKycSBT.KycStatus.REVOKED);  // Second event
        
        vm.expectEmit(true, true, true, true);
        emit KycRevoked(user);  // Third event
        
        kycSBT.revokeKyc(user);

        // 3. Verify state
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
        
        // 4. Verify ENS resolver state
        assertFalse(resolver.isValid(ensNode), "ENS KYC status should be invalid");
        assertEq(resolver.addr(ensNode), user, "ENS address should remain unchanged");

        vm.stopPrank();
    }

    function testRevokeKycRevert() public {
        // Test revoking unapproved KYC
        vm.startPrank(owner);
        vm.expectRevert("KycSBT.revokeKyc: Not approved");
        kycSBT.revokeKyc(user);
        vm.stopPrank();

        // Test non-owner revocation
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
        // 1. Complete KYC process
        testApproveKycWithENS();

        // 2. Verify isHuman query
        (bool isValid, uint8 level) = kycSBT.isHuman(user);
        assertTrue(isValid, "Should be valid human");
        assertEq(level, uint8(IKycSBT.KycLevel.BASIC), "Should have BASIC level");

        // 3. Verify non-KYC user
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