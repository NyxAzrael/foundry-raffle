// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "src/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelpConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 ticketPrice;
        uint256 interval;
        uint256 subscriptionId;
        bytes32 gasLane; // keyHash
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 ChainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[CodeConstants.ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
    function setConfig(uint256 chainid,NetworkConfig memory config) public {
        networkConfigs[chainid] = config;
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ticketPrice: 0.01 ether, // 1e16
            interval: 30, // 30 seconds
            vrfCoordinatorV2: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,  // 500,000 gas
            subscriptionId:21399117852884758846534989372150044447850175237192674390347950531229940766673 ,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey:vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (networkConfigs[LOCAL_CHAIN_ID].vrfCoordinatorV2 != address(0)) {
            return localNetworkConfig;
        }
        // if not, create one

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            ticketPrice: 0.01 ether,
            interval: 30, // 30 seconds
            vrfCoordinatorV2: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(link),
            deployerKey:0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });

        return localNetworkConfig;
    }
}
