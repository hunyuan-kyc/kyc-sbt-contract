// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/interfaces/IKycSBT.sol";

abstract contract KycSBTTest is Test {
    KycSBT public kycSBT;
    KycResolver public resolver;
    ENS public ens;

    address public owner = address(1);
    address public user = address(3);

    event KycRequested(address indexed user, string ensName);
    event KycLevelUpdated(address indexed user, IKycSBT.KycLevel oldLevel, IKycSBT.KycLevel newLevel);
    event KycStatusUpdated(address indexed user, IKycSBT.KycStatus status);
    event KycRevoked(address indexed user);
    event KycRestored(address indexed user);
    event AddressApproved(address indexed user, IKycSBT.KycLevel level);
    event ValidityPeriodUpdated(uint256 newPeriod);
    event RegistrationFeeUpdated(uint256 newFee);
    event EnsFeeUpdated(uint256 newFee);
    event EnsNameApproved(address indexed user, string ensName);

    function setUp() public virtual {
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

    function _getTotalFee() internal view returns (uint256) {
        return kycSBT.registrationFee() + kycSBT.ensFee();
    }
}