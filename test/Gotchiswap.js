const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const aavegotchi_abi = require('./aavegotchi.json');
//const { ethers, upgrades } = require("hardhat");

const hre = require("hardhat");

describe("Gotchiswap", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployGotchiswapFixture() {

    const GhstAddress = "0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7";
    const GotchisAddress = "0x86935F11C86623deC8a25696E1C19a8659CbF95d";
    const WearablesAddress = "0x58de9AaBCaeEC0f69883C94318810ad79Cc6a44f";
    const AdminAddress = "0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD";

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD"],
    });

    const testAccount = await hre.ethers.getSigner(
      "0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD"
    );

    const aavegotchi = await hre.ethers.getContractAt(aavegotchi_abi, GotchisAddress);

    const Gotchiswap = await hre.ethers.getContractFactory("Gotchiswap");
    const gotchiswap = await hre.upgrades.deployProxy(
      Gotchiswap,
      [
        GhstAddress,
        GotchisAddress,
        WearablesAddress,
        AdminAddress
      ]
    );

    await gotchiswap.waitForDeployment();

    //const currentImplAddress = await upgrades.erc1967.getImplementationAddress(gotchiswap.target);
    //console.log("implementation: ", currentImplAddress);

    await aavegotchi.connect(testAccount).setApprovalForAll(gotchiswap.target, true);

    return {
        gotchiswap,
        aavegotchi,
        GhstAddress,
        GotchisAddress,
        WearablesAddress,
        AdminAddress,
        owner,
        testAccount,
        otherAccount
    };
  }

  describe("Deployment", function () {
    it("Should set the right admin address", async function () {
      const { gotchiswap, AdminAddress } = await loadFixture(deployGotchiswapFixture);

      expect(await gotchiswap.adminAddress()).to.equal(AdminAddress);
    });
    it("Should be a fork of mainnet", async function () {
      const { aavegotchi, testAccount } = await loadFixture(deployGotchiswapFixture);

      expect(await aavegotchi.balanceOf(testAccount.address)).to.equal(16);
    });
    it("Should have approval to spend test gotchis", async function () {
      const { gotchiswap, aavegotchi, owner, testAccount } = await loadFixture(deployGotchiswapFixture);

      expect(await aavegotchi.isApprovedForAll(testAccount.address, gotchiswap.target)).to.be.true;
    });
  });

  describe("Sales", function () {
    it("Should be able to create a sale", async function () {
      const { gotchiswap, aavegotchi, owner, testAccount } = await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAccount).sellGotchi(4895, 1, owner.address);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      console.log(await gotchiswap.getOffer(owner.address, 0));
    });
  });
});
