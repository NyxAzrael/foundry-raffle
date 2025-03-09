// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * @title A game of Raffle
 * @author Azrael Nyx
 * @notice A game of chance where players can buy tickets to win a prize
 * @dev This contract is a work in progress
 *
 */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";






contract Raffle is VRFConsumerBaseV2Plus {
    //errors
    //error of enterRaffle function when the ticket price is not enough
    error InvalidTicketPrice();
    error Raffle__notOpen();
    error Raffle__cannotTransfer();
    error Raffle_notupkeep(uint256 balance, uint256 length, uint256 state);

    //events
    event enterPlayer(address indexed player);
    event Winner(address indexed winner);
    event RequestedWinner(uint256 indexed requestId);

    // Chainlink VRF related variables
    address immutable i_vrfCoordinator;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    //type declarations

    enum State {
        OPEN,
        CLOSED
    }
    //state variables

    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private lastTime;
    State private s_state;
    //constructor

    constructor(
        uint256 _ticketPrice,
        uint256 _interval,
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_ticketPrice = _ticketPrice;
        i_interval = _interval;
        lastTime = block.timestamp;

        i_vrfCoordinator = vrfCoordinatorV2;
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;

        s_state = State.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_ticketPrice) {
            revert InvalidTicketPrice();
        }
        if (s_state == State.CLOSED) {
            revert Raffle__notOpen();
        }
        s_players.push(payable(msg.sender));
        emit enterPlayer(msg.sender);
    }

    function checkUpKeep(bytes memory /*checkdata */ ) public view returns (bool upkeepNeeded, bytes memory) {
        bool timePassed = (block.timestamp > (lastTime + i_interval));
        bool isBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        bool isOpen = s_state == State.OPEN;

        return (timePassed && isBalance && hasPlayers && isOpen, "");
    }

    function performUPKeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle_notupkeep(address(this).balance, s_players.length, uint256(s_state));
        }
        s_state = State.CLOSED;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedWinner(requestId);
    }

    function getTicketPrice() public view returns (uint256) {
        return i_ticketPrice;
    }

    function fulfillRandomWords(uint256 , uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        
        s_players = new address payable[](0);
        s_state = State.OPEN;
        lastTime = block.timestamp;
        emit Winner(winner);

        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__cannotTransfer();
        }
    }
    //get functions

    function getState() public view returns (State) {
        return s_state;
    }

    function getPlayer(uint256 indexPlayer) external view returns (address) {
        return s_players[indexPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return lastTime;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
    function getInterval() external view returns (uint256) {
        return i_interval;
    }
   
}