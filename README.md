# ENS-based KYC Soulbound Token

A decentralized KYC (Know Your Customer) system based on ENS (Ethereum Name Service) using Soulbound Token.

## Overview

This project implements a KYC system where:
- Users can request KYC verification using their ENS names (.hsk)
- Admins can approve/revoke KYC status
- KYC status is bound to ENS names and cannot be transferred (Soulbound)
- Multiple KYC levels supported (BASIC, ADVANCED, PREMIUM)

## Features

- **ENS Integration**
  - Custom .hsk TLD (Top Level Domain)
  - ENS name ownership verification
  - ENS resolver for KYC status

- **KYC Management**
  - Request KYC with ENS name
  - Approve/Revoke KYC status
  - Multiple KYC levels
  - KYC status expiration

- **Admin Features**
  - Multi-admin support
  - Emergency pause/unpause
  - Fee management
  - Whitelist management

- **Security**
  - Soulbound (non-transferable)
  - Role-based access control
  - Pausable in emergency
  - Upgradeable design

## Contract Structure

```solidity
src/
├── KycSBT.sol              // Main contract
├── KycSBTStorage.sol       // Storage layout
├── KycResolver.sol         // ENS resolver
└── interfaces/
    ├── IKycSBT.sol        // Main interface
    └── IKycResolver.sol    // Resolver interface
```

## Core Functions

### User Functions
```solidity
// Request KYC verification
function requestKyc(string calldata ensName) external payable;

// Check if an address is KYC verified
function isHuman(address account) external view returns (bool, uint8);
```

### Admin Functions
```solidity
// Approve KYC request
function approve(address user, KycLevel level) external;

// Revoke KYC status
function revokeKyc(address user) external;

// Emergency controls
function emergencyPause() external;
function emergencyUnpause() external;
```

## Integration Guide

### Backend Integration Example (Node.js + ethers.js v6)

```typescript
import { 
    ethers, 
    Contract, 
    JsonRpcProvider, 
    Wallet, 
    ContractEventPayload,
    TransactionResponse,
    TransactionReceipt 
} from 'ethers';

// KYC 状态类型
interface KycStatus {
    isValid: boolean;
    level: number;
}

// 事件监听器类型
type EventCallback = (args: ContractEventPayload) => void;

class KycService {
    private provider: JsonRpcProvider;
    private wallet: Wallet;
    private kycSBT: Contract;
    private eventListeners: Map<string, EventCallback>;

    constructor(
        rpcUrl: string, 
        contractAddress: string, 
        privateKey: string, 
        abi: any[]
    ) {
        this.provider = new JsonRpcProvider(rpcUrl);
        this.wallet = new Wallet(privateKey, this.provider);
        this.kycSBT = new Contract(contractAddress, abi, this.wallet);
        this.eventListeners = new Map();
    }

    /**
     * 用户请求 KYC
     * @param ensName ENS 名称 (例如: "alice1.hsk")
     * @returns 交易回执
     */
    async requestKyc(ensName: string): Promise<TransactionReceipt> {
        try {
            const fee = await this.kycSBT.registrationFee();
            const tx = await this.kycSBT.requestKyc(ensName, { value: fee });
            return await tx.wait();
        } catch (error) {
            console.error('Request KYC failed:', error);
            throw error;
        }
    }

    // ... 其他方法 ...
}

// 使用示例
async function demo() {
    const config = {
        rpcUrl: "https://ethereum-goerli.publicnode.com",
        contractAddress: "YOUR_CONTRACT_ADDRESS",
        privateKey: "YOUR_PRIVATE_KEY",
        abi: [] // 你的合约 ABI
    };

    try {
        const kycService = new KycService(
            config.rpcUrl,
            config.contractAddress,
            config.privateKey,
            config.abi
        );

        // 1. 请求 KYC
        const requestTx = await kycService.requestKyc("alice1.hsk");
        console.log("KYC Request TX:", requestTx.hash);

        // 2. 查询状态
        const status = await kycService.checkKycStatus("USER_ADDRESS");
        console.log("KYC Status:", status);
    } catch (error) {
        console.error("Demo failed:", error);
    }
}
```

## Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/KycSBTCore.t.sol

# Run with detailed logs
forge test -vvv
```

## Deployment

```bash
# Deploy to local network
forge script script/Deploy.s.sol --rpc-url localhost

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url goerli --broadcast --verify
```

## Security Considerations

1. ENS Name Validation
   - Minimum length requirements
   - Suffix (.hsk) validation
   - Ownership verification

2. Access Control
   - Owner privileges
   - Admin management
   - Emergency controls

3. Fee Management
   - Registration fee
   - Fee withdrawal
   - Balance checks

## License

MIT
