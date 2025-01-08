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
        uint256 expirationTime;  // Expiration timestamp
        bytes32 ensNode;         // ENS node hash
        bool isWhitelisted;      // Whether the address is whitelisted
    }
    
    // Configuration
    uint256 public registrationFee;  // Fee required for KYC registration
    uint256 public minNameLength;    // Minimum length required for ENS names
    uint256 public validityPeriod;   // Period for which KYC is valid
    bool public paused;              // Emergency pause flag
    string public suffix = ".hsk";   // Default ENS suffix

    // ENS Configuration
    ENS public ens;                  // ENS Registry contract
    IKycResolver public resolver;    // ENS Resolver contract
    
    // Admin management
    mapping(address => bool) public isAdmin;    // Admin role mapping
    uint256 public adminCount;                  // Number of admins
    
    // KYC mappings
    mapping(address => KycInfo) public kycInfos;         // Maps address to KYC info
    mapping(string => address) public ensNameToAddress;  // Maps ENS name to address
    
    // Reserved storage space for future upgrades
    uint256[100] private __gap;
}