// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IAggregator.sol";

/**
 * @title Rock Paper Scissors Contract
 */
contract RockPaperScissors is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IAggregator public LinkUSDT;
    IAggregator public GBTSUSDT;

    uint256 constant RTP = 98;
    uint256 constant gameId = 3;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    bool public isLocked;

    uint256 public vrfCost = 10000; // 0.0001 Link

    struct BetInfo {
        uint256 number;
        uint256 amount;
        uint256 gameRandomNumber;
    }

    mapping(address => BetInfo) private betInfos;

    /// @notice Event emitted only on construction.
    event RockPaperScissorsDeployed();

    /// @notice Event emitted when player start the betting.
    event BetStarted(address indexed player, uint256 number, uint256 amount);

    /// @notice Event emitted when player finish the betting.
    event BetFinished(address indexed player, string result);

    /// @notice Event emitted when game number generated.
    event VerifiedGameNumber(uint256 vrf, uint256 gameNumber, uint256 gameId);

    modifier unLocked() {
        require(isLocked == false, "RockPaperScissors: Game is locked");
        _;
    }

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _GBTSUSDT Interface of GBTS Token USDT Aggregator
     * @param _LinkUSDT Interface of Link Token USDT Aggregator "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665" Address of LINK/USD Price Contract
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IAggregator _GBTSUSDT,
        IAggregator _LinkUSDT
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        GBTSUSDT = _GBTSUSDT;
        LinkUSDT = _LinkUSDT;

        emit RockPaperScissorsDeployed();
    }

    /**
     * @dev External function for start betting. This function can be called by players.
     * @param _number Tracks Player Selection for UI
     * @param _amount Amount of player betted.
     */
    function bet(uint256 _number, uint256 _amount) external unLocked {
        require(
            betInfos[msg.sender].amount == 0,
            "RockPaperScissors: Already betted"
        );
        require(
            0 <= _number && _number < 3,
            "RockPaperScissors: Number out of range"
        );
        require(
            GBTS.balanceOf(msg.sender) >= _amount,
            "RockPaperScissors: Caller has not enough balance"
        );

        uint256 multiplier = 244;
        uint256 winnings = (_amount * multiplier) / 100;

        require(
            checkBetAmount(winnings, _amount),
            "RockPaperScissors: Bet amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        betInfos[msg.sender].number = _number;
        betInfos[msg.sender].amount = _amount;
        betInfos[msg.sender].gameRandomNumber = ULP.getRandomNumber();
        betGBTS += _amount;

        emit BetStarted(msg.sender, _number, _amount);
    }

    /**
     * @dev External function for calculate betting win or lose.
     */
    function play() external nonReentrant unLocked {
        require(
            betInfos[msg.sender].amount != 0,
            "RockPaperScissors: Cannot play without betting"
        );

        uint256 newRandomNumber = ULP.getNewRandomNumber(
            betInfos[msg.sender].gameRandomNumber
        );

        uint256 gameNumber = uint256(
            keccak256(abi.encode(newRandomNumber, address(msg.sender), gameId))
        ) % 3; // 0: Rock, 1: Paper, 2: Scissors

        emit VerifiedGameNumber(newRandomNumber, gameNumber, gameId);

        BetInfo storage betInfo = betInfos[msg.sender];

        if (gameNumber == betInfo.number) {
            //Draw
            uint256 amountToSend = betInfo.amount / 2;

            ULP.sendPrize(msg.sender, amountToSend);

            paidGBTS += amountToSend;

            emit BetFinished(msg.sender, "Draw");
        } else if (
            (gameNumber == 0 && betInfo.number == 1) ||
            (gameNumber == 1 && betInfo.number == 2) ||
            (gameNumber == 2 && betInfo.number == 0)
        ) {
            //Win
            uint256 amountToSend = (betInfo.amount * 244) / 100;

            ULP.sendPrize(msg.sender, amountToSend);

            paidGBTS += amountToSend;

            emit BetFinished(msg.sender, "Win");
        } else {
            //Lose
            emit BetFinished(msg.sender, "Lose");
        }
        betInfo.amount = 0;
    }

    /**
     * @dev Public function for returns min bet amount with current Link and GBTS token price.
     */
    function minBetAmount() public view returns (uint256) {
        int256 GBTSPrice;
        int256 LinkPrice;

        (, GBTSPrice, , , ) = GBTSUSDT.latestRoundData();
        (, LinkPrice, , , ) = LinkUSDT.latestRoundData();

        return (uint256(LinkPrice) * 53) / (uint256(GBTSPrice) * vrfCost);
    }

    /**
     * @dev Internal function to check current bet amount is enough to bet.
     * @param _winnings Amount of GBTS if user wins.
     * @param _betAmount Bet Amount
     */
    function checkBetAmount(uint256 _winnings, uint256 _betAmount)
        internal
        view
        returns (bool)
    {
        return (GBTS.balanceOf(address(ULP)) / 100 >= _winnings &&
            _betAmount >= minBetAmount());
    }

    /**
     * @dev External function for lock the game. This function is called by owner only.
     */
    function lock() external unLocked onlyOwner {
        _lock();
    }

    /**
     * @dev Private function for lock the game.
     */
    function _lock() private {
        isLocked = true;
    }

    /**
     * @dev External function for unlock the game. This function is called by owner only.
     */
    function unLock() external onlyOwner {
        require(isLocked == true);

        isLocked = false;
    }
}
