const hre = require("hardhat");

async function main() {

  // mumbai
  //const GhstAddress = "0xc93A55a39356BddA580036Ce50044C106Dd211c8";
  //const GotchisAddress = "0x83e73D9CF22dFc3A767EA1cE0611F7f50306622e";
  //const WearablesAddress = "0x1b1bcB49A744a09aEd636CDD9893508BdF1431A8";
  const GhstAddress = "0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7";
  const GotchisAddress = "0x86935F11C86623deC8a25696E1C19a8659CbF95d";
  const WearablesAddress = "0x58de9AaBCaeEC0f69883C94318810ad79Cc6a44f";
  const AdminAddress = "0x43FF4C088df0A425d1a519D3030A1a3DFff05CfD";

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

  console.log("Gotchiswap proxy deployed to:", await gotchiswap.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
