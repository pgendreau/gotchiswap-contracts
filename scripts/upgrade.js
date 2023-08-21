const { ethers, upgrades } = require("hardhat");

async function main() {
  const Gotchiswap = await ethers.getContractFactory("Gotchiswap");
  const gotchiswap = await upgrades.upgradeProxy("0xFE4B96f1860c5A2A09CD4bD5C341632c9E9486e6", Gotchiswap);
  console.log("Gotchiswap upgraded");
}

main();
