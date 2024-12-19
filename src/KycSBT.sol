// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./KycSBTStorage.sol";
import "./interfaces/IKycSBT.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "./interfaces/IKycResolver.sol";

contract KycSBT is ERC721Upgradeable, OwnableUpgradeable, KycSBTStorage, IKycSBT {
    function initialize() public initializer {
        __ERC721_init("KYC SBT", "KYC");
        __Ownable_init(msg.sender);
        registrationFee = 0.01 ether;
        minNameLength = 5;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || owner() == msg.sender, "Not admin");
        _;
    }

    function requestKyc(string calldata ensName) external payable override whenNotPaused {
        // 验证名称长度（不包括.hsk后缀）
        bytes memory nameBytes = bytes(ensName);
        require(nameBytes.length >= 4, "Name too short"); // 确保至少有 .hsk
        
        // 检查后缀
        require(_hasSuffix(ensName, ".hsk"), "Invalid suffix");
        
        // 计算不包括后缀的长度
        uint256 labelLength = nameBytes.length - 4; // 减去 .hsk 的长度
        require(labelLength >= minNameLength, "Name too short");

        require(msg.value >= registrationFee, "Insufficient fee");
        require(ensNameToAddress[ensName] == address(0), "Name already registered");
        require(kycInfos[msg.sender].status == KycStatus.NONE, "KYC already exists");

        bytes32 node = keccak256(bytes(ensName));
        
        // 创建 KYC 信息
        KycInfo storage info = kycInfos[msg.sender];
        info.ensName = ensName;
        info.level = KycLevel.NONE;
        info.status = KycStatus.PENDING;
        info.expirationTime = block.timestamp + 365 days;
        info.ensNode = node;
        info.isWhitelisted = false;

        ensNameToAddress[ensName] = msg.sender;

        emit KycRequested(msg.sender, ensName);
    }

    function approve(
        address user, 
        KycLevel level
    ) external onlyOwner whenNotPaused {
        require(user != address(0), "Invalid address");
        
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.PENDING, "Invalid status");
        require(!info.isWhitelisted, "Already approved");

        // 更新状态
        info.status = KycStatus.APPROVED;
        info.level = level;
        info.isWhitelisted = true;

        // 更新 ENS 解析器
        resolver.setAddr(info.ensNode, user);
        resolver.setKycStatus(
            info.ensNode,
            true,
            uint8(level),
            info.expirationTime
        );

        emit KycStatusUpdated(user, KycStatus.APPROVED);
        emit KycLevelUpdated(user, KycLevel.NONE, level);
        emit AddressApproved(user, level);
    }

    function revokeKyc(address user) external override onlyOwner {
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.APPROVED, "Not approved");

        // 只更新状态，保留 ENS 信息
        info.status = KycStatus.REVOKED;
        info.isWhitelisted = false;

        // 更新 ENS 解析器状态
        resolver.setKycStatus(
            info.ensNode,
            false,
            uint8(info.level),
            0
        );

        emit KycStatusUpdated(user, KycStatus.REVOKED);
        emit KycRevoked(user);
    }

    function isHuman(address account) external view override returns (bool, uint8) {
        KycInfo memory info = kycInfos[account];
        
        if (info.status == KycStatus.APPROVED &&
            block.timestamp <= info.expirationTime &&
            resolver.isValid(info.ensNode)) {
            return (true, uint8(info.level));
        }
        
        return (false, 0);
    }

    // 管理功能
    function setENSAndResolver(address _ens, address _resolver) external onlyOwner {
        ens = ENS(_ens);
        resolver = IKycResolver(_resolver);
    }

    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
    }

    function setMinNameLength(uint256 newLength) external onlyOwner {
        minNameLength = newLength;
    }

    function addAdmin(address newAdmin) external onlyOwner {
        require(!isAdmin[newAdmin], "Already admin");
        isAdmin[newAdmin] = true;
        adminCount++;
    }

    function removeAdmin(address admin) external onlyOwner {
        require(isAdmin[admin], "Not admin");
        require(adminCount > 1, "Cannot remove last admin");
        isAdmin[admin] = false;
        adminCount--;
    }

    function emergencyPause() external onlyAdmin {
        paused = true;
    }

    function emergencyUnpause() external onlyOwner {
        paused = false;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

    function _hasSuffix(string memory str, string memory suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(suffix);
        
        if (strBytes.length < suffixBytes.length) {
            return false;
        }
        
        for (uint i = 0; i < suffixBytes.length; i++) {
            if (strBytes[strBytes.length - suffixBytes.length + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }
} 