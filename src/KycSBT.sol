// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@ens-contracts/contracts/registry/ENS.sol";
import "./KycSBTStorage.sol";
import "./interfaces/IKycSBT.sol";
import "./interfaces/IKycResolver.sol";

/**
 * @title KYC Soulbound Token
 * @notice Implements KYC verification using ENS and Soulbound tokens
 * @dev Non-transferable tokens representing KYC status, integrated with ENS
 */
contract KycSBT is ERC721Upgradeable, OwnableUpgradeable, KycSBTStorage, IKycSBT {
    
    /**
     * @dev Ensures the contract is not paused
     */
    modifier whenNotPaused() {
        require(!paused, "KycSBT.whenNotPaused: Contract is paused");
        _;
    }

    /**
     * @dev Restricts function to admin or owner
     */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || owner() == msg.sender, "KycSBT.onlyAdmin: Not admin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    /**
     * @dev Initializes the contract with default settings
     */
    function initialize() public initializer {
        __ERC721_init("KYC SBT", "KYC");
        __Ownable_init(msg.sender);
        registrationFee = 0.01 ether;
        minNameLength = 5;
    }

    /**
     * @dev Sets the suffix for ENS names
     * @param newSuffix New suffix to be used (e.g., ".hsk")
     */
    function setSuffix(string calldata newSuffix) external onlyOwner {
        require(bytes(newSuffix).length > 0, "KycSBT.setSuffix: Invalid suffix");
        require(bytes(newSuffix)[0] == bytes1("."), "KycSBT.setSuffix: Suffix must start with dot");
        suffix = newSuffix;
    }

    /**
     * @dev Requests KYC verification with an ENS name
     * @param ensName The ENS name to be registered
     */
    function requestKyc(string calldata ensName) external payable override whenNotPaused {
        bytes memory nameBytes = bytes(ensName);
        bytes memory suffixBytes = bytes(suffix);
        require(nameBytes.length >= suffixBytes.length, "KycSBT.requestKyc: Name too short"); 
        require(_hasSuffix(ensName, suffix), "KycSBT.requestKyc: Invalid suffix");
        
        uint256 labelLength = nameBytes.length - suffixBytes.length;
        require(labelLength >= minNameLength, "KycSBT.requestKyc: Name too short");
        require(msg.value >= registrationFee, "KycSBT.requestKyc: Insufficient fee");
        require(ensNameToAddress[ensName] == address(0), "KycSBT.requestKyc: Name already registered");
        require(kycInfos[msg.sender].status == KycStatus.NONE, "KycSBT.requestKyc: KYC already exists");

        bytes32 node = keccak256(bytes(ensName));
        
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

    /**
     * @dev Approves a KYC request for a user
     * @param user Address of the user to approve
     * @param level KYC level to assign
     */
    function approve(
        address user, 
        KycLevel level
    ) external onlyOwner whenNotPaused {
        require(user != address(0), "KycSBT.approve: Invalid address");
        
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.PENDING, "KycSBT.approve: Invalid status");
        require(!info.isWhitelisted, "KycSBT.approve: Already approved");

        info.status = KycStatus.APPROVED;
        info.level = level;
        info.isWhitelisted = true;

        // Update ENS resolver
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

    /**
     * @dev Revokes KYC status from a user
     * @param user Address of the user to revoke
     */
    function revokeKyc(address user) external override onlyOwner {
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.APPROVED, "KycSBT.revokeKyc: Not approved");

        // Update status while keeping ENS information
        info.status = KycStatus.REVOKED;
        info.isWhitelisted = false;

        // Update ENS resolver status
        resolver.setKycStatus(
            info.ensNode,
            false,
            uint8(info.level),
            0
        );

        emit KycStatusUpdated(user, KycStatus.REVOKED);
        emit KycRevoked(user);
    }

    /**
     * @dev Checks if an address has valid KYC status
     * @param account Address to check
     * @return bool Whether the address is verified
     * @return uint8 KYC level of the address
     */
    function isHuman(address account) external view override returns (bool, uint8) {
        KycInfo memory info = kycInfos[account];
        
        if (info.status == KycStatus.APPROVED &&
            block.timestamp <= info.expirationTime &&
            resolver.isValid(info.ensNode)) {
            return (true, uint8(info.level));
        }
        
        return (false, 0);
    }

    // Admin Functions

    /**
     * @dev Sets the ENS registry and resolver addresses
     * @param _ens Address of the ENS registry
     * @param _resolver Address of the KYC resolver
     */
    function setENSAndResolver(address _ens, address _resolver) external onlyOwner {
        ens = ENS(_ens);
        resolver = IKycResolver(_resolver);
    }

    /**
     * @dev Sets the registration fee
     * @param newFee New fee amount in wei
     */
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        registrationFee = newFee;
    }

    /**
     * @dev Sets the minimum ENS name length
     * @param newLength New minimum length
     */
    function setMinNameLength(uint256 newLength) external onlyOwner {
        minNameLength = newLength;
    }

    /**
     * @dev Adds a new admin
     * @param newAdmin Address of the new admin
     */
    function addAdmin(address newAdmin) external onlyOwner {
        require(!isAdmin[newAdmin], "KycSBT.addAdmin: Already admin");
        isAdmin[newAdmin] = true;
        adminCount++;
    }

    /**
     * @dev Removes an admin
     * @param admin Address of the admin to remove
     */
    function removeAdmin(address admin) external onlyOwner {
        require(isAdmin[admin], "KycSBT.removeAdmin: Not admin");
        require(adminCount > 1, "KycSBT.removeAdmin: Cannot remove last admin");
        isAdmin[admin] = false;
        adminCount--;
    }

    /**
     * @dev Pauses all contract operations
     */
    function emergencyPause() external onlyAdmin {
        paused = true;
    }

    /**
     * @dev Unpauses contract operations
     */
    function emergencyUnpause() external onlyOwner {
        paused = false;
    }

    /**
     * @dev Withdraws collected fees to owner
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "KycSBT.withdrawFees: No fees to withdraw");
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "KycSBT.withdrawFees: Transfer failed");
    }

    /**
     * @dev Internal function to check if a string ends with a suffix
     * @param str String to check
     * @param _suffix Suffix to check for
     * @return bool Whether the string ends with the suffix
     */
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