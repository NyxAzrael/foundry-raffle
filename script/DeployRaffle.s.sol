// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelpConfig} from "./Helpconfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Intercation.s.sol";

contract DeployRaffle is Script {
    function run() external {

        Deploy();
    }

    function Deploy() public returns (Raffle, HelpConfig) {
        HelpConfig helpConfig = new HelpConfig();
        AddConsumer addConsumer = new AddConsumer();
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2) = createSubscription.createSubscriptionUsingConfig();
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinatorV2, config.subscriptionId, config.link,config.deployerKey);
            
            helpConfig.setConfig(block.chainid,config);
        }

        vm.startBroadcast(config.deployerKey);
        Raffle raffle = new Raffle(
            config.ticketPrice,
            config.interval,
            config.subscriptionId,
            config.gasLane,
            config.callbackGasLimit,
            config.vrfCoordinatorV2
        );
        vm.stopBroadcast();

        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2, config.subscriptionId,config.deployerKey);

        return (raffle, helpConfig);
    }
}
