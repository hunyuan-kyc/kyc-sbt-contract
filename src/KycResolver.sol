// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "./interfaces/IKycResolver.sol";

/**
 * @title KYC Resolver Contract
 * @notice ENS resolver that stores KYC verification status and address records
 * @dev Implements ENS resolution for KYC verification status
 */
contract KycResolver is IKycResolver, Ownable {
    ENS public immutable ens;
    
    // ENS node mappings
    mapping(bytes32 => bool) public isValidated;     // KYC validation status
    mapping(bytes32 => uint8) public kycLevels;      // KYC level for each node
    mapping(bytes32 => uint256) public validUntil;   // Expiration timestamp
    mapping(bytes32 => address) public ensAddrs;     // Address records

    constructor(ENS _ens) Ownable(msg.sender) {
        ens = _ens;
    }

    /**
     * @dev Checks if caller is authorized to modify the node
     * @param node ENS node hash
     */
    modifier authorised(bytes32 node) {
        require(msg.sender == owner() || ens.isApprovedForAll(ens.owner(node), msg.sender));
        _;
    }

    function setAddr(bytes32 node, address _addr) public authorised(node) {
        ensAddrs[node] = _addr;
        emit AddrChanged(node, _addr);
    }

    function addr(bytes32 node) public view returns (address) {
        return ensAddrs[node];
    }

    function setKycStatus(
        bytes32 node,
        bool _isValid,
        uint8 level,
        uint256 expiry
    ) external override onlyOwner {
        isValidated[node] = _isValid;
        kycLevels[node] = level;
        validUntil[node] = expiry;
        
        emit KycStatusChanged(node, _isValid, level);
    }

    function kycLevel(bytes32 node) external view override returns (uint8) {
        return kycLevels[node];
    }

    function isValid(bytes32 node) external view override returns (bool) {
        return isValidated[node] && block.timestamp <= validUntil[node];
    }

    function expirationTime(bytes32 node) external view override returns (uint256) {
        return validUntil[node];
    }
} 