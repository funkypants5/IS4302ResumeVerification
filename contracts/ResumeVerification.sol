// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VeriToken.sol";

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
    VeriToken public veriToken;
    address[] public employers;
    address[] public employees;
    uint256 public verificationRequestCount;

    // Enumeration for the state of verification requests/resume entries.
    enum Status { Pending, Verified, Rejected }
    
    // Emitted when a new employer is added to the system
    event EmployerAdded(address indexed newEmployer, address indexed addedBy);

    // Emitted when a new employee is added to the system
    event EmployeeAdded(address indexed newEmployee);

    // Emitted when a resume is created
    event ResumeCreated(address indexed employee);

    // Emitted when a resume entry is verified and added
    event ResumeEntryVerified(
    address indexed employee, 
    uint256 indexed entryId, 
    address indexed employer
    );

    // Emitted when an employee resume is viewed by an employer
    event ResumeViewed(
        address indexed employee, 
        address indexed employer
    );


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
    bool isEmployer = false;
    for (uint i = 0; i < employers.length; i++) {
        if (msg.sender == employers[i]) {
            isEmployer = true;
            break;
        }
    }
    require(isEmployer, "Only registered employers can call this function.");
    _;
}

modifier onlyEmployee() {
    bool isEmployee = false;
    for (uint i = 0; i < employees.length; i++) {
        if (msg.sender == employees[i]) {
            isEmployee = true;
            break;
        }
    }
    require(isEmployee, "Only registered employees can call this function.");
    _;
}

    /// @notice Contract constructor
    /// @param _veriToken Address of the VERI token contract.
    constructor(address _veriToken) {
        veriToken = VeriToken(_veriToken);
    }

    function addEmployer(address _newEmployer) external {
    // To add only EmployerGovernance can call this
    employers.push(_newEmployer);
    emit EmployerAdded(_newEmployer, msg.sender);
    }

    /// @notice Create a resume for the caller (employee).
    /// @dev Requires the caller to pay 1 VERI token.
    function createResume() external {
        require(!resumes[msg.sender].exists, "Resume already exists.");
        // Charge 1 VERI token from the employee.
        require(veriToken.erc20Contract().transferFrom(msg.sender, address(this), 1), "Token transfer failed.");
        employees.push(msg.sender);
        
        Resume storage newResume = resumes[msg.sender];
        newResume.owner = msg.sender;
        newResume.exists = true;
        emit EmployeeAdded(msg.sender);
        emit ResumeCreated(msg.sender);
    }

    /// @notice Send a verification request to add a resume entry.
    /// @param content The resume statement details (job experience, project, etc.).
    /// @dev Employee must already have a resume and pay 1 VERI token fee.
    function sendVerificationRequest(string memory content, address employer) external onlyEmployee {
        require(resumes[msg.sender].exists, "You must create a resume first.");
        // Charge 1 VERI token from the employee.
        require(veriToken.erc20Contract().transferFrom(msg.sender, address(this), 1), "Token transfer failed.");

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
   function updateVerificationRequestStatus(uint256 requestId, Status newStatus) external onlyEmployer {
    // Ensure the request exists and the caller is the specific employer for this request
    require(requestId > 0 && requestId <= verificationRequestCount, "Invalid request id.");
    require(msg.sender == verificationRequests[requestId].employer, "Not authorized for this verification request");

    // Update the verification request status
    verificationRequests[requestId].status = newStatus;

    // If the request is verified, add the entry to the employee's resume and refund the token
    if (newStatus == Status.Verified) {
        // Refund 1 VERI token to the employee
        require(veriToken.transferVTFrom(msg.sender, verificationRequests[requestId].employee, 1), "Refund failed.");
        Resume storage userResume = resumes[verificationRequests[requestId].employee];
        uint256 entryId = userResume.entries.length + 1;
        
        // Create resume entry with the verified content
        ResumeEntry memory newEntry = ResumeEntry({
            id: entryId,
            content: verificationRequests[requestId].content,
            status: Status.Verified
        });
        
        // Add the entry to the resume
        userResume.entries.push(newEntry);
        
        emit ResumeEntryVerified (
            verificationRequests[requestId].employee, 
            verificationRequests[requestId].id, 
            msg.sender
        );
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
        require(veriToken.transferVTFrom(msg.sender, address(this), 1), "Token transfer failed.");
        emit ResumeViewed(employeeAddr, msg.sender);
        return resumes[employeeAddr];
    }

    function getResumeItem(address _employee, address _employer) external view returns (ResumeEntry memory) {
    require(resumes[_employee].exists, "Employee resume does not exist.");

    // Find the resume item associated with the specific employer
    for (uint i = 0; i < resumes[_employee].entries.length; i++) {
        if (verificationRequests[resumes[_employee].entries[i].id].employer == _employer) {
            return resumes[_employee].entries[i];
        }
    }
    
    revert("No resume item found for this employee and employer");
}
}
