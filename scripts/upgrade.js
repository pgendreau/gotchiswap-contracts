const { ethers, upgrades } = require("hardhat");

async function main() {
  const Gotchiswap = await ethers.getContractFactory("Gotchiswap");
  const gotchiswap = await upgrades.upgradeProxy("0xA463Bfcd554d0c4D1cCb9147B8C93De72A9A8ae7", Gotchiswap);
  console.log("Gotchiswap upgraded");
}

main();
