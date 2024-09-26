// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MsgBridge} from "../src/MsgBridge.sol"; // Adjust the import path as necessary

contract DeployMsgBridge is Script {
    struct ChainConfig {
        uint16 chainId;
        address wormholeCoreAddress;
        uint8 finality;
    }

    ChainConfig baseChain = ChainConfig({
        chainId: 10004, // Base sepolia
        wormholeCoreAddress: 0x79A1027a6A159502049F10906D333EC57E95F083, // Replace with actual address
        finality: 2
    });

    ChainConfig arbitrumChain = ChainConfig({
        chainId: 10003, // Arbitrum sepolia
        wormholeCoreAddress: 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35, // Replace with actual address
        finality: 2
    });

    // Choose which chain to deploy on. Update this variable before deployment!
    // TODO: Set this variable to the desired chain configuration before deploying.
    ChainConfig selectedChain = baseChain; // Change to arbitrumChain to deploy on Arbitrum

    function run() external {
        vm.startBroadcast();

        // Deploy the MsgBridge contract using the selected chain configuration
        MsgBridge msgBridge = new MsgBridge(
            selectedChain.wormholeCoreAddress,
            selectedChain.chainId,
            selectedChain.finality
        );

        // Optionally, you can log the deployed contract address
        console.log("MsgBridge deployed at:", address(msgBridge));

        vm.stopBroadcast();
    }
}
