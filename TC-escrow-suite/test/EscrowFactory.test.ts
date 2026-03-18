import { expect } from "chai";
import { ethers } from "hardhat";
import type { Escrow, EscrowFactory, MockERC20 } from "../typechain-types";

describe("EscrowFactory + Escrow", function () {
  async function deployFixture() {
    const [owner, payer, payee, arbiter, treasury, other] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token = (await MockERC20.deploy("Mock USD", "mUSD")) as MockERC20;
    await token.waitForDeployment();

    const Factory = await ethers.getContractFactory("EscrowFactory");
    const factory = (await Factory.deploy(
      owner.address,
      treasury.address,
      arbiter.address,
      100
    )) as EscrowFactory;
    await factory.waitForDeployment();

    return { owner, payer, payee, arbiter, treasury, other, token, factory };
  }

  it("creates a native escrow and releases on dual approval", async function () {
    const { payer, payee, arbiter, treasury, factory } = await deployFixture();
    const now = (await ethers.provider.getBlock("latest"))!.timestamp;
    const amount = ethers.parseEther("1");
    const termsHash = ethers.keccak256(ethers.toUtf8Bytes("native escrow terms v1"));

    const tx = await factory.createEscrowCustom(
      payer.address,
      payee.address,
      arbiter.address,
      ethers.ZeroAddress,
      treasury.address,
      amount,
      100,
      BigInt(now + 3600),
      BigInt(now + 7200),
      termsHash
    );

    const receipt = await tx.wait();
    const event = receipt!.logs.find((log) => {
      try {
        return factory.interface.parseLog(log as any)?.name === "EscrowCreated";
      } catch {
        return false;
      }
    });
    const parsed = factory.interface.parseLog(event as any)!;
    const escrowAddress = parsed.args.escrow as string;

    const escrow = (await ethers.getContractAt("Escrow", escrowAddress)) as Escrow;
    await expect(escrow.connect(payer).depositNative({ value: amount }))
      .to.emit(escrow, "Deposited")
      .withArgs(payer.address, amount);

    await escrow.connect(payer).approveRelease();
    await expect(escrow.connect(payee).approveRelease()).to.emit(escrow, "Released");

    expect(await escrow.status()).to.equal(4n);
  });

  it("refunds ERC20 escrow on dual refund approval", async function () {
    const { payer, payee, arbiter, treasury, token, factory } = await deployFixture();
    const now = (await ethers.provider.getBlock("latest"))!.timestamp;
    const amount = ethers.parseUnits("500", 18);
    const termsHash = ethers.keccak256(ethers.toUtf8Bytes("token escrow terms v1"));

    await token.mint(payer.address, amount);

    const tx = await factory.createEscrowCustom(
      payer.address,
      payee.address,
      arbiter.address,
      await token.getAddress(),
      treasury.address,
      amount,
      100,
      BigInt(now + 3600),
      BigInt(now + 7200),
      termsHash
    );

    const receipt = await tx.wait();
    const event = receipt!.logs.find((log) => {
      try {
        return factory.interface.parseLog(log as any)?.name === "EscrowCreated";
      } catch {
        return false;
      }
    });
    const parsed = factory.interface.parseLog(event as any)!;
    const escrowAddress = parsed.args.escrow as string;

    const escrow = (await ethers.getContractAt("Escrow", escrowAddress)) as Escrow;

    await token.connect(payer).approve(escrowAddress, amount);
    await escrow.connect(payer).depositToken();
    await escrow.connect(payee).approveRefund();
    await expect(escrow.connect(payer).approveRefund()).to.emit(escrow, "Refunded");

    expect(await token.balanceOf(payer.address)).to.equal(amount);
    expect(await escrow.status()).to.equal(5n);
  });

  it("allows arbiter to resolve a dispute", async function () {
    const { payer, payee, arbiter, treasury, factory } = await deployFixture();
    const now = (await ethers.provider.getBlock("latest"))!.timestamp;
    const amount = ethers.parseEther("2");
    const termsHash = ethers.keccak256(ethers.toUtf8Bytes("dispute terms v1"));

    const tx = await factory.createEscrowCustom(
      payer.address,
      payee.address,
      arbiter.address,
      ethers.ZeroAddress,
      treasury.address,
      amount,
      50,
      BigInt(now + 3600),
      BigInt(now + 7200),
      termsHash
    );

    const receipt = await tx.wait();
    const event = receipt!.logs.find((log) => {
      try {
        return factory.interface.parseLog(log as any)?.name === "EscrowCreated";
      } catch {
        return false;
      }
    });
    const parsed = factory.interface.parseLog(event as any)!;
    const escrowAddress = parsed.args.escrow as string;

    const escrow = (await ethers.getContractAt("Escrow", escrowAddress)) as Escrow;

    await escrow.connect(payer).depositNative({ value: amount });
    await escrow.connect(payee).raiseDispute("Goods not delivered");
    await expect(escrow.connect(arbiter).arbiterRefund()).to.emit(escrow, "Refunded");
    expect(await escrow.status()).to.equal(5n);
  });

  it("releases by timeout", async function () {
    const { payer, payee, arbiter, treasury, factory } = await deployFixture();
    const now = (await ethers.provider.getBlock("latest"))!.timestamp;
    const amount = ethers.parseEther("1");
    const termsHash = ethers.keccak256(ethers.toUtf8Bytes("timeout terms v1"));

    const tx = await factory.createEscrowCustom(
      payer.address,
      payee.address,
      arbiter.address,
      ethers.ZeroAddress,
      treasury.address,
      amount,
      0,
      BigInt(now + 10),
      BigInt(now + 20),
      termsHash
    );

    const receipt = await tx.wait();
    const event = receipt!.logs.find((log) => {
      try {
        return factory.interface.parseLog(log as any)?.name === "EscrowCreated";
      } catch {
        return false;
      }
    });
    const parsed = factory.interface.parseLog(event as any)!;
    const escrowAddress = parsed.args.escrow as string;

    const escrow = (await ethers.getContractAt("Escrow", escrowAddress)) as Escrow;
    await escrow.connect(payer).depositNative({ value: amount });

    await ethers.provider.send("evm_increaseTime", [11]);
    await ethers.provider.send("evm_mine", []);

    await expect(escrow.connect(payee).releaseByTimeout()).to.emit(escrow, "Released");
    expect(await escrow.status()).to.equal(4n);
  });
});
