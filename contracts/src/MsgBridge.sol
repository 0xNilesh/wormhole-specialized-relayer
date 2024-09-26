// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import the Wormhole interface for message passing
import {IWormhole} from "@wormhole/ethereum/contracts/interfaces/IWormhole.sol";

contract MsgBridge {
    // Address of the contract owner
    address public owner;

    // Address of the Wormhole contract on this chain
    address public wormhole;

    // Wormhole chain ID of this contract
    uint16 public chainId;

    // The number of block confirmations needed before the Wormhole network
    // will attest a message
    uint8 public wormholeFinality;

    // Mapping from Wormhole chain ID to known emitter address
    mapping(uint16 => bytes32) public registeredEmitters;

    // Verified message hash to received message mapping
    mapping(bytes32 => string) public receivedMessages;

    // Verified message hash to consumed status mapping
    mapping(bytes32 => bool) public consumedMessages;

    // Structure for message details
    struct Msg {
        string msg;              // Message content
        uint32 id;               // Unique identifier for the message
        uint16 emitterChainId;   // Chain ID of the message emitter
        uint16 destinationChainId; // Chain ID of the message destination
        address sender;          // Address of the message sender
    }

    // State variable for the last message received
    Msg public lastMessageReceived;

    // Unique identifier for messages
    uint32 public id;

    // OnlyOwner modifier to restrict access to certain functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Constructor to initialize contract variables
    constructor(
        address wormhole_,
        uint16 chainId_,
        uint8 wormholeFinality_
    ) {
        owner = msg.sender;      // Set the contract deployer as the owner
        wormhole = wormhole_;
        chainId = chainId_;
        wormholeFinality = wormholeFinality_;
    }

    // Function to get the message fee required by Wormhole
    function getMsgFee() public view returns (uint256) {
        return IWormhole(wormhole).messageFee();
    }

    // Function to send a message to a specified recipient chain
    function sendMessage(
        string memory message, 
        uint16 recipientChain
    ) public payable returns (uint64 messageSequence) {
        // Cache the Wormhole instance and fees to save on gas
        IWormhole wormholeCore = IWormhole(wormhole);
        uint256 wormholeFee = getMsgFee();

        // Ensure that the caller has sent enough value to cover the Wormhole message fee
        require(msg.value == wormholeFee, "Insufficient value");

        // Create the Msg struct
        Msg memory parsedMessage = Msg({
            id: ++id,
            msg: message,
            emitterChainId: chainId,
            sender: msg.sender,
            destinationChainId: recipientChain
        });

        // Encode the Msg struct for sending
        bytes memory encodedMessage = abi.encode(parsedMessage);

        // Publish the message using the Wormhole core contract
        messageSequence = wormholeCore.publishMessage{value: wormholeFee}(
            0, // batchID 
            encodedMessage,
            wormholeFinality
        );
    }

    // Function to receive and process a message
    function receiveMessage(bytes memory encodedMessage) public {
        IWormhole wormholeCore = IWormhole(wormhole);
        
        // Parse and verify the encoded message using Wormhole
        (
            IWormhole.VM memory wormholeMessage,
            bool valid,
            string memory reason
        ) = wormholeCore.parseAndVerifyVM(encodedMessage);

        // Ensure the Wormhole core contract verified the message
        require(valid, reason);

        // Verify that the message was emitted by a registered emitter
        require(_verifyEmitter(wormholeMessage), "unknown emitter");

        // Decode the message
        Msg memory parsedMessage = decodeMessage(wormholeMessage.payload);

        // Consume the message and prevent double processing
        require(!consumedMessages[wormholeMessage.hash], "Msg already consumed");
        receivedMessages[wormholeMessage.hash] = parsedMessage.msg;
        consumedMessages[wormholeMessage.hash] = true;
        lastMessageReceived = parsedMessage;
    }

    // Function to decode a message from bytes to Msg struct
    function decodeMessage(bytes memory encodedMessage) public pure returns (Msg memory) {
        return abi.decode(encodedMessage, (Msg));
    }

    // Internal function to verify the message emitter
    function _verifyEmitter(
        IWormhole.VM memory vm
    ) internal view returns (bool) {
        // Check if the sender of the Wormhole message is a trusted contract
        return registeredEmitters[vm.emitterChainId] == vm.emitterAddress;
    }

    /**
     * Register a new emitter for a specific chain.
     * @param emitterChainId The chain ID of the emitter.
     * @param emitterAddress The address of the emitter contract.
     */
    function registerEmitter(uint16 emitterChainId, address emitterAddress) external onlyOwner {
        // Convert the address to bytes32 by left-padding with zeros
        bytes32 paddedAddress = bytes32(uint256(uint160(emitterAddress)));

        // Store the left-padded address in the mapping
        registeredEmitters[emitterChainId] = paddedAddress;
    }
}
