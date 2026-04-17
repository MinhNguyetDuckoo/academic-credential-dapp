import { expect } from "chai";
import { ethers } from "hardhat";
import { CredentialRegistry } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("CredentialRegistry", function () {
  let registry: CredentialRegistry;
  let owner: HardhatEthersSigner;
  let school: HardhatEthersSigner;
  let employer: HardhatEthersSigner;

  const STUDENT_NAME = "Nguyen Van A";
  const COURSE_NAME  = "Bachelor of Computer Science";
  const CRED_HASH    = ethers.keccak256(ethers.toUtf8Bytes("certificate-data-001"));

  beforeEach(async () => {
    [owner, school, employer] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("CredentialRegistry");
    registry = await Factory.deploy();
    await registry.waitForDeployment();
  });

  it("Owner được phép cấp chứng chỉ ngay sau deploy", async () => {
    expect(await registry.authorizedIssuers(owner.address)).to.equal(true);
  });

  it("Owner có thể ủy quyền cho trường học", async () => {
    await registry.authorizeIssuer(school.address);
    expect(await registry.authorizedIssuers(school.address)).to.equal(true);
  });

  it("Trường học cấp chứng chỉ thành công", async () => {
    await registry.authorizeIssuer(school.address);

    const tx = await registry.connect(school).issueCredential(
      STUDENT_NAME, COURSE_NAME, CRED_HASH
    );
    const receipt = await tx.wait();

    // Lấy credentialId từ event
    const event = receipt?.logs.find(
      (log: any) => log.fragment?.name === "CredentialIssued"
    ) as any;
    expect(event).to.not.be.undefined;
  });

  it("Nhà tuyển dụng xác thực chứng chỉ hợp lệ", async () => {
    await registry.authorizeIssuer(school.address);
    const tx = await registry.connect(school).issueCredential(
      STUDENT_NAME, COURSE_NAME, CRED_HASH
    );
    const receipt = await tx.wait();
    const event = receipt?.logs.find((log: any) => log.fragment?.name === "CredentialIssued") as any;
    const credentialId = event.args[0];

    const [isValid, cred] = await registry.connect(employer).verifyCredential(credentialId);
    expect(isValid).to.equal(true);
    expect(cred.studentName).to.equal(STUDENT_NAME);
  });

  it("Chứng chỉ bị thu hồi → xác thực trả về false", async () => {
    await registry.authorizeIssuer(school.address);
    const tx = await registry.connect(school).issueCredential(
      STUDENT_NAME, COURSE_NAME, CRED_HASH
    );
    const receipt = await tx.wait();
    const event = receipt?.logs.find((log: any) => log.fragment?.name === "CredentialIssued") as any;
    const credentialId = event.args[0];

    await registry.connect(school).revokeCredential(credentialId);
    const [isValid] = await registry.connect(employer).verifyCredential(credentialId);
    expect(isValid).to.equal(false);
  });

  it("Địa chỉ không có quyền KHÔNG được cấp chứng chỉ", async () => {
    await expect(
      registry.connect(employer).issueCredential(STUDENT_NAME, COURSE_NAME, CRED_HASH)
    ).to.be.revertedWith("Khong co quyen cap chung chi");
  });
});