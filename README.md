# KYC SoulBound Token (SBT) with ENS Integration

这是一个基于 Foundry 开发的可升级智能合约，实现了带有 ENS 域名管理的 KYC SoulBound Token (SBT)。

## 主要功能

1. **KYC 等级系统**
   - NONE: 未认证
   - BASIC: 基础认证
   - ADVANCED: 高级认证
   - PREMIUM: 特权认证

2. **ENS 域名管理**
   - 最小域名长度：5个字符
   - 域名定价：基础价格 + 字符长度费用
   - 基础价格：0.01 ETH
   - 每字符费用：0.002 ETH

3. **SoulBound 特性**
   - Token 不可转让
   - 一年有效期
   - 可续期

4. **可升级合约**
   - 使用 UUPS 代理模式
   - 支持未来功能升级

## 合约功能

### 用户功能

1. `requestKyc(string memory ensName)`: 申请 KYC 并铸造 SBT
2. `extendValidity(uint256 tokenId)`: 延长 SBT 有效期
3. `getTokenDetails(uint256 tokenId)`: 获取 Token 详细信息

### 管理员功能

1. `updateKycLevel(uint256 tokenId, KycLevel newLevel)`: 更新用户 KYC 等级

## 定价规则

- 基础价格：0.01 ETH
- 每个字符额外收费：0.002 ETH
- 示例：
  - 5字符域名：0.01 + (5 * 0.002) = 0.02 ETH
  - 10字符域名：0.01 + (10 * 0.002) = 0.03 ETH

## 开发环境

- Solidity: ^0.8.19
- Foundry
- OpenZeppelin Contracts Upgradeable

## 测试

运行测试：
```bash
forge test
```

## 部署

1. 部署实现合约
2. 部署代理合约
3. 初始化合约

## 安全特性

- 不可转让的 SoulBound Token
- 基于时间的有效期控制
- 只有管理员可以更新 KYC 等级
- 可升级架构用于修复潜在问题 


forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit