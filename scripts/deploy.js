const hre = require("hardhat");

async function main() {

  // mumbai
  //const AdminAddress = "0x5DaFd030C07844741157CcDcc366306822dd5FF3";
  // polygon
  const AdminAddress = "0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD";

  const Gotchiswap = await hre.ethers.getContractFactory("Gotchiswap");
  const gotchiswap = await hre.upgrades.deployProxy(
    Gotchiswap,
    [AdminAddress]
  );

  await gotchiswap.waitForDeployment();

  console.log("Gotchiswap proxy deployed to:", await gotchiswap.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
