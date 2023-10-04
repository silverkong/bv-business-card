import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { BusinessCardNFT } from "../typechain-types";

describe("BusinessCardNFT", () => {
  let businessCardNFT: BusinessCardNFT;
  let owner: Signer;
  let addressToSend: Signer;

  before("Deploy Business Card", async () => {
    const businessCardNFTFactory = await ethers.getContractFactory(
      "BusinessCardNFT"
    );
    businessCardNFT =
      (await businessCardNFTFactory.deploy()) as BusinessCardNFT;
    [owner, addressToSend] = await ethers.getSigners();
  });

  describe("Register Business Card Info", () => {
    it("Should Register Business Card Info", async () => {
      await businessCardNFT
        .connect(owner)
        .resgisterBusinessCardInfo(
          "정은빈",
          "ISFJ",
          "010-1234-1234",
          "블록체인밸리"
        );
      const businessCardInfo = await businessCardNFT.getBusinessCardInfo(
        await owner.getAddress()
      );

      expect(businessCardInfo.name).to.equal("정은빈");
      expect(businessCardInfo.mbti).to.equal("ISFJ");
      expect(businessCardInfo.phone).to.equal("010-1234-1234");
      expect(businessCardInfo.company).to.equal("블록체인밸리");
    });
  });

  describe("Mint Business Card", () => {
    it("Should Mint BusinessCardNFT", async () => {
      await businessCardNFT.connect(owner).mintBusinessCard("");
      const businessCardInfo = await businessCardNFT.getBusinessCardInfo(
        await owner.getAddress()
      );

      expect(
        await businessCardNFT.balanceOf(await owner.getAddress())
      ).to.equal(5);
    });

    it("Should Mint BusinessCardNFT 2", async () => {
      await businessCardNFT
        .connect(owner)
        .mintBusinessCard("", { value: ethers.parseEther("0.01") });
      const businessCardInfo = await businessCardNFT.getBusinessCardInfo(
        await owner.getAddress()
      );

      expect(
        await businessCardNFT.balanceOf(await owner.getAddress())
      ).to.equal(10);
    });
  });

  describe("Transfer Business Card", () => {
    it("Should Transfer Business Card", async () => {
      await businessCardNFT
        .connect(owner)
        .transferBusinessCard(await addressToSend.getAddress(), "", "");

      expect(
        await businessCardNFT.balanceOf(await addressToSend.getAddress())
      ).to.equal(1);

      expect(
        await businessCardNFT.balanceOf(await owner.getAddress())
      ).to.equal(9);

      expect(
        await businessCardNFT.getAmountOfTokenOwnedByIssuer(
          await owner.getAddress()
        )
      ).to.equal(9);
    });
  });
});
