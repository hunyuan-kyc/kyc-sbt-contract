// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";

/**
 * @title KYC SBT Verification Script
 * @notice Verifies the deployment and configuration of KYC SBT system
 * @dev Run with: forge script script/Verify.s.sol --rpc-url $RPC_URL --broadcast -vvvv
 */
contract VerifyScript is Script {
    function run() external view {
        // Load contract addresses from environment
        address kycSBTAddress = vm.envAddress("KYCSBT_ADDRESS");
        address ensAddress = vm.envAddress("ENS_ADDRESS");
        address resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        // Load contract instances
        KycSBT kycSBT = KycSBT(kycSBTAddress);
        ENSRegistry ens = ENSRegistry(ensAddress);
        KycResolver resolver = KycResolver(resolverAddress);

        console.log("\n=== Verifying KycSBT Contract ===");
        
        // Step 1: Verify basic settings
        console.log("\nBasic Settings:");
        console.log("Registration Fee:", kycSBT.registrationFee());
        console.log("Min Name Length:", kycSBT.minNameLength());
        console.log("Default Suffix:", kycSBT.suffix());
        require(kycSBT.registrationFee() == 0.01 ether, "Invalid registration fee");
        require(kycSBT.minNameLength() == 5, "Invalid min name length");
        require(keccak256(bytes(kycSBT.suffix())) == keccak256(bytes(".hsk")), "Invalid suffix");

        // Step 2: Verify ENS integration
        console.log("\nENS Integration:");
        console.log("ENS Address:", address(kycSBT.ens()));
        console.log("Resolver Address:", address(kycSBT.resolver()));
        require(address(kycSBT.ens()) == ensAddress, "ENS address mismatch");
        require(address(kycSBT.resolver()) == resolverAddress, "Resolver address mismatch");

        // Step 3: Verify ENS domain settings
        bytes32 hskNode = keccak256(abi.encodePacked(bytes32(0), keccak256("hsk")));
        console.log("\nENS Domain Settings:");
        console.log("HSK Node:", vm.toString(hskNode));
        console.log("HSK Owner:", ens.owner(hskNode));
        require(ens.owner(hskNode) == address(kycSBT), "KycSBT not owner of .hsk");
        require(ens.resolver(hskNode) == address(resolver), "Resolver not set for .hsk");

        // Step 4: Verify admin settings
        console.log("\nAdmin Settings:");
        console.log("Admin Count:", kycSBT.adminCount());
        console.log("Is Admin:", kycSBT.isAdmin(admin));
        require(kycSBT.isAdmin(admin), "Admin not set correctly");
        require(kycSBT.adminCount() > 0, "No admins set");

        // Step 5: Verify resolver ownership
        console.log("\nResolver Ownership:");
        console.log("Resolver Owner:", resolver.owner());
        require(resolver.owner() == address(kycSBT), "KycSBT not owner of resolver");

        // Step 6: Verify contract state
        console.log("\nContract State:");
        console.log("Paused:", kycSBT.paused());
        require(!kycSBT.paused(), "Contract should not be paused initially");

        console.log("\n=== Verification Completed Successfully ===\n");
    }
} 