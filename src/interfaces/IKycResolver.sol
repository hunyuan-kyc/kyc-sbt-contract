// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKycResolver {
    event AddrChanged(bytes32 indexed node, address addr);
    event KycStatusChanged(bytes32 indexed node, bool isValid, uint8 level);

    function setAddr(bytes32 node, address addr) external;
    function addr(bytes32 node) external view returns (address);
    function kycLevel(bytes32 node) external view returns (uint8);
    function isValid(bytes32 node) external view returns (bool);
    function expirationTime(bytes32 node) external view returns (uint256);
    function setKycStatus(bytes32 node, bool isValid, uint8 level, uint256 expiry) external;
} 