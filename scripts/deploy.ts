import hre from "hardhat";

async function main() {
  const SimpleContractFactory = await hre.ethers.getContractFactory(
    "SimpleContract"
  );

  const simpleContract = await SimpleContractFactory.deploy();

  await simpleContract.waitForDeployment();

  const contractAddress = simpleContract.address;

  console.log("SimpleContract deployed to:", contractAddress);
}
