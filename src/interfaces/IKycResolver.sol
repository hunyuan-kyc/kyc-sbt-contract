// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IKycResolver {
    event AddrChanged(bytes32 indexed node, address addr); // Parameter name `a` changed to `addr` for clarity
    event KycStatusChanged(
        bytes32 indexed node,
        bool isValid,
        uint8 level,
        uint256 birthDate, // Added: User's birth date as a timestamp
        string region      // Added: User's region
    );

    function setAddr(bytes32 node, address addr) external;
    function addr(bytes32 node) external view returns (address);
    function kycLevel(bytes32 node) external view returns (uint8);
    function isValid(bytes32 node) external view returns (bool);
    function expirationTime(bytes32 node) external view returns (uint256);
    function setKycStatus(
        bytes32 node,
        bool isValid,
        uint8 level,
        uint256 expiry,
        uint256 birthDate,    // Added
        string calldata region // Added
    ) external;

    function birthDate(bytes32 node) external view returns (uint256); // Added getter
    function region(bytes32 node) external view returns (string memory); // Added getter
}