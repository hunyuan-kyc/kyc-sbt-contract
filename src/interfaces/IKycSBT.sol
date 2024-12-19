// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKycSBT {
    enum KycLevel { NONE, BASIC, ADVANCED, PREMIUM }
    enum KycStatus { NONE, PENDING, APPROVED, REJECTED, REVOKED }

    // Events
    event KycRequested(address indexed user, string ensName);
    event KycLevelUpdated(address indexed user, KycLevel oldLevel, KycLevel newLevel);
    event KycStatusUpdated(address indexed user, KycStatus status);
    event KycRevoked(address indexed user);
    event AddressApproved(address indexed user, KycLevel level);

    // Core functions
    function requestKyc(string calldata ensName) external payable;
    function approve(address user, KycLevel level) external;
    function revokeKyc(address user) external;
    function isHuman(address account) external view returns (bool, uint8);

    // ... 其他管理函数 ...
}