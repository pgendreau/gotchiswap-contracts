const { ethers, upgrades } = require("hardhat");

async function main() {
  const Gotchiswap = await ethers.getContractFactory("Gotchiswap");
  const gotchiswap = await upgrades.upgradeProxy("0x022a644b60a63BC6Dd51bd7Eab67E73F4f5a14d2", Gotchiswap);
  console.log("Gotchiswap upgraded");
}

main();
