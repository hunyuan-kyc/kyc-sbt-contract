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
        require(!paused, "KycSBT: Contract is paused");
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
        minNameLength = 5;
        validityPeriod = 365 days;  // Default validity period
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
     * @dev Approves an ENS name for a specific address
     * @param user Address to approve the name for
     * @param ensName The ENS name to approve
     */
    function approveEnsName(address user, string calldata ensName) external onlyOwner {
        require(bytes(ensName).length > 0, "KycSBT: Empty name");
        require(user != address(0), "KycSBT: Zero address");
        require(ensNameToAddress[ensName] == address(0), "KycSBT: Name already registered");
        
        approvedEnsNames[user] = ensName;
        isNameApproved[ensName] = true;
        emit EnsNameApproved(user, ensName);
    }

    /**
     * @dev Checks if an ENS name is approved for a specific address
     * @param user Address to check
     * @param ensName The ENS name to check
     * @return bool Whether the name is approved for the address
     */
    function isEnsNameApproved(address user, string calldata ensName) external view returns (bool) {
        return keccak256(bytes(approvedEnsNames[user])) == keccak256(bytes(ensName));
    }

    /**
     * @dev Approves or updates KYC level for a user
     * @param user Address to approve
     * @param level KYC level (1-4)
     */
    function approveKyc(address user, uint8 level) external onlyOwner {
        require(user != address(0), "KycSBT: Zero address");
        require(level >= 1 && level <= 4, "KycSBT: Invalid level");
        
        KycInfo storage info = kycInfos[user];
        
        if (bytes(info.ensName).length == 0) {
            // New user - store approval for future requestKyc
            pendingApprovals[user] = level;
            emit KycApprovalPending(user, level);
            return;
        }

        // Update existing user's level
        info.level = KycLevel(level);
        if (info.status != KycStatus.APPROVED) {
            info.status = KycStatus.APPROVED;
        }

        bytes32 node = keccak256(bytes(info.ensName));
        resolver.setKycStatus(
            node,
            true,
            level,
            block.timestamp + validityPeriod
        );

        emit KycStatusUpdated(user, KycStatus.APPROVED);
        emit AddressApproved(user, KycLevel(level));
    }

    /**
     * @dev Requests KYC verification with an ENS name
     * @param ensName The ENS name to be registered
     */
    function requestKyc(string calldata ensName) external payable override whenNotPaused {
        bytes memory nameBytes = bytes(ensName);
        bytes memory suffixBytes = bytes(suffix);
        
        // First check name requirements
        require(nameBytes.length >= suffixBytes.length, "KycSBT: Name too short"); 
        require(_hasSuffix(ensName, suffix), "KycSBT: Invalid suffix");
        
        // Then check if name is already registered
        require(ensNameToAddress[ensName] == address(0), "KycSBT: Name already registered");
        
        // Then check if user is approved
        require(pendingApprovals[msg.sender] > 0, "KycSBT: Not approved");
        
        uint256 labelLength = nameBytes.length - suffixBytes.length;
        
        // Check name length and approval status
        if (labelLength <= 4) {
            require(
                keccak256(bytes(approvedEnsNames[msg.sender])) == keccak256(bytes(ensName)),
                "KycSBT: Short name not approved for sender"
            );
            require(isNameApproved[ensName], "KycSBT: Short name not approved");
        }
        
        uint256 totalFee = registrationFee + ensFee;
        require(msg.value >= totalFee, "KycSBT: Insufficient fee");
        
        // Process refund if excess fee was sent
        if (msg.value > totalFee) {
            uint256 refundAmount = msg.value - totalFee;
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            require(success, "KycSBT: Refund failed");
        }

        bytes32 node = keccak256(bytes(ensName));
        uint8 approvedLevel = pendingApprovals[msg.sender];
        
        KycInfo storage info = kycInfos[msg.sender];
        info.ensName = ensName;
        info.level = KycLevel(approvedLevel);
        info.status = KycStatus.APPROVED;
        info.createTime = block.timestamp;

        ensNameToAddress[ensName] = msg.sender;
        delete pendingApprovals[msg.sender];
        
        resolver.setAddr(node, msg.sender);
        resolver.setKycStatus(
            node,
            true,
            approvedLevel,
            block.timestamp + validityPeriod
        );

        _mint(msg.sender, uint256(uint160(msg.sender)));

        emit KycRequested(msg.sender, ensName);
        emit KycStatusUpdated(msg.sender, KycStatus.APPROVED);
        emit AddressApproved(msg.sender, KycLevel(approvedLevel));
    }

    /**
     * @dev Sets the registration fee
     * @param newFee New fee amount in wei
     */
    function setRegistrationFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "KycSBT: Fee cannot be zero");
        registrationFee = newFee;
        emit RegistrationFeeUpdated(newFee);
    }

    /**
     * @dev Sets the ENS fee
     * @param newFee New fee amount in wei
     */
    function setEnsFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "KycSBT: Fee cannot be zero");
        ensFee = newFee;
        emit EnsFeeUpdated(newFee);
    }

    /**
     * @dev Revokes KYC status from a user
     * @param user Address of the user to revoke
     */
    function revokeKyc(address user) external override {
        require(msg.sender == owner() || msg.sender == user, "KycSBT: Not authorized");
        KycInfo storage info = kycInfos[user];
        require(info.status == KycStatus.APPROVED, "KycSBT: Not approved");

        info.status = KycStatus.REVOKED;
        bytes32 node = keccak256(bytes(info.ensName));

        resolver.setKycStatus(
            node,
            false,
            uint8(info.level),
            0  // Set expiry to 0 when revoking
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
        bytes32 node = keccak256(bytes(info.ensName));
        
        if (info.status == KycStatus.APPROVED && resolver.isValid(node)) {
            return (true, uint8(info.level));
        }
        
        return (false, 0);
    }

    /**
     * @dev Gets KYC information for a user
     * @param account Address of the user to get KYC info for
     * @return ensName ENS name
     * @return level KYC level
     * @return status KYC status
     * @return createTime Creation timestamp
     */
    function getKycInfo(address account) external view override returns (
        string memory ensName,
        KycLevel level,
        KycStatus status,
        uint256 createTime
    ) {
        KycInfo memory info = kycInfos[account];
        return (
            info.ensName,
            info.level,
            info.status,
            info.createTime
        );
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
     * @dev Sets the minimum ENS name length
     * @param newLength New minimum length
     */
    function setMinNameLength(uint256 newLength) external onlyOwner {
        minNameLength = newLength;
    }

    /**
     * @dev Pauses all contract operations
     */
    function emergencyPause() external onlyOwner {
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

    /**
     * @dev Sets the validity period for KYC
     * @param newPeriod New validity period in seconds
     */
    function setValidityPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "KycSBT: Invalid period");
        validityPeriod = newPeriod;
        emit ValidityPeriodUpdated(newPeriod);
    }

    /**
     * @notice Get the total fee required for KYC registration
     * @return The total fee (registration fee + ENS fee) in wei
     */
    function getTotalFee() external view returns (uint256) {
        return registrationFee + ensFee;
    }
} 