const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VeriToken and ResumeVerification Integration", function () {
  let VeriToken, ResumeVerification, EmployerGovernance;
  let veriToken, resumeVerification, employerGovernance;
  let owner, employer, employee, employee2, employee3, others;

  beforeEach(async () => {
    [owner, employer, employee, employee2, employee3, ...others] = await ethers.getSigners();

    // Deploy VeriToken with the ERC20 instance injected
    VeriToken = await ethers.getContractFactory("VeriToken");
    veriToken = await VeriToken.deploy();
    await veriToken.waitForDeployment();
    // console.log("VeriToken deployed at: " + veriToken.target);

    // Mint some tokens for employee and employer
    await veriToken.connect(owner).mintVT({ value: ethers.parseEther("1") }); // 1000 VT
    await veriToken.connect(employer).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee2).mintVT({ value: ethers.parseEther("1") });
    await veriToken.connect(employee3).mintVT({ value: ethers.parseEther("1") });

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
    await veriToken.connect(employee).approveVT(employerGovernance.target, 1000);
    await veriToken.connect(employee2).approveVT(employerGovernance.target, 1000);
    await veriToken.connect(employee3).approveVT(employerGovernance.target, 1000);
    
    //Add Employer
    await employerGovernance.connect(employer).applyForVerification({ value: ethers.parseEther("1") });
    await veriToken.connect(employee).approveVT(resumeVerification, 1);
    await employerGovernance.connect(employee).voteOnEmployer(employer, true, 67);
    await veriToken.connect(employee2).approveVT(resumeVerification, 1);
    await employerGovernance.connect(employee2).voteOnEmployer(employer, false, 67);

    for (const index in others) {
      const voter = others[index];
      await veriToken.connect(voter).mintVT({ value: ethers.parseEther("1") });
      await veriToken.connect(voter).approveVT(employerGovernance.target, 1000);
      await veriToken.connect(voter).approveVT(resumeVerification, 1);
      await employerGovernance.connect(voter).voteOnEmployer(employer, true, 67);
      if (index == 12) {
        break;
      }
    }
  });

  it("should allow employee to create a resume after approving token", async () => {
    await veriToken.connect(employee).approveVT(resumeVerification.target, 1);
    await resumeVerification.connect(employee).createResume();

    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume.owner).to.equal(employee.address);
  });

  it("should allow sending a verification request", async () => {
    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Built X project", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    expect(requests.length).to.equal(1);
    expect(requests[0].content).to.equal("Built X project");
  });

  it("should allow employer to view verification request", async () => {
    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Worked at This", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    expect(requests.length).to.equal(1);
    expect(requests[0][3]).to.equal("Worked at This");
  });

  it("should allow employer to approve verification and add resume entry", async () => {

    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Worked at ABC", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    const requestId = requests[0].id;

    await veriToken.connect(employer).approveVT(resumeVerification.target, 1); 
    await resumeVerification.connect(employer).updateVerificationRequestStatus(requestId, 1);

    // Log the employee's resume to check the entries
    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume[1].length).to.equal(1);
    expect(resume[1][0][1]).to.equal("Worked at ABC");
  });

  it("anyone should be able to view resume", async () => {

    await veriToken.connect(employee).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employee).createResume();
    await resumeVerification.connect(employee).sendVerificationRequest("Did XYZ", employer.address);

    const requests = await resumeVerification.connect(employee).viewMyVerificationRequests();
    const requestId = requests[0].id;

    await veriToken.connect(employer).approveVT(resumeVerification.target, 2);
    await resumeVerification.connect(employer).updateVerificationRequestStatus(requestId, 1); // Verified

    // Employee viewing own resume 
    const resume = await resumeVerification.connect(employee).getMyResume();
    expect(resume[1].length).to.equal(1);
    expect(resume[1][0][1]).to.equal("Did XYZ");

    // Employer viewing employee's resume
    const employerResume = await resumeVerification.connect(employer).viewEmployeeResume(employee.address);
    expect(employerResume[1].length).to.equal(1);
    expect(employerResume[1][0][1]).to.equal("Did XYZ");

    //Anyone else viewing employee's resume
    const anyoneResume = await resumeVerification.connect(others[0]).viewEmployeeResume(employee.address);
    expect(anyoneResume[1].length).to.equal(1);
    expect(anyoneResume[1][0][1]).to.equal("Did XYZ");
  });
});
