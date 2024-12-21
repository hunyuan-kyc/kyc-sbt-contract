// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";

// forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast -vvvv
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 ENS Registry
        ENSRegistry ensRegistry = new ENSRegistry();
        console.log("ENS Registry deployed at:", address(ensRegistry));
        
        // 2. 部署 Resolver
        KycResolver resolver = new KycResolver(ENS(address(ensRegistry)));
        console.log("KYC Resolver deployed at:", address(resolver));
        
        // 3. 部署并初始化 KycSBT
        KycSBT kycSBT = new KycSBT();
        kycSBT.initialize();
        console.log("KYC SBT deployed at:", address(kycSBT));
        
        // 4. 设置 ENS 和解析器
        kycSBT.setENSAndResolver(address(ensRegistry), address(resolver));
        
        // 5. 设置 .hsk 域名
        bytes32 rootNode = bytes32(0);
        bytes32 labelHash = keccak256("hsk");
        bytes32 hskNode = keccak256(abi.encodePacked(rootNode, labelHash));
        
        // 先将 .hsk 域名所有权给到部署者
        ensRegistry.setSubnodeOwner(rootNode, labelHash, deployer);
        console.log("HSK node created and owned by deployer:", vm.toString(hskNode));
        
        // 确认部署者是所有者后设置解析器
        require(ensRegistry.owner(hskNode) == deployer, "Deployer not owner of HSK node");
        ensRegistry.setResolver(hskNode, address(resolver));
        console.log("Resolver set for HSK node");
        
        // 将所有权转移给 KycSBT 合约
        ensRegistry.setSubnodeOwner(rootNode, labelHash, address(kycSBT));
        console.log("HSK node ownership transferred to KycSBT");
        
        // 6. 添加管理员
        kycSBT.addAdmin(admin);
        console.log("Admin added:", admin);
        
        // 7. 授权 KycSBT 合约可以操作 resolver
        resolver.transferOwnership(address(kycSBT));
        console.log("Resolver ownership transferred to KycSBT");

        vm.stopBroadcast();

        console.log("\nDeployment Summary:");
        console.log("==================");
        console.log("Deployer:", deployer);
        console.log("ENS Registry:", address(ensRegistry));
        console.log("KYC Resolver:", address(resolver));
        console.log("KYC SBT:", address(kycSBT));
        console.log("HSK Node:", vm.toString(hskNode));
        console.log("Admin:", admin);
    }
} 