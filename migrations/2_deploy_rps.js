const RockPaperScissors = artifacts.require('RockPaperScissors');

module.exports = async function (deployer) {

    await deployer.deploy(
        RockPaperScissors,
        "0xEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE", // Deployed ULP Address
        "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", // Deployed GBTS Address
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665"
    );

    return;
};
