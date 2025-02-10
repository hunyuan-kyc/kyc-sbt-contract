// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ens-contracts/contracts/registry/ENS.sol";
import "./interfaces/IKycSBT.sol";
import "./interfaces/IKycResolver.sol";

abstract contract KycSBTStorage {
    struct KycInfo {
        string ensName;          // ENS domain name
        IKycSBT.KycLevel level;  // KYC level
        IKycSBT.KycStatus status; // KYC status
        uint256 createTime;      // Creation timestamp
    }
    
    // Configuration
    uint256 public registrationFee = 2 ether;  // Fee required for KYC registration (2 HSK)
    uint256 public minNameLength = 5;    // Minimum length required for ENS names
    uint256 public validityPeriod;   // Period for which KYC is valid (in seconds)
    bool public paused;              // Emergency pause flag
    string public suffix = ".hsk";   // Default ENS suffix
    uint256 public ensFee = 2 ether; // ENS registration fee (2 HSK)

    // ENS Configuration
    ENS public ens;                  // ENS Registry contract
    IKycResolver public resolver;    // ENS Resolver contract

    // KYC mappings
    mapping(address => KycInfo) public kycInfos;         // Maps address to KYC info
    mapping(string => address) public ensNameToAddress;  // Maps ENS name to address
    mapping(address => uint8) public pendingApprovals;   // Maps address to pending KYC level

    // ENS name approval mappings
    mapping(address => string) internal approvedEnsNames;  // Maps address to approved ENS name
    mapping(string => bool) internal isNameApproved;       // Maps ENS name to approval status

    // Reserved storage space for future upgrades
    uint256[100] private __gap;
}