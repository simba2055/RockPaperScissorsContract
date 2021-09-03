// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGame.sol";

/**
 * @title RandomNumberGenerator Contract
 */
contract RandomNumberGenerator is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    IUnifiedLiquidityPool public ULP;
    uint256 private currentRandomNumber;

    mapping(bytes32 => address) requestToGame;

    /// @notice Event emitted when contract is deployed.
    event RandomNumberGeneratorDeployed();

    /// @notice Event emitted when chainlink verified random number arrived or requested.
    event randomNumberArrived(
        bool arrived,
        uint256 randomNumber,
        bytes32 batchID
    );

    modifier onlyApprovedGame() {
        require(
            ULP.currentGameApproved(msg.sender),
            "RandomNumberGenerator: Game is not approved"
        );
        _;
    }

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Polygon(Matic) Mainnet
     * Chainlink VRF Coordinator address: 0x3d2341ADb2D31f1c5530cDC622016af293177AE0
     * LINK token address:                0xb0897686c545045aFc77CF20eC7A532E3120E0F1
     * Key Hash:                          0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da
     * Fee : 0.0001LINK
     */
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee,
        IUnifiedLiquidityPool _ULP
    )
        VRFConsumerBase(
            _vrfCoordinator, // VRF Coordinator
            _link // LINK Token
        )
    {
        keyHash = _keyHash;
        fee = _fee;
        ULP = _ULP;

        emit RandomNumberGeneratorDeployed();
    }

    /**
     * @dev Public function to request randomness and returns request Id. This function can be called by only apporved games.
     */
    function requestRandomNumber()
        external
        onlyApprovedGame
        returns (bytes32 requestId)
    {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");

        bytes32 _requestId = requestRandomness(keyHash, fee);
        requestToGame[_requestId] = msg.sender;
        emit randomNumberArrived(false, currentRandomNumber, _requestId);

        return _requestId;
    }

    /**
     * @dev Callback function used by VRF Coordinator. This function calls the play method of current game contract with random number.
     * @param _requestId Request Id
     * @param _randomness Random Number
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        currentRandomNumber = _randomness;
        IGame GAME = IGame(requestToGame[_requestId]);
        GAME.play(_requestId, _randomness);

        emit randomNumberArrived(true, _randomness, _requestId);
    }
}
