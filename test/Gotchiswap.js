const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const aavegotchi_abi = require('./aavegotchi.json');
const ghst_abi = require('./ghst.json');
//const { ethers, upgrades } = require("hardhat");

const hre = require("hardhat");

const MAX_UINT256 = (2n ** 256n) - 1n;

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

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0xE1bCD0f5c6c855ee3452B38E16FeD0b7Cb0CC507"],
    });

    const testAdmin = await hre.ethers.getSigner(
      "0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD"
    );

    const testUser = await hre.ethers.getSigner(
      "0xE1bCD0f5c6c855ee3452B38E16FeD0b7Cb0CC507"
    );

    const aavegotchi = await hre.ethers.getContractAt(aavegotchi_abi, GotchisAddress);
    const ghst = await hre.ethers.getContractAt(ghst_abi, GhstAddress);

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

    await aavegotchi.connect(testAdmin).setApprovalForAll(gotchiswap.target, true);
    await ghst.connect(testAdmin).transfer(owner.address, 100000000000000000000n);
    await ghst.connect(testAdmin).approve(gotchiswap.target, MAX_UINT256);
    await ghst.approve(gotchiswap.target, MAX_UINT256);

    return {
        gotchiswap,
        aavegotchi,
        ghst,
        GhstAddress,
        GotchisAddress,
        WearablesAddress,
        AdminAddress,
        testAdmin,
        testUser,
        owner,
        otherAccount
    };
  }

  describe("Deployment", function () {
    it("Should set the right admin address", async function () {
      const { gotchiswap, AdminAddress } = await loadFixture(deployGotchiswapFixture);

      expect(await gotchiswap.adminAddress()).to.equal(AdminAddress);
    });
    it("Should be a fork of mainnet", async function () {
      const { aavegotchi, testAdmin } = await loadFixture(deployGotchiswapFixture);

      expect(await aavegotchi.balanceOf(testAdmin.address)).to.equal(16);
    });
    it("Should have approval to spend testAdmin gotchis", async function () {
      const { gotchiswap, aavegotchi, testAdmin } = await loadFixture(deployGotchiswapFixture);

      expect(await aavegotchi.isApprovedForAll(testAdmin.address, gotchiswap.target)).to.be.true;
    });
    it("Should have approval to spend testAdmin GHSTs", async function () {
      const { gotchiswap, ghst, testAdmin } = await loadFixture(deployGotchiswapFixture);

      expect(await ghst.allowance(testAdmin.address, gotchiswap.target)).to.equal(MAX_UINT256);
    });
    it("Should have approval to spend owner GHSTs", async function () {
      const { gotchiswap, ghst, owner } = await loadFixture(deployGotchiswapFixture);

      expect(await ghst.allowance(owner.address, gotchiswap.target)).to.equal(MAX_UINT256);
    });
    it("Should have sent 100 GHST to owner", async function () {
      const { gotchiswap, ghst, owner } = await loadFixture(deployGotchiswapFixture);

      expect(await ghst.balanceOf(owner.address)).to.equal(100000000000000000000n);
    });
  });

  describe("Trades", function () {
    it("Should be able to sell a gotchi to himself", async function () {
      const { gotchiswap, aavegotchi, owner, testAdmin } = await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAdmin).sellGotchi(4895, "100000000000000000000", testAdmin.address);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await gotchiswap.getBuyerSalesCount(testAdmin.address)).to.equal(1);
      await gotchiswap.connect(testAdmin).buyGotchi(0);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
    });
    it("Should be able to sell a gotchi to someone else", async function () {
      const { gotchiswap, aavegotchi, owner, testAdmin } = await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAdmin).sellGotchi(15434, 100000000000000000000n, owner.address);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await gotchiswap.getBuyerSalesCount(owner.address)).to.equal(1);
      await gotchiswap.buyGotchi(0);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.balanceOf(owner.address)).to.equal(1);
    });
  });

  describe("Admin Functions", function () {
    it("Should be able to retrieve a gotchi from the contract", async function () {
      const { gotchiswap, aavegotchi, testUser, testAdmin } = await loadFixture(deployGotchiswapFixture);
      await aavegotchi.connect(testUser).safeTransferFrom(testUser.address, gotchiswap.target, 10356);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      await gotchiswap.connect(testAdmin).withdrawERC721(10356);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.ownerOf(10356)).to.equal(testAdmin.address);
    });
    it("Should be able to retrieve GHST from the contract", async function () {
      const { gotchiswap, ghst, testUser, testAdmin } = await loadFixture(deployGotchiswapFixture);
      const testAdminBalanceBefore = await ghst.balanceOf(testAdmin.address);
      const testAdminBalanceAfter = testAdminBalanceBefore + 10000000000000000000n;
      await ghst.connect(testUser).transfer(gotchiswap.target, 10000000000000000000n);
      expect(await ghst.balanceOf(gotchiswap.target)).to.equal(10000000000000000000n);
      await gotchiswap.connect(testAdmin).withdrawGHST();
      expect(await ghst.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await ghst.balanceOf(testAdmin.address)).to.equal(testAdminBalanceAfter);
    });
  });
});
