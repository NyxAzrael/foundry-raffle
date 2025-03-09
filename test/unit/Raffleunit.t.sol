//spdx-license-identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelpConfig} from "../../script/Helpconfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {LinkToken} from "src/mocks/LinkToken.sol";
import {CodeConstants} from "../../script/Helpconfig.s.sol";

contract UnitTest is Test,CodeConstants {
    event enterPlayer(address indexed player);

    Raffle public raffle;
    HelpConfig public helpConfig;
    //config variables
    uint256 ticketPrice;
    uint256 interval;
    uint256 subscriptionId;
    bytes32 gasLane; // keyHash
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;
    LinkToken link;
    uint256 deployerKey;
    //play
    address public PLAYER = makeAddr("player");
    uint256 public constant BALANCE = 10 ether;


    function setUp() external {
        //deploy the contract
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helpConfig) = deployRaffle.Deploy();

        //get the config
        HelpConfig.NetworkConfig memory config = helpConfig.getConfig();
        ticketPrice = config.ticketPrice;
        interval = config.interval;
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2 = config.vrfCoordinatorV2;
        link = LinkToken(config.link);
        deployerKey = config.deployerKey;

        
    

        vm.deal(PLAYER, BALANCE);
    }
      modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp +interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    modifier skipFork() {
    if (block.chainid != 31337){
        return;
    }
    _;

}

    function testRaffleisOpen() public view {
        assert(raffle.getState() == Raffle.State.OPEN);
    }

    function testPlayerHasBalance() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.InvalidTicketPrice.selector);

        raffle.enterRaffle();
    }

    function testPlayerCanEnterRaffle() public {
        //arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, BALANCE);

        //act
        raffle.enterRaffle{value: ticketPrice}();
        //assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit enterPlayer(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__notOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testCheckUpKeepReturnsFalse() public {
        // Arrange

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");

        // Act / Assert
        assert(!upKeepNeeded);
    }

    function testKeepUpReturnsFalseIfRafflenotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testPerformUpKeepOnlyRunIfCheckUpIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertIfCheckUpIsFalse() public {
        // Arrange
        uint256 balance = 0;
        uint256 numplayers = 0;
        Raffle.State state = raffle.getState();

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_notupkeep.selector, balance, numplayers, uint256(state)));
        raffle.performUpkeep("");
    }

    function testRaffleStateAndEmitsRequestId() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        // Assert
        Raffle.State state = raffle.getState();
        assert(state == Raffle.State.CLOSED);
        assert(requestId > 0);
    }

    function testRandomOnlyAfterPerformUPKeep() 
    public skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(0, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() 
    public raffleEntered skipFork{
        // Arrange

        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address exceptedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: ticketPrice}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = exceptedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        /**[
         * ([0xeb0e3652e0f44f417695e6e90f2f42c99b65cd7169074c5a654b16b9748c3a4e, 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, 0x10316c63b8916590b900a272998c37c9a9131e6fd2560a77a15816ddc0f2700d, 0x00000000000000000000000062c20aa1e0272312bc100b4e23b4dc1ed96dd7d1], 
         * 0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000007a120000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000002492fd1338000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, 
         * 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496), 
         * ([0xb67476d1d38e93caac2ca37113122e613c199269c4cea0d39c67807a6442b40a, 0x0000000000000000000000000000000000000000000000000000000000000001], 0x, 0x62c20Aa1e0272312BC100b4e23B4DC1Ed96dD7D1)]
         * 
         */
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console2.logBytes32(requestId);

        // Pretend to be Chainlink VRF
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(uint256(requestId), address(raffle));
        
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.State raffleState = raffle.getState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = ticketPrice * (additionalEntrants + 1);

        assert(exceptedWinner == recentWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
