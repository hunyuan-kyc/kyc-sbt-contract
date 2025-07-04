// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KycSBT} from "../src/KycSBT.sol"; // Import your implementation contract

// Define an interface for the UUPSUpgradeable functions
interface IUUPSUpgradeable {
    function upgradeTo(address newImplementation) external;
    // Add other UUPS-related functions if needed, like upgradeToAndCall
}

// This script is for upgrading an existing KycSBT proxy to a new implementation.
// Assumes the KycSBT contract is a UUPS upgradeable contract (inherits UUPSUpgradeable).
contract UpgradeKycSBT is Script {
    // Replace with the address of your deployed KycSBT proxy contract
    address public constant PROXY_ADDRESS = 0x0000000000000000000000000000000000000001;

    function run() external returns (address newImplementation) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying new KycSBT implementation...");
        // Deploy the new implementation contract
        // Ensure this is the *new* version of your KycSBT contract with updated logic
        KycSBT newKycSBTImplementation = new KycSBT();
        newImplementation = address(newKycSBTImplementation);
        console.log("New KycSBT implementation deployed at:", newImplementation);

        console.log("Upgrading KycSBT proxy at:", PROXY_ADDRESS);

        // To upgrade a UUPS proxy, you call the upgradeTo function on the proxy address.
        // The proxy's fallback function will delegate this call to the current implementation,
        // which then executes the upgrade logic (assuming it inherits UUPSUpgradeable).
        // The caller (deployer) must be the admin/owner of the proxy.
        IUUPSUpgradeable(payable(PROXY_ADDRESS)).upgradeTo(newImplementation);

        console.log("KycSBT proxy upgraded successfully!");

        vm.stopBroadcast();
    }
}