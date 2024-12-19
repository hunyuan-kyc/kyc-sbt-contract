// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@ens-contracts/contracts/registry/ENS.sol";
import "./interfaces/IKycSBT.sol";
import "./interfaces/IKycResolver.sol";

abstract contract KycSBTStorage {
    struct KycInfo {
        string ensName;          // ENS 域名
        IKycSBT.KycLevel level;  // KYC 等级
        IKycSBT.KycStatus status; // KYC 状态
        uint256 expirationTime;  // 过期时间
        bytes32 ensNode;         // ENS 节点 hash
        bool isWhitelisted;      // 是否在白名单中
    }
    
    // Configuration
    uint256 public registrationFee;
    uint256 public minNameLength;
    uint256 public validityPeriod;
    bool public paused;
    
    // ENS Configuration
    ENS public ens;
    IKycResolver public resolver;
    
    // Admin management
    mapping(address => bool) public isAdmin;
    uint256 public adminCount;
    
    // KYC mappings
    mapping(address => KycInfo) public kycInfos;        // address => KycInfo
    mapping(string => address) public ensNameToAddress; // ensName => address
    
    uint256[100] private __gap;
}