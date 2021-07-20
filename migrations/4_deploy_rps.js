const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");
const RockPaperScissors = artifacts.require('RockPaperScissors');

module.exports = async function (deployer) {

    const UnifiedLiquidityPoolInstance = await UnifiedLiquidityPool.deployed();
    const GBTSInstance = await GBTS.deployed();

    await deployer.deploy(
        RockPaperScissors,
        UnifiedLiquidityPoolInstance.address,
        GBTSInstance.address,
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665"
    );

    return;
};
