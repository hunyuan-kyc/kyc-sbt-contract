// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@ens-contracts/contracts/registry/ENSRegistry.sol";
import "../src/KycSBT.sol";
import "../src/KycResolver.sol";

/**
 * @title KYC SBT Deployment Script
 * @notice Handles the deployment and initialization of KYC SBT system
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast -vvvv
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy ENS Registry
        ENSRegistry ensRegistry = new ENSRegistry();
        console.log("ENS Registry deployed at:", address(ensRegistry));
        
        // Step 2: Deploy KYC Resolver
        KycResolver resolver = new KycResolver(ENS(address(ensRegistry)));
        console.log("KYC Resolver deployed at:", address(resolver));
        
        // Step 3: Deploy and initialize KYC SBT
        KycSBT kycSBT = new KycSBT();
        kycSBT.initialize();
        console.log("KYC SBT deployed at:", address(kycSBT));
        
        // Step 4: Configure ENS and Resolver
        kycSBT.setENSAndResolver(address(ensRegistry), address(resolver));
        
        // Step 5: Set up ENS domain
        bytes32 rootNode = bytes32(0);
        bytes32 labelHash = keccak256("hsk");
        bytes32 hskNode = keccak256(abi.encodePacked(rootNode, labelHash));
        
        // Assign .hsk ownership to deployer temporarily
        ensRegistry.setSubnodeOwner(rootNode, labelHash, deployer);
        console.log("HSK node created and owned by deployer:", vm.toString(hskNode));
        
        // Set resolver after ownership confirmation
        require(ensRegistry.owner(hskNode) == deployer, "Deployer not owner of HSK node");
        ensRegistry.setResolver(hskNode, address(resolver));
        console.log("Resolver set for HSK node");
        
        // Transfer .hsk ownership to KYC SBT contract
        ensRegistry.setSubnodeOwner(rootNode, labelHash, address(kycSBT));
        console.log("HSK node ownership transferred to KycSBT");
        
        // Step 6: Set up admin
        kycSBT.addAdmin(admin);
        console.log("Admin added:", admin);
        
        // Step 7: Transfer resolver ownership
        resolver.transferOwnership(address(kycSBT));
        console.log("Resolver ownership transferred to KycSBT");

        vm.stopBroadcast();

        // Create deployment config
        string memory json = vm.serializeAddress("config", "deployer", deployer);
        json = vm.serializeAddress("config", "ensRegistry", address(ensRegistry));
        json = vm.serializeAddress("config", "kycResolver", address(resolver));
        json = vm.serializeAddress("config", "kycSBT", address(kycSBT));
        json = vm.serializeAddress("config", "admin", admin);
        json = vm.serializeBytes32("config", "hskNode", hskNode);

        // Save to file
        string memory path = "output/config.json";
        vm.writeJson(json, path);
        console.log("\nDeployment config saved to:", path);
    }
} 