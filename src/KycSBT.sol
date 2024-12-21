// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "./KycSBTStorage.sol";
import "./interfaces/IKycSBT.sol";
import "./interfaces/IKycResolver.sol";

contract KycSBT is ERC721Upgradeable, OwnableUpgradeable, KycSBTStorage, IKycSBT {

    
    modifier whenNotPaused() {
        require(!paused, "KycSBT.whenNotPaused: Contract is paused");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || owner() == msg.sender, "KycSBT.onlyAdmin: Not admin");
        _;
    }


    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    function initialize() public initializer {
        __ERC721_init("KYC SBT", "KYC");
        __Ownable_init(msg.sender);
        registrationFee = 0.01 ether;
        minNameLength = 5;
    }

    // 添加设置后缀的函数
    function setSuffix(string calldata newSuffix) external onlyOwner {
        require(bytes(newSuffix).length > 0, "KycSBT.setSuffix: Invalid suffix");
        require(bytes(newSuffix)[0] == bytes1("."), "KycSBT.setSuffix: Suffix must start with dot");
        suffix = newSuffix;
    }

    function requestKyc(string calldata ensName) external payable override whenNotPaused {
        // 验证名称长度（不包括后缀）
        bytes memory nameBytes = bytes(ensName);
        bytes memory suffixBytes = bytes(suffix);
        require(nameBytes.length >= suffixBytes.length, "KycSBT.requestKyc: Name too short"); 
        
        // 检查后缀
        require(_hasSuffix(ensName, suffix), "KycSBT.requestKyc: Invalid suffix");
        
        // 计算不包括后缀的长度
        uint256 labelLength = nameBytes.length - suffixBytes.length;
        require(labelLength >= minNameLength, "KycSBT.requestKyc: Name too short");

        require(msg.value >= registrationFee, "KycSBT.requestKyc: Insufficient fee");
        require(ensNameToAddress[ensName] == address(0), "KycSBT.requestKyc: Name already registered");
        require(kycInfos[msg.sender].status == KycStatus.NONE, "KycSBT.requestKyc: KYC already exists");

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
        require(user != address(0), "KycSBT.approve: Invalid address");
        
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.PENDING, "KycSBT.approve: Invalid status");
        require(!info.isWhitelisted, "KycSBT.approve: Already approved");

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
        require(info.status == KycStatus.APPROVED, "KycSBT.revokeKyc: Not approved");

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
        require(!isAdmin[newAdmin], "KycSBT.addAdmin: Already admin");
        isAdmin[newAdmin] = true;
        adminCount++;
    }

    function removeAdmin(address admin) external onlyOwner {
        require(isAdmin[admin], "KycSBT.removeAdmin: Not admin");
        require(adminCount > 1, "KycSBT.removeAdmin: Cannot remove last admin");
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
        require(balance > 0, "KycSBT.withdrawFees: No fees to withdraw");
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "KycSBT.withdrawFees: Transfer failed");
    }

    function _hasSuffix(string memory str, string memory _suffix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory suffixBytes = bytes(_suffix);
        
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