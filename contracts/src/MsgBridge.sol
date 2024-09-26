// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IWormhole} from "@wormhole/ethereum/contracts/interfaces/IWormhole.sol";

contract MsgBridge {
    /**
     * Address of the Wormhole contract on this chain.
     */
    address wormhole;

    /** 
     * Wormhole chain ID of this contract.
     */
    uint16 chainId;

    /**
     * The number of block confirmations needed before the Wormhole network
     * will attest a message.
     */
    uint8 wormholeFinality;

    /**
     * Wormhole chain ID to known emitter address mapping. xDapps using
     * Wormhole should register all deployed contracts on each chain to
     * verify that messages being consumed are from trusted contracts.
     */
    mapping(uint16 => bytes32) registeredEmitters;

    // Verified message hash to received message mapping.
    mapping(bytes32 => string) receivedMessages;

    // Verified message hash to received message mapping.
    mapping(bytes32 => bool) consumedMessages;

    // State vars.
    struct Msg {
        string msg;
        uint32 id;
        uint16 emitterChainId;
        uint16 destinationChainId;
        address sender;
    }
    Msg public lastMessageReceived;
    uint32 id;

    constructor(
        address wormhole_,
        uint16 chainId_,
        uint8 wormholeFinality_
    ) {
        wormhole = wormhole_;
        chainId = chainId_;
        wormholeFinality = wormholeFinality_;
    }

    function getMsgFee() public view returns (uint256) {
        return IWormhole(wormhole).messageFee();
    }

    function sendMessage(
        string memory message, 
        uint16 recipientChain
    ) public payable returns (uint64 messageSequence) {
        // Cache Wormhole instance and fees to save on gas.
        IWormhole wormholeCore = IWormhole(wormhole);
        uint256 wormholeFee = getMsgFee();

        // Confirm that the caller has sent enough value to pay for the Wormhole message fee.
        require(msg.value == wormholeFee, "Insufficient value");

        // Create the Msg struct.
        Msg memory parsedMessage = Msg({
            id: ++id,
            msg: message,
            emitterChainId: chainId,
            sender: msg.sender,
            destinationChainId: recipientChain
        });

        // Encode the Msg struct.
        bytes memory encodedMessage = abi.encode(parsedMessage);

        // Send the message by calling publishMessage on the Wormhole core contract.
        messageSequence = wormholeCore.publishMessage{value: wormholeFee}(
            0, // batchID
            encodedMessage,
            wormholeFinality
        );
    }

    function receiveMessage(bytes memory encodedMessage) public {
        IWormhole wormholeCore = IWormhole(wormhole);
        // call the Wormhole core contract to parse and verify the encodedMessage
        (
            IWormhole.VM memory wormholeMessage,
            bool valid,
            string memory reason
        ) = wormholeCore.parseAndVerifyVM(encodedMessage);

        // confirm that the Wormhole core contract verified the message
        require(valid, reason);

        // verify that this message was emitted by a registered emitter
        require(_verifyEmitter(wormholeMessage), "unknown emitter");

        // Decode the message.
        Msg memory parsedMessage = decodeMessage(wormholeMessage.payload);

        // Consume the msg
        require(!consumedMessages[wormholeMessage.hash], "Msg already consumed");
        receivedMessages[wormholeMessage.hash] = parsedMessage.msg;
        consumedMessages[wormholeMessage.hash] = true;
        lastMessageReceived = parsedMessage;
    }

    // Separate decoding function
    function decodeMessage(bytes memory encodedMessage) public pure returns (Msg memory) {
        return abi.decode(encodedMessage, (Msg));
    }

    function _verifyEmitter(
        IWormhole.VM memory vm
    ) internal view returns (bool) {
        // Verify that the sender of the Wormhole message is a trusted contract.
        return registeredEmitters[vm.emitterChainId] == vm.emitterAddress;
    }
}
