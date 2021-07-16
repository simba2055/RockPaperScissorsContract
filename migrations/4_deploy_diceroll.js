const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");
const DiceRoll = artifacts.require('DiceRoll');

module.exports = async function (deployer) {

    const UnifiedLiquidityPoolInstance = await UnifiedLiquidityPool.deployed();
    const GBTSInstance = await GBTS.deployed();

    await deployer.deploy(
        DiceRoll,
        UnifiedLiquidityPoolInstance.address,
        GBTSInstance.address,
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665"
    );

    return;
};
