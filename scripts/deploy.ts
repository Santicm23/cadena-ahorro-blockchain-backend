import hre from "hardhat";

async function main() {
  const ChainGameFactory = await hre.ethers.getContractFactory(
    "ChainGame"
  );

  const chainGame = await ChainGameFactory.deploy();

  await chainGame.waitForDeployment();

  const contractAddress = await chainGame.getAddress();

  console.log("ChainGame deployed to:", contractAddress);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
