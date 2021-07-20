const GBTS = artifacts.require("GBTS");
const ULP = artifacts.require("UnifiedLiquidityPool");
const RPS = artifacts.require("RockPaperScissors");
const RNG = artifacts.require("RandomNumberConsumer");
const { assert } = require("chai");
const { BN } = require("web3-utils");

contract("RockPaperScissors", (accounts) => {
    let gbts_contract, ulp_contract, RPS_contract, rng_contract;

    before(async () => {
        await GBTS.new(
            { from: accounts[0] }
        ).then((instance) => {
            gbts_contract = instance;
        });

        await RNG.new(
            "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9",   // Chainlink VRF Coordinator address
            "0xa36085F69e2889c224210F603D836748e7dC0088",   // LINK token address
            "0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4",   // Key Hash
            1, // fee
            { from: accounts[0] }
        ).then((instance) => {
            rng_contract = instance;
        });

        await ULP.new(
            gbts_contract.address,
            rng_contract.address,
            { from: accounts[0] }
        ).then((instance) => {
            ulp_contract = instance;
        });

        await RPS.new(
            ulp_contract.address,
            gbts_contract.address,
            "0xb77fa460604b9C6435A235D057F7D319AC83cb53",
            "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
            { from: accounts[0] }
        ).then((instance) => {
            RPS_contract = instance;
        });

        await gbts_contract.approve(ulp_contract.address, new BN('1000000000000000000000'), { from: accounts[0] }); // 1000 GBTS

        await ulp_contract.startStaking(
            new BN('1000000000000000000000'), //1000 GBTS
            { from: accounts[0] }
        );

        await gbts_contract.transfer(accounts[1], new BN('1000000000000000000000'), { from: accounts[0] }); // Win Account 1000 GBTS
        await gbts_contract.transfer(accounts[2], new BN('1000000000000000000000'), { from: accounts[0] }); // Lose Account 1000 GBTS

        await ulp_contract.changeGameApproval(RPS_contract.address, true, { from: accounts[0] });
        await rng_contract.setULPAddress(ulp_contract.address);
    });

    describe("Bet", () => {
        it("Betting is not working with locked", async () => {
            await RPS_contract.lock({ from: accounts[0] });
            let thrownError;
            try {
                await RPS_contract.bet(
                    40,
                    new BN('10000000000000000000000'), // 10000GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Game is locked',
            )
        });

        it("Betting is not working with insuffcient balance", async () => {
            await RPS_contract.unLock({ from: accounts[0] });
            let thrownError;
            try {
                await RPS_contract.bet(
                    40,
                    new BN('10000000000000000000000'), // 10000GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Caller has not enough balance',
            )
        });


        it("First player betting is working", async () => {
            await gbts_contract.approve(RPS_contract.address, new BN('1000000000000000000000'), { from: accounts[1] });
            await RPS_contract.bet(40, new BN('100000000000000000000'), { from: accounts[1] }); // Bet Number: 40, Bet Amount: 100GBTS
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('1100000000000000000000').toString());
        });

        it("Player already betted", async () => {
            let thrownError;
            try {
                await RPS_contract.bet(
                    40,
                    new BN('100000000000000000000'),
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Already betted',
            )
        });

        it("Betting is not working with number out of range", async () => {
            let thrownError;
            try {
                await RPS_contract.bet(
                    51,
                    new BN('100000000000000000000'),
                    { from: accounts[2] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Number out of range',
            )
        });

        it("Second player betting is working", async () => {
            await gbts_contract.approve(RPS_contract.address, new BN('100000000000000000000'), { from: accounts[2] });
            await RPS_contract.bet(20, new BN('100000000000000000000'), { from: accounts[2] }); // Bet Number: 20, Bet Amount: 100GBTS
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('1200000000000000000000').toString());
        });
    });

    describe("Play", () => {
        it("Play is not working with locked", async () => {

            await RPS_contract.lock({ from: accounts[0] });
            let thrownError;

            try {
                await RPS_contract.play({ from: accounts[1] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Game is locked',
            )
        });

        it("Play is not working without betting", async () => {
            await RPS_contract.unLock({ from: accounts[0] });
            let thrownError;

            try {
                await RPS_contract.play({ from: accounts[3] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'RockPaperScissors: Cannot play without betting',
            )
        });

        it("First player wins", async () => {
            await RPS_contract.play({ from: accounts[1] });
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('955000000000000000000').toString());
        });

        it("Second player loses", async () => {
            await RPS_contract.play({ from: accounts[2] });
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('955000000000000000000').toString());
        });

    });
});
