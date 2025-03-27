// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal ERC20 interface for the VERI token.
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title ResumeVerification Smart Contract
/// @notice This contract allows employees to create their resume on-chain,
/// submit verification requests (with a fee), and have those requests updated based on a decentralized voting process.
/// Employers can view pending requests and also pay to view individual employee resumes.
contract ResumeVerification {
    IERC20 public veriToken;
    address public employer;
    address public governance;

    uint256 public verificationRequestCount;

    // Enumeration for the state of verification requests/resume entries.
    enum Status { Pending, Verified, Rejected }

    // A resume entry representing a job experience, project, or certification.
    struct ResumeEntry {
        uint256 id;
        string content;
        Status status;
    }

    // A resume associated with an employee.
    struct Resume {
        address owner;
        ResumeEntry[] entries;
        bool exists;
    }

    // A verification request to add a new resume statement.
    struct VerificationRequest {
        uint256 id;
        address employee;
        address employer; // The employer that will review this request.
        string content;
        Status status;
    }

    // Mapping of employee address to their resume.
    mapping(address => Resume) public resumes;
    // Mapping of verification request ID to the request details.
    mapping(uint256 => VerificationRequest) public verificationRequests;

    // Modifiers to restrict function access.
    modifier onlyEmployer() {
        require(msg.sender == employer, "Only employer can call this function.");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance can call this function.");
        _;
    }

    // In this simple model, anyone who is not the employer or governance is considered an employee.
    modifier onlyEmployee() {
        require(msg.sender != employer && msg.sender != governance, "Employer or governance cannot call this function.");
        _;
    }

    /// @notice Contract constructor
    /// @param _veriToken Address of the VERI token contract.
    /// @param _employer Address that represents the employer.
    /// @param _governance Address of the governance contract that will update request statuses.
    constructor(address _veriToken, address _employer, address _governance) {
        veriToken = IERC20(_veriToken);
        employer = _employer;
        governance = _governance;
    }

    /// @notice Create a resume for the caller (employee).
    /// @dev Requires the caller to pay 1 VERI token.
    function createResume() external onlyEmployee {
        require(!resumes[msg.sender].exists, "Resume already exists.");
        // Charge 1 VERI token from the employee.
        require(veriToken.transferFrom(msg.sender, address(this), 1), "Token transfer failed.");
        
        Resume storage newResume = resumes[msg.sender];
        newResume.owner = msg.sender;
        newResume.exists = true;
    }

    /// @notice Send a verification request to add a resume entry.
    /// @param content The resume statement details (job experience, project, etc.).
    /// @dev Employee must already have a resume and pay 1 VERI token fee.
    function sendVerificationRequest(string memory content) external onlyEmployee {
        require(resumes[msg.sender].exists, "You must create a resume first.");
        // Charge 1 VERI token from the employee.
        require(veriToken.transferFrom(msg.sender, address(this), 1), "Token transfer failed.");

        verificationRequestCount++;
        verificationRequests[verificationRequestCount] = VerificationRequest({
            id: verificationRequestCount,
            employee: msg.sender,
            employer: employer, // Here we assume the request goes to the designated employer.
            content: content,
            status: Status.Pending
        });
    }

    /// @notice Allows the employer to view all verification requests.
    /// @return An array of all verification requests.
    function viewAllVerificationRequests() external view onlyEmployer returns (VerificationRequest[] memory) {
        VerificationRequest[] memory requests = new VerificationRequest[](verificationRequestCount);
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            requests[i - 1] = verificationRequests[i];
        }
        return requests;
    }

    /// @notice Allows an employee or the employer to view verification requests associated with them.
    /// @return An array of verification requests relevant to the caller.
    function viewMyVerificationRequests() external view returns (VerificationRequest[] memory) {
        uint256 count = 0;
        // Count requests where the caller is either the employee who initiated or the employer.
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            if (verificationRequests[i].employee == msg.sender || verificationRequests[i].employer == msg.sender) {
                count++;
            }
        }
        VerificationRequest[] memory result = new VerificationRequest[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            if (verificationRequests[i].employee == msg.sender || verificationRequests[i].employer == msg.sender) {
                result[index] = verificationRequests[i];
                index++;
            }
        }
        return result;
    }

    /// @notice Update the status of a verification request after the voting process.
    /// @param requestId The ID of the verification request.
    /// @param newStatus The new status (Verified or Rejected).
    /// @dev Only callable by the governance contract.
    function updateVerificationRequestStatus(uint256 requestId, Status newStatus) external onlyGovernance {
        require(requestId > 0 && requestId <= verificationRequestCount, "Invalid request id.");
        verificationRequests[requestId].status = newStatus;

        // If the request is verified, add the entry to the employee's resume and refund the token.
        if (newStatus == Status.Verified) {
            Resume storage userResume = resumes[verificationRequests[requestId].employee];
            uint256 entryId = userResume.entries.length + 1;
            userResume.entries.push(ResumeEntry({
                id: entryId,
                content: verificationRequests[requestId].content,
                status: Status.Verified
            }));
            // Refund 1 VERI token to the employee.
            require(veriToken.transfer(verificationRequests[requestId].employee, 1), "Refund failed.");
        }
    }

    /// @notice Retrieve the caller's resume.
    /// @return The resume structure associated with the caller.
    function getMyResume() external view onlyEmployee returns (Resume memory) {
        require(resumes[msg.sender].exists, "Resume does not exist.");
        return resumes[msg.sender];
    }

    /// @notice Allow the employer to view an employee's resume.
    /// @param employeeAddr The address of the employee whose resume is being viewed.
    /// @return The resume structure of the specified employee.
    /// @dev The employer must pay 1 VERI token fee.
    function viewEmployeeResume(address employeeAddr) external onlyEmployer returns (Resume memory) {
        require(resumes[employeeAddr].exists, "Employee resume does not exist.");
        // Charge fee of 1 VERI token from the employer.
        require(veriToken.transferFrom(msg.sender, address(this), 1), "Token transfer failed.");
        return resumes[employeeAddr];
    }
}
