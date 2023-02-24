import { ethers } from "hardhat";

async function main() {
  const PersonalMining = await ethers.getContractFactory("PersonalMining");
  const PersonalMining = await PersonalMining.deploy();

  await PersonalMining.deployed();

  console.log(`Personal Mining deployed to ${PersonalMining.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
