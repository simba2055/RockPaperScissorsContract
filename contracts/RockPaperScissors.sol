// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGembitesProxy.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/**
 * @title Rock Paper Scissors Contract
 */
contract RockPaperScissors is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice Event emitted when gembites proxy set.
    event GembitesProxySet(address newProxyAddress);

    /// @notice Event emitted when contract is deployed.
    event RockPaperScissorsDeployed();

    /// @notice Event emitted when bet is started.
    event BetStarted(
        address player,
        uint256 multiplier,
        uint256 number,
        uint256 amount
    );

    /// @notice Event emitted when bet is finished.
    event BetFinished(
        address player,
        uint256 paidAmount,
        uint256 betResult, // 0: Draw, 1: Win, 2: Loss
        BetInfo betInfo
    );

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IGembitesProxy public GembitesProxy;
    IRandomNumberGenerator public RNG;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    uint256 public gameId;

    struct BetInfo {
        address player;
        uint256 number;
        uint256 amount;
        uint256 multiplier;
        uint256 expectedWinAmount;
        bytes32 requestId;
        uint256 gameNumber;
    }

    mapping(bytes32 => BetInfo) public requestToBet;

    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "DiceRoll: Caller is not the RandomNumberGenerator"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of RandomNumberGenerator
     * @param _gameId Game Id
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IRandomNumberGenerator _RNG,
        uint256 _gameId
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        RNG = _RNG;
        gameId = _gameId;

        emit RockPaperScissorsDeployed();
    }

    /**
     * @dev External function for start betting. This function can be called by players.
     * @param _number Tracks Player Selection for UI
     * @param _amount Amount of player betted.
     */
    function bet(uint256 _number, uint256 _amount) external {
        uint256 expectedWinAmount;
        uint256 multiplier;
        uint256 minBetAmount;
        uint256 maxWinAmount;

        minBetAmount = GembitesProxy.getMinBetAmount();
        maxWinAmount = GBTS.balanceOf(address(ULP)) / 100;

        require(
            0 <= _number && _number < 3,
            "RockPaperScissors: Number out of range"
        );

        multiplier = 244;
        expectedWinAmount = (multiplier * _amount) / 1000;

        require(
            _amount >= minBetAmount && expectedWinAmount <= maxWinAmount,
            "RockPaperScissors: Expected paid amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

         bytes32 requestId = RNG.requestRandomNumber();

        requestToBet[requestId] = BetInfo(
            msg.sender,
            _number,
            _amount,
            multiplier,
            expectedWinAmount,
            requestId,
            0
        );

        betGBTS += _amount;

        emit BetStarted(msg.sender, multiplier, _number, _amount);
    }

    /**
     * @dev External function for playing. This function can be called by only RandomNumberGenerator.
     * @param _requestId Request Id
     * @param _randomness Random Number
     */
    function play(bytes32 _requestId, uint256 _randomness) external onlyRNG {
        BetInfo storage betInfo = requestToBet[_requestId];

        address player = betInfo.player;
        uint256 expectedWinAmount = betInfo.expectedWinAmount;

        uint256 gameNumber = uint256(
            keccak256(abi.encode(_randomness, player, gameId))
        ) % 3; // 0: Rock, 1: Paper, 2: Scissors

        betInfo.gameNumber = gameNumber;

        if (gameNumber == betInfo.number) {
            //Draw
            uint256 amountToSend = betInfo.amount / 2;

            ULP.sendPrize(msg.sender, amountToSend);

            paidGBTS += amountToSend;

            emit BetFinished(msg.sender, amountToSend, 0, betInfo);
        } else if (
            (gameNumber == 0 && betInfo.number == 1) ||
            (gameNumber == 1 && betInfo.number == 2) ||
            (gameNumber == 2 && betInfo.number == 0)
        ) {
            ULP.sendPrize(msg.sender, expectedWinAmount);

            paidGBTS += expectedWinAmount;

            emit BetFinished(msg.sender, expectedWinAmount, 1, betInfo);
        } else {
            //Lose
            emit BetFinished(msg.sender, 0, 2, betInfo);
        }
    }

    /**
     * @dev External function to set gembites proxy. This function can be called by only owner.
     * @param _newProxyAddress New Gembites Proxy Address
     */
    function setGembitesProxy(address _newProxyAddress) external onlyOwner {
        require(
            _newProxyAddress.isContract() == true,
            "RockPaperScissors: Address is not contract address"
        );
        GembitesProxy = IGembitesProxy(_newProxyAddress);

        emit GembitesProxySet(_newProxyAddress);
    }
}
