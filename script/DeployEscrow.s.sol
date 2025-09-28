// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Escrow} from "../src/escrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrow is Script {
    function run() external {
        // Get the payment token address from environment variable
        address paymentToken = vm.envAddress("PAYMENT_TOKEN");
        
        vm.startBroadcast();
        
        // Deploy the escrow contract
        Escrow escrow = new Escrow(paymentToken);
        
        vm.stopBroadcast();
        
        // Log the deployed contract address
        console.log("Escrow deployed at:", address(escrow));
        console.log("Payment token:", paymentToken);
    }
}
