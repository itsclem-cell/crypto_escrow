import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  const owner = process.env.OWNER_ADDRESS;
  const treasury = process.env.TREASURY_ADDRESS;
  const defaultArbiter = process.env.DEFAULT_ARBITER_ADDRESS;

  if (!owner || !treasury || !defaultArbiter) {
    throw new Error("Missing OWNER_ADDRESS, TREASURY_ADDRESS, or DEFAULT_ARBITER_ADDRESS in .env");
  }

  const EscrowFactory = await ethers.getContractFactory("EscrowFactory");
  const factory = await EscrowFactory.deploy(owner, treasury, defaultArbiter, 100);
  await factory.waitForDeployment();

  console.log("EscrowFactory deployed to:", await factory.getAddress());
  console.log("Owner:", owner);
  console.log("Treasury:", treasury);
  console.log("Default arbiter:", defaultArbiter);
  console.log("Default fee bps:", 100);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
