// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";

// forge script script/Verify.s.sol --rpc-url $RPC_URL --broadcast -vvvv
contract VerifyScript is Script {
    function run() external view {
        // 从环境变量获取地址
        address kycSBTAddress = vm.envAddress("KYCSBT_ADDRESS");
        address ensAddress = vm.envAddress("ENS_ADDRESS");
        address resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        // 加载合约
        KycSBT kycSBT = KycSBT(kycSBTAddress);
        ENSRegistry ens = ENSRegistry(ensAddress);
        KycResolver resolver = KycResolver(resolverAddress);

        console.log("\n=== Verifying KycSBT Contract ===");
        
        // 1. 验证基本设置
        console.log("\nBasic Settings:");
        console.log("Registration Fee:", kycSBT.registrationFee());
        console.log("Min Name Length:", kycSBT.minNameLength());
        console.log("Default Suffix:", kycSBT.suffix());
        require(kycSBT.registrationFee() == 0.01 ether, "Invalid registration fee");
        require(kycSBT.minNameLength() == 5, "Invalid min name length");
        require(keccak256(bytes(kycSBT.suffix())) == keccak256(bytes(".hsk")), "Invalid suffix");

        // 2. 验证 ENS 设置
        console.log("\nENS Integration:");
        console.log("ENS Address:", address(kycSBT.ens()));
        console.log("Resolver Address:", address(kycSBT.resolver()));
        require(address(kycSBT.ens()) == ensAddress, "ENS address mismatch");
        require(address(kycSBT.resolver()) == resolverAddress, "Resolver address mismatch");

        // 3. 验证 ENS 域名设置
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        console.log("\nENS Domain Settings:");
        console.log("HSK Node:", vm.toString(hskNode));
        console.log("HSK Owner:", ens.owner(hskNode));
        require(ens.owner(hskNode) == address(kycSBT), "KycSBT not owner of .hsk");
        require(ens.resolver(hskNode) == address(resolver), "Resolver not set for .hsk");

        // 4. 验证管理员设置
        console.log("\nAdmin Settings:");
        console.log("Admin Count:", kycSBT.adminCount());
        console.log("Is Admin:", kycSBT.isAdmin(admin));
        require(kycSBT.isAdmin(admin), "Admin not set correctly");
        require(kycSBT.adminCount() > 0, "No admins set");

        // 5. 验证 Resolver 权限
        console.log("\nResolver Ownership:");
        console.log("Resolver Owner:", resolver.owner());
        require(resolver.owner() == address(kycSBT), "KycSBT not owner of resolver");

        // 6. 验证合约状态
        console.log("\nContract State:");
        console.log("Paused:", kycSBT.paused());
        require(!kycSBT.paused(), "Contract should not be paused initially");

        console.log("\n=== Verification Completed Successfully ===\n");
    }
} 