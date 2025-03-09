// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelpConfig, CodeConstants} from "./Helpconfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "src/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelpConfig helpConfig = new HelpConfig();
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinatorV2;
        uint256 deployerKey = config.deployerKey;
        (uint256 subId,) = createSubscription(vrfCoordinator,deployerKey);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator,uint256 deployerKey) public returns (uint256, address) {
        console.log("Creating subscription on chainId", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription created with id", subscriptionId);
        console.log("Updating config with subscriptionId", subscriptionId);
        return (subscriptionId, vrfCoordinator);
    }

    function run() public returns(uint256,address) {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 link

    function fundSubscriptionUsingConfig() public {
        HelpConfig helpConfig = new HelpConfig();
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinatorV2;
        uint256 subId = config.subscriptionId;
        uint256 deployerKey = config.deployerKey;
        console.log("Funding subscription with id", subId);
        address link = config.link;

        if(subId == 0){
            CreateSubscription createsub = new CreateSubscription();
            (uint256 updatesubId,address updatevrfv2) = createsub.run();
            subId = updatesubId;
            vrfCoordinator = updatevrfv2;
        }
        fundSubscription(vrfCoordinator, subId, link,deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address link,uint256 deployerKey) public {
        console.log("Funding subscription on chainId", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT*100000);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address RecentlyDeployed) public {
        HelpConfig helpConfig = new HelpConfig();
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinatorV2;
        uint256 subId = config.subscriptionId;
        uint256 deployerKey = config.deployerKey;
        console.log("Adding consumer with subscription id", subId);
        addConsumer(RecentlyDeployed, vrfCoordinator, subId, deployerKey);
    }

    function addConsumer(address RecentlyDeployed, address vrfCoordinator, uint256 subId,uint256 deployerKey) public {
        console.log("Adding consumer on chainId", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, RecentlyDeployed);
        vm.stopBroadcast();
    }

    function run() external {
        address RecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(RecentlyDeployed);
    }
}
