// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2_5} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Raffle
 * @author EngrPips
 * @notice This contract if Particpating in a Raffle and standing the chance to win.
 * @dev This contract heavily implements the chainlink VRF and Automation
 */
// 0x9ddfaca8183c41ad55329bdeed9f6a8d53168b1b => VRFCoordinator
// 54528670710849503547892655734386820566589065322714869834102560641565075666367 => subId
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {

    /* ERRORS */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error Raffle__LotteryIsCalculatingWinner();

    /* USER DEFINED TYPES */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* EVENTS */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* STATE VARIABLES */

    RaffleState private s_raffleState;
    IVRFCoordinatorV2Plus private immutable i_vrfCoordinatorContract;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;


    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;


    address payable private s_recentWinner;
    address payable[] private s_players;



    constructor(uint256 _entranceFee, uint256 _interval,address  _vrfCoordinator, bytes32 _gasLane, uint256 _subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus( _vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinatorContract = IVRFCoordinatorV2Plus(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }
    function enterRaffle() public payable {
        if (s_raffleState == RaffleState.CALCULATING) revert Raffle__RaffleNotOpen();
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool hasPlayer = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;

        upkeepNeeded = (timeHasPassed && hasPlayer && hasBalance && isOpen);
        return(upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) public {
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded) revert Raffle__UpkeepNotNeeded(address(this).balance, getNumberOfPlayers(), uint256(getRaffleState()));
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinatorContract.requestRandomWords(VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasLane,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        }));
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable addressOfWinner = s_players[indexOfWinner];
        s_recentWinner = addressOfWinner;
        emit PickedWinner(addressOfWinner);
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        (bool success,) = addressOfWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /** GETTERS */

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }


}