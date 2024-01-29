// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
//const hre = require("hardhat");
//
//async function main() {
//  const feeAccount = (await hre.getNamedAccounts()).deployer;
//  const feePercentage = 15;
//  const marketplace = await hre.ethers.deployContract("NovaNexHubMarketplace", [
//    feeAccount,
//    feePercentage,
//  ]);
//
//  await marketplace.waitForDeployment();
//
//  console.log("marketplace: ", marketplace);
//}
//
//// We recommend this pattern to be able to use async/await everywhere
//// and properly handle errors.
//main().catch((error) => {
//  console.error(error);
//  process.exitCode = 1;
//});
//

const { ethers } = require("hardhat");

async function main() {
  const ERC4907 = await ethers.getContractFactory("ERC4907");
  const erc4907 = await ERC4907.deploy();
  await erc4907.deployed();

  const NovaNexHub = await ethers.getContractFactory("NovaNexHub");
  const novaNexHub = await NovaNexHub.deploy();
  await novaNexHub.deployed();

  const NovaNexHubMarketplace = await ethers.getContractFactory("NovaNexHubMarketplace");
  const nft = await NovaNexHubMarketplace.deploy();
  await nft.deployed();

  console.log("Contracts deployed:", erc4907.address, novaNexHub.address, nft.address);
}

main();
