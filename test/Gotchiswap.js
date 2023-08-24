const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const aavegotchi_abi = require("./aavegotchi.json");
const erc20_abi = require("./erc20.json");
const wearables_abi = require("./wearables.json");

const hre = require("hardhat");

const MAX_UINT256 = 2n ** 256n - 1n;
const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";

describe("Gotchiswap", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployGotchiswapFixture() {
    const GhstAddress = "0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7";
    const GltrAddress = "0x3801C3B3B5c98F88a9c9005966AA96aa440B9Afc";
    const AavegotchiAddress = "0x86935F11C86623deC8a25696E1C19a8659CbF95d";
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

    const aavegotchi = await hre.ethers.getContractAt(
      aavegotchi_abi,
      AavegotchiAddress
    );
    const wearables = await hre.ethers.getContractAt(
      wearables_abi,
      WearablesAddress
    );
    const ghst = await hre.ethers.getContractAt(erc20_abi, GhstAddress);
    const gltr = await hre.ethers.getContractAt(erc20_abi, GltrAddress);

    const Gotchiswap = await hre.ethers.getContractFactory("Gotchiswap");
    const gotchiswap = await hre.upgrades.deployProxy(Gotchiswap, [
      AdminAddress,
    ]);

    await gotchiswap.waitForDeployment();

    const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
      gotchiswap.target
    );
    //console.log("implementation: ", currentImplAddress);

    // setup approvals
    await aavegotchi
      .connect(testAdmin)
      .setApprovalForAll(gotchiswap.target, true);
    await ghst.connect(testAdmin).approve(gotchiswap.target, MAX_UINT256);

    // setup owner with tokens
    await ghst
      .connect(testAdmin)
      .transfer(owner.address, 100000000000000000000n);
    await gltr
      .connect(testAdmin)
      .transfer(owner.address, 1000000000000000000000000n);
    await ghst.approve(gotchiswap.target, MAX_UINT256);
    await gltr.approve(gotchiswap.target, MAX_UINT256);

    await gotchiswap.connect(testAdmin).disableAllowlist();

    return {
      gotchiswap,
      aavegotchi,
      ghst,
      gltr,
      wearables,
      GhstAddress,
      GltrAddress,
      AavegotchiAddress,
      WearablesAddress,
      AdminAddress,
      testAdmin,
      testUser,
      owner,
      otherAccount,
    };
  }

  describe("Deployment", function () {
    it("Should set the right admin address", async function () {
      const { gotchiswap, AdminAddress } = await loadFixture(
        deployGotchiswapFixture
      );
      expect(await gotchiswap.adminAddress()).to.equal(AdminAddress);
    });
  });
  describe("Test environment", function () {
    it("Should be a fork of mainnet", async function () {
      const { aavegotchi, testAdmin } = await loadFixture(
        deployGotchiswapFixture
      );
      expect(await aavegotchi.ownerOf(4895)).to.equal(testAdmin.address);
    });
    it("Should have set all approvals", async function () {
      const { gotchiswap, aavegotchi, ghst, gltr, testAdmin, owner } =
        await loadFixture(deployGotchiswapFixture);
      expect(
        await aavegotchi.isApprovedForAll(testAdmin.address, gotchiswap.target)
      ).to.be.true;
      expect(
        await ghst.allowance(testAdmin.address, gotchiswap.target)
      ).to.equal(MAX_UINT256);
      expect(await ghst.allowance(owner.address, gotchiswap.target)).to.equal(
        MAX_UINT256
      );
      expect(await gltr.allowance(owner.address, gotchiswap.target)).to.equal(
        MAX_UINT256
      );
    });
    it("Should have set up owner with tokens", async function () {
      const { gotchiswap, ghst, gltr, owner } = await loadFixture(
        deployGotchiswapFixture
      );
      expect(await ghst.balanceOf(owner.address)).to.equal(
        100000000000000000000n
      );
      expect(await gltr.balanceOf(owner.address)).to.equal(
        1000000000000000000000000n
      );
    });
    it("Should have disabled allowlist globally", async function () {
      const { gotchiswap } = await loadFixture(deployGotchiswapFixture);
      expect(await gotchiswap.allowlistDisabled()).to.be.true;
    });
  });

  describe("Trades", function () {
    it("Should be able to sell a gotchi to oneself", async function () {
      const {
        gotchiswap,
        aavegotchi,
        ghst,
        GhstAddress,
        AavegotchiAddress,
        owner,
        testAdmin,
      } = await loadFixture(deployGotchiswapFixture);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      await gotchiswap
        .connect(testAdmin)
        .createSale(
          [2],
          [AavegotchiAddress],
          [4895],
          [1],
          [0],
          [GhstAddress],
          [0],
          [100000000000000000000n],
          testAdmin.address
        );

      // check gotchi is transferred
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(gotchiswap.target);

      // check sale has registered
      expect(await gotchiswap.getSellerSalesCount(testAdmin.address)).to.equal(
        1
      );
      expect(await gotchiswap.getBuyerOffersCount(testAdmin.address)).to.equal(
        1
      );

      // retrieve the sale from the mapping
      const sale = await gotchiswap.getSale(testAdmin.address, 0);
      // should expect
      //console.log("sale: ", sale);

      // test wrong offer index
      await expect(gotchiswap.connect(testAdmin).concludeSale(1))
        .to.be.revertedWith('Gotchiswap: Index out of bound, no offer found');
      // complete the trade
      await gotchiswap.connect(testAdmin).concludeSale(0);

      // check gotchi has transferred back to original owner
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.ownerOf(4895)).to.equal(testAdmin.address);

      // check sale has unregistered
      await expect(
        gotchiswap.getSellerSalesCount(testAdmin.address)
      ).to.be.revertedWith("Gotchiswap: No sales found for the seller");
      await expect(
        gotchiswap.getBuyerOffersCount(testAdmin.address)
      ).to.be.revertedWith("Gotchiswap: No offers found for the buyer");
    });
    it("Should be able to sell a gotchi to someone else", async function () {
      const {
        gotchiswap,
        aavegotchi,
        ghst,
        GhstAddress,
        AavegotchiAddress,
        owner,
        testAdmin,
      } = await loadFixture(deployGotchiswapFixture);
      const balanceBefore = await ghst.balanceOf(testAdmin.address);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      await gotchiswap
        .connect(testAdmin)
        .createSale(
          [2],
          [AavegotchiAddress],
          [4895],
          [1],
          [0],
          [GhstAddress],
          [0],
          [100000000000000000000n],
          owner.address
        );

      // check gotchi is transferred to contract
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(gotchiswap.target);
      // check sale has registered for both buyer and seller
      expect(await gotchiswap.getSellerSalesCount(testAdmin.address)).to.equal(
        1
      );
      expect(await gotchiswap.getBuyerOffersCount(owner.address)).to.equal(1);
      await gotchiswap.concludeSale(0);
      // check gotchi has transferred to buyer
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.balanceOf(owner.address)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(owner.address);
      // check money has transferred to seller
      expect(await ghst.balanceOf(owner.address)).to.equal(0);
      expect(await ghst.balanceOf(testAdmin.address)).to.equal(
        balanceBefore + 100000000000000000000n
      );
    });
    it("Should be able to trade bundles", async function () {
      const {
        gotchiswap,
        aavegotchi,
        ghst,
        gltr,
        wearables,
        GhstAddress,
        GltrAddress,
        AavegotchiAddress,
        WearablesAddress,
        owner,
        testAdmin,
      } = await loadFixture(deployGotchiswapFixture);
      const ghstBalanceBefore = await ghst.balanceOf(testAdmin.address);
      const gltrBalanceBefore = await gltr.balanceOf(testAdmin.address);
      const ghstBalanceAfter = ghstBalanceBefore + 100000000000000000000n;
      const gltrBalanceAfter = gltrBalanceBefore + 1000000000000000000000000n;
      const wearableBalanceBefore = await wearables.balanceOf(
        testAdmin.address,
        350
      );
      const wearableBalanceAfter = wearableBalanceBefore - 1n;
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await wearables.balanceOf(gotchiswap.target, 350)).to.equal(0);
      await gotchiswap
        .connect(testAdmin)
        .createSale(
          [2, 1],
          [AavegotchiAddress, WearablesAddress],
          [4895, 350],
          [1, 1],
          [0, 0],
          [GhstAddress, GltrAddress],
          [0, 0],
          [100000000000000000000n, 1000000000000000000000000n],
          owner.address
        );

      // check assets have transferred to contract
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(gotchiswap.target);
      expect(await wearables.balanceOf(gotchiswap.target, 350)).to.equal(1);
      // check sale has registered for both buyer and seller
      expect(await gotchiswap.getSellerSalesCount(testAdmin.address)).to.equal(
        1
      );
      expect(await gotchiswap.getBuyerOffersCount(owner.address)).to.equal(1);
      await gotchiswap.concludeSale(0);
      // check assets has transferred to buyer
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await wearables.balanceOf(gotchiswap.target, 350)).to.equal(0);
      expect(await aavegotchi.balanceOf(owner.address)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(owner.address);
      expect(await wearables.balanceOf(owner.address, 350)).to.equal(1);
      // check money has transferred to seller
      expect(await ghst.balanceOf(owner.address)).to.equal(0);
      expect(await gltr.balanceOf(owner.address)).to.equal(0);
      expect(await ghst.balanceOf(testAdmin.address)).to.equal(
        ghstBalanceAfter
      );
      expect(await gltr.balanceOf(testAdmin.address)).to.equal(
        gltrBalanceAfter
      );
    });
    it("Should be able to abort a non settled trade", async function () {
      const {
        gotchiswap,
        aavegotchi,
        AavegotchiAddress,
        GhstAddress,
        owner,
        testAdmin,
      } = await loadFixture(deployGotchiswapFixture);
      const gotchisBefore = await aavegotchi.balanceOf(testAdmin.address);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      await gotchiswap
        .connect(testAdmin)
        .createSale(
          [2],
          [AavegotchiAddress],
          [4895],
          [1],
          [0],
          [GhstAddress],
          [0],
          [100000000000000000000n],
          owner.address
        );
      // check the gotchi is transferred to the contract
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(gotchiswap.target);
      // check sale has registered for both buyer and seller
      expect(await gotchiswap.getSellerSalesCount(testAdmin.address)).to.equal(
        1
      );
      expect(await gotchiswap.getBuyerOffersCount(owner.address)).to.equal(1);
      // test revert on bad index
      await expect(gotchiswap.connect(testAdmin).abortSale(1))
        .to.be.revertedWith("Gotchiswap: Index out of bound, no sale found");
      await gotchiswap.connect(testAdmin).abortSale(0);
      // check that the gotchi is returned to the owner
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.balanceOf(testAdmin.address)).to.equal(
        gotchisBefore
      );
      expect(await aavegotchi.ownerOf(4895)).to.equal(testAdmin.address);
    });
  });
  describe("Allowlist functions", function () {
    it("Should be able to enable allowlist globally", async function () {
      const { gotchiswap, testAdmin } = await loadFixture(
        deployGotchiswapFixture
      );
      await gotchiswap.connect(testAdmin).enableAllowlist();
      expect(await gotchiswap.allowlistDisabled()).to.be.false;
    });
    it("Should not be able to trade when allowlist is enabled and empty", async function () {
      const { gotchiswap, AavegotchiAddress, GhstAddress, testAdmin } =
        await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAdmin).enableAllowlist();
      await expect(
        gotchiswap
          .connect(testAdmin)
          .createSale(
            [2],
            [AavegotchiAddress],
            [4895],
            [1],
            [0],
            [GhstAddress],
            [0],
            [100000000000000000000n],
            testAdmin.address
          )
      ).to.be.revertedWith("Gotchiswap: Contract address in not allowed");
    });
    it("Should be able to trade when allowlist is enabled and contracts are added", async function () {
      const {
        gotchiswap,
        aavegotchi,
        AavegotchiAddress,
        GhstAddress,
        testAdmin,
      } = await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAdmin).enableAllowlist();
      await gotchiswap
        .connect(testAdmin)
        .allowContracts([AavegotchiAddress, GhstAddress]);
      expect(await gotchiswap.isContractAllowed(AavegotchiAddress)).to.be.true;
      expect(await gotchiswap.isContractAllowed(GhstAddress)).to.be.true;
      await gotchiswap
        .connect(testAdmin)
        .createSale(
          [2],
          [AavegotchiAddress],
          [4895],
          [1],
          [0],
          [GhstAddress],
          [0],
          [100000000000000000000n],
          testAdmin.address
        );
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(4895)).to.equal(gotchiswap.target);
    });
    it("Should be able to disallow contracts after enabling them", async function () {
      const { gotchiswap, AavegotchiAddress, GhstAddress, testAdmin } =
        await loadFixture(deployGotchiswapFixture);
      await gotchiswap.connect(testAdmin).enableAllowlist();
      await gotchiswap.connect(testAdmin).allowContract(AavegotchiAddress);
      expect(await gotchiswap.isContractAllowed(AavegotchiAddress)).to.be.true;
      await gotchiswap.connect(testAdmin).disallowContract(AavegotchiAddress);
      expect(await gotchiswap.isContractAllowed(AavegotchiAddress)).to.be.false;
    });
    it("Should not be possible to allow null address", async function () {
      const { gotchiswap, testAdmin } = await loadFixture(
        deployGotchiswapFixture
      );
      await expect(
        gotchiswap.connect(testAdmin).allowContract(ADDRESS_ZERO)
      ).to.be.revertedWith("Gotchiswap: Invalid contract address");
    });
    it("Should be unable to manage allowlist if not admin", async function () {
      const { gotchiswap, AavegotchiAddress, testAdmin } = await loadFixture(
        deployGotchiswapFixture
      );
      await expect(gotchiswap.enableAllowlist()).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await expect(gotchiswap.disableAllowlist()).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await expect(
        gotchiswap.allowContract(AavegotchiAddress)
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await expect(
        gotchiswap.allowContracts([AavegotchiAddress])
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await expect(
        gotchiswap.disallowContract(AavegotchiAddress)
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await expect(
        gotchiswap.disallowContracts([AavegotchiAddress])
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
    });
  });
  describe("Admin functions", function () {
    it("Should be able to retrieve ERC721 from the contract (only admin)", async function () {
      const { gotchiswap, aavegotchi, AavegotchiAddress, testUser, testAdmin } =
        await loadFixture(deployGotchiswapFixture);
      await aavegotchi
        .connect(testUser)
        .safeTransferFrom(testUser.address, gotchiswap.target, 10356);
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(1);
      expect(await aavegotchi.ownerOf(10356)).to.equal(gotchiswap.target);
      // check that only admin can retrieve gotchis
      await expect(
        gotchiswap.rescueERC721(AavegotchiAddress, 10356)
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await gotchiswap
        .connect(testAdmin)
        .rescueERC721(AavegotchiAddress, 10356);
      // check that gotchi has been sent to admin
      expect(await aavegotchi.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await aavegotchi.ownerOf(10356)).to.equal(testAdmin.address);
    });
    it("Should be able to retrieve ERC1155 from the contract (only admin)", async function () {
      const { gotchiswap, wearables, WearablesAddress, testUser, testAdmin } =
        await loadFixture(deployGotchiswapFixture);
      const testAdminBalanceBefore = await wearables.balanceOf(
        testAdmin.address,
        292
      );
      const testAdminBalanceAfter = testAdminBalanceBefore + 1n;
      await wearables
        .connect(testUser)
        .safeTransferFrom(testUser.address, gotchiswap.target, 292, 1, "0x");
      expect(await wearables.balanceOf(gotchiswap.target, 292)).to.equal(1);
      // check that only admin can retrieve gotchis
      await expect(
        gotchiswap.rescueERC1155(WearablesAddress, 292, 1)
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await gotchiswap
        .connect(testAdmin)
        .rescueERC1155(WearablesAddress, 292, 1);
      // check that gotchi has been sent to admin
      expect(await wearables.balanceOf(gotchiswap.target, 292)).to.equal(0);
      expect(await wearables.balanceOf(testAdmin.address, 292)).to.equal(
        testAdminBalanceAfter
      );
    });
    it("Should be able to retrieve ERC20 from the contract (only admin)", async function () {
      const { gotchiswap, ghst, GhstAddress, testUser, testAdmin } =
        await loadFixture(deployGotchiswapFixture);
      const testAdminBalanceBefore = await ghst.balanceOf(testAdmin.address);
      const testAdminBalanceAfter =
        testAdminBalanceBefore + 10000000000000000000n;
      await ghst
        .connect(testUser)
        .transfer(gotchiswap.target, 10000000000000000000n);
      expect(await ghst.balanceOf(gotchiswap.target)).to.equal(
        10000000000000000000n
      );
      // check that only admin can retrieve GHST
      await expect(
        gotchiswap.rescueERC20(GhstAddress, 10000000000000000000n)
      ).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await gotchiswap
        .connect(testAdmin)
        .rescueERC20(GhstAddress, 10000000000000000000n);
      // check that GHST have been sent to admin
      expect(await ghst.balanceOf(gotchiswap.target)).to.equal(0);
      expect(await ghst.balanceOf(testAdmin.address)).to.equal(
        testAdminBalanceAfter
      );
    });
    it("Should be able to change admin address (only admin)", async function () {
      const { gotchiswap, testAdmin, owner } = await loadFixture(
        deployGotchiswapFixture
      );
      // check that only admin can change admin address
      await expect(gotchiswap.changeAdmin(owner.address)).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      // check that admin address cannot be set to null address
      await expect(
        gotchiswap.connect(testAdmin).changeAdmin(ADDRESS_ZERO)
      ).to.be.revertedWith(
        "Gotchiswap: Cannot change admin to an invalid address"
      );
      await gotchiswap.connect(testAdmin).changeAdmin(owner.address);
      // check that admin address has been set to new address
      expect(await gotchiswap.adminAddress()).to.equal(owner.address);
    });
    it("Should be able to remove admin (only admin)", async function () {
      const { gotchiswap, testAdmin, owner } = await loadFixture(
        deployGotchiswapFixture
      );
      // check that only admin can remove admin
      await expect(gotchiswap.removeAdmin()).to.be.revertedWith(
        "Gotchiswap: Only the admin can perform this action"
      );
      await gotchiswap.connect(testAdmin).removeAdmin();
      // check that admin address is set to null address
      expect(await gotchiswap.adminAddress()).to.equal(ADDRESS_ZERO);
    });
  });
});
