// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKycSBT {
    // @dev KYC levels from lowest to highest
    enum KycLevel { NONE, BASIC, ADVANCED, PREMIUM, ULTIMATE }
    
    // @dev Only store APPROVED(1) and REVOKED(2) on-chain
    enum KycStatus { NONE, APPROVED, REVOKED }

    // Events
    event KycRequested(address indexed user, string ensName);
    event KycLevelUpdated(address indexed user, KycLevel oldLevel, KycLevel newLevel);
    event KycStatusUpdated(address indexed user, KycStatus status);
    event KycRevoked(address indexed user);
    event KycRestored(address indexed user);
    event AddressApproved(address indexed user, KycLevel level);
    event ValidityPeriodUpdated(uint256 newPeriod);
    event RegistrationFeeUpdated(uint256 newFee);
    event EnsFeeUpdated(uint256 newFee);
    event EnsNameApproved(address indexed user, string ensName);

    // Core functions
    function requestKyc(string calldata ensName) external payable;
    function revokeKyc(address user) external;
    function restoreKyc(address user) external;
    function isHuman(address account) external view returns (bool, uint8);
    function getKycInfo(address account) external view returns (
        string memory ensName,
        KycLevel level,
        KycStatus status,
        uint256 createTime
    );

    // ENS name approval functions
    function approveEnsName(address user, string calldata ensName) external;
    function isEnsNameApproved(address user, string calldata ensName) external view returns (bool);

    // Configuration functions
    function setValidityPeriod(uint256 newPeriod) external;
    function setRegistrationFee(uint256 newFee) external;
    function setEnsFee(uint256 newFee) external;
    function getTotalFee() external view returns (uint256);
}