const { ethers, upgrades } = require("hardhat");

async function main() {
  const Gotchiswap = await ethers.getContractFactory("Gotchiswap");
  const gotchiswap = await upgrades.upgradeProxy("0x27064131565F96fDa5D7BD6A813f12a744fd85a6", Gotchiswap);
  console.log("Gotchiswap upgraded");
}

main();
