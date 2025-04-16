const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Employee Governance", function () {
  let VeriToken, ResumeVerification, EmployerGovernance;
  let veriToken, resumeVerification, employerGovernance;
  let owner, employer, employee, employee2, employee3, other;

  beforeEach(async () => {
    [owner, employer, employee, employee2, employee3, other, ...others] = await ethers.getSigners();

    // Deploy VeriToken with the ERC20 instance injected
    VeriToken = await ethers.getContractFactory("VeriToken");
    veriToken = await VeriToken.deploy();
    await veriToken.waitForDeployment();
    console.log("VeriToken deployed at: " + veriToken.target);

    // Mint some tokens for employee and employer
    await veriToken.connect(owner).mintVT({ value: ethers.parseEther("1") }); // 100 VT
    await veriToken.connect(employer).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee2).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee3).mintVT({ value: ethers.parseEther("1") });

    // Deploy ResumeVerification with the address of VeriToken
    ResumeVerification = await ethers.getContractFactory("ResumeVerification");
    resumeVerification = await ResumeVerification.deploy(veriToken.target);
    await resumeVerification.waitForDeployment();
    console.log("ResumeVerification deployed at: " + resumeVerification.target);

    // Deploy EmployerGovernance with the address of VeriToken
    EmployerGovernance = await ethers.getContractFactory("EmployerGovernance");
    employerGovernance = await EmployerGovernance.deploy(veriToken.target, resumeVerification.target);
    await employerGovernance.waitForDeployment();
    console.log("EmployerGovernance deployed at: " + employerGovernance.target);

    // Allow VT token to be transferred
    await veriToken.connect(employee).approveVT(employerGovernance.target, 90);
    await veriToken.connect(employee2).approveVT(employerGovernance.target, 90);
    await veriToken.connect(employee3).approveVT(employerGovernance.target, 90);
  });

  it("employer can apply for verification", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    expect(await employerGovernance.connect(other).isVerified(employer)).to.be.false;
  });

  it("voters can get a random unverified employer", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();
    expect(randomEmployer).to.be.equal(employer);
  });

  it("voters can vote", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();

    await resumeVerification.connect(employee).createResume();
    await employerGovernance.connect(employee).voteOnEmployer(randomEmployer, true, 30);

    const employerData = await employerGovernance.connect(other).employerApplications(randomEmployer);
    expect(employerData[3]).to.be.equal(30);
  });

  it("vote get passed and employer gets verified", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();

    await resumeVerification.connect(employee).createResume();
    await employerGovernance.connect(employee).voteOnEmployer(randomEmployer, true, 30);

    await resumeVerification.connect(employee2).createResume();
    await employerGovernance.connect(employee2).voteOnEmployer(randomEmployer, true, 30);

    await resumeVerification.connect(employee3).createResume();
    await employerGovernance.connect(employee3).voteOnEmployer(randomEmployer, false, 40);

    expect(await employerGovernance.connect(other).isVerified(randomEmployer)).to.be.true;
  });

  it("vote doesnt get passed and employer doesnt get verified", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();

    await resumeVerification.connect(employee).createResume();
    await employerGovernance.connect(employee).voteOnEmployer(randomEmployer, true, 30);

    await resumeVerification.connect(employee2).createResume();
    await employerGovernance.connect(employee2).voteOnEmployer(randomEmployer, false, 30);

    await resumeVerification.connect(employee3).createResume();
    await employerGovernance.connect(employee3).voteOnEmployer(randomEmployer, false, 40);

    expect(await employerGovernance.connect(other).isVerified(randomEmployer)).to.be.false;
  });

  it("voter in favour of vote received 5% interest", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();

    await resumeVerification.connect(employee).createResume();
    const initialBalance = await veriToken.connect(employee).checkVTBalance();
    await employerGovernance.connect(employee).voteOnEmployer(randomEmployer, true, 20);

    await resumeVerification.connect(employee2).createResume();
    await employerGovernance.connect(employee2).voteOnEmployer(randomEmployer, true, 40);

    await resumeVerification.connect(employee3).createResume();
    await employerGovernance.connect(employee3).voteOnEmployer(randomEmployer, false, 40);

    console.log("Initial balance type:", typeof initialBalance);
    console.log("Initial balance:", initialBalance);
    const expectedBalance = initialBalance + 1n;

    const finalBalance = await veriToken.connect(employee).checkVTBalance();

    expect(finalBalance).to.equal(expectedBalance);
  });

  it("voter not in favour of vote lost its stake", async () => {
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("0.01") });
    const randomEmployer = await employerGovernance.connect(employee).getRandomUnverifiedEmployer();

    await resumeVerification.connect(employee).createResume();
    await employerGovernance.connect(employee).voteOnEmployer(randomEmployer, true, 20);

    await resumeVerification.connect(employee2).createResume();
    await employerGovernance.connect(employee2).voteOnEmployer(randomEmployer, true, 40);

    await resumeVerification.connect(employee3).createResume();
    const initialBalance = await veriToken.connect(employee3).checkVTBalance();
    await employerGovernance.connect(employee3).voteOnEmployer(randomEmployer, false, 40);

    console.log("Initial balance type:", typeof initialBalance);
    console.log("Initial balance:", initialBalance);
    const expectedBalance = initialBalance - 40n;

    const finalBalance = await veriToken.connect(employee3).checkVTBalance();

    expect(finalBalance).to.equal(expectedBalance);
  });
});
