const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VeriToken and ResumeVerification Integration", function () {
  let VeriToken, ResumeVerification, EmployerGovernance;
  let veriToken, resumeVerification, employerGovernance;
  let owner, employer, employee, others;

  beforeEach(async () => {
    [owner, employer, employee, ...others] = await ethers.getSigners();

    // Deploy VeriToken with the ERC20 instance injected
    VeriToken = await ethers.getContractFactory("VeriToken");
    veriToken = await VeriToken.deploy();
    await veriToken.waitForDeployment();
    // console.log("VeriToken deployed at: " + veriToken.target);

    // Mint some tokens for employee and employer
    await veriToken.connect(owner).mintVT({ value: ethers.parseEther("1") }); // 1000 VT
    await veriToken.connect(employer).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee).mintVT({ value: ethers.parseEther("1") });

    // Deploy EmployerGovernance
    EmployerGovernance = await ethers.getContractFactory("EmployerGovernance");
    employerGovernance = await EmployerGovernance.deploy(veriToken.target);
    await employerGovernance.waitForDeployment();
    // console.log("EmployerGovernance deployed at: " + employerGovernance.target);

    // Deploy ResumeVerification with the address of VeriToken
    ResumeVerification = await ethers.getContractFactory("ResumeVerification");
    resumeVerification = await ResumeVerification.deploy(veriToken.target, employerGovernance.target);
    await resumeVerification.waitForDeployment();
    // console.log("ResumeVerification deployed at: " + resumeVerification.target);
  });

  it("should allow employer registration", async () => {
    await employerGovernance.connect(employer).applyForVerification();
    await resumeVerification.connect(employee).createResume();
    await employerGovernance.connect(employee).voteOnEmployer(employer, true, 67);

    for (const index in others) {
      const voter = others[index];
      await veriToken.connect(voter).mintVT({ value: ethers.parseEther("1") });
      await veriToken.connect(voter).approveVT(employerGovernance.target, 1000);
      await resumeVerification.connect(voter).createResume();
      await employerGovernance.connect(voter).voteOnEmployer(employer, true, 67);
      if (index == 13) {
        break;
      }
    }
    // No return value, so we'll assume success if no revert
  });

  it("should allow employee to create a resume after approving token", async () => {
    await resumeVerification.connect(owner).addEmployer(employer.address);

    await veriToken.connect(employee).approveVT(resumeVerification.target, 1);
    await resumeVerification.connect(employee).createResume();

    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume.owner).to.equal(employee.address);
  });

  it("should allow sending a verification request", async () => {
    await resumeVerification.connect(owner).addEmployer(employer.address);

    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Built X project", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    expect(requests.length).to.equal(1);
    expect(requests[0].content).to.equal("Built X project");
  });

  it("should allow employer to approve verification and add resume entry", async () => {
    await resumeVerification.connect(owner).addEmployer(employer.address);

    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Worked at ABC", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    const requestId = requests[0].id;

    await veriToken.connect(employer).approveVT(resumeVerification.target, 1); // for refund
    await resumeVerification.connect(employer).updateVerificationRequestStatus(requestId, 1);

    // Log the employee's resume to check the entries
    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume[1].length).to.equal(1);
    expect(resume[1][0][1]).to.equal("Worked at ABC");
  });

  it("should let employer view employee resume by paying", async () => {
    await resumeVerification.connect(owner).addEmployer(employer.address);

    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Did XYZ", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    const requestId = requests[0].id;

    await veriToken.connect(employer).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employer).updateVerificationRequestStatus(requestId, 1); // Verified

    // Log the employee's resume to check the entries
    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume[1].length).to.equal(1);
    expect(resume[1][0][1]).to.equal("Did XYZ");
  });
});
