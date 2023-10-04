import { ethers } from "hardhat";
import { BusinessCardNFT, BusinessCardNFT__factory } from "../typechain-types";

async function main() {
  const businessCardNFTFactory: BusinessCardNFT__factory =
    await ethers.getContractFactory("BusinessCardNFT");
  const businessCardNFT: BusinessCardNFT =
    (await businessCardNFTFactory.deploy()) as BusinessCardNFT;
  console.log(
    "BusinessCardNFT deployed to: " + (await businessCardNFT.getAddress())
  );
}

main()
  .then(() => (process.exitCode = 0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
