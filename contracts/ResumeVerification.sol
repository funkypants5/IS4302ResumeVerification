// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VeriToken.sol";
import "./EmployerGovernance.sol";

contract ResumeVerification {
    // Structures ----------------------------------- //
    struct ResumeEntry {
        uint256 id;
        string content;
        Status status;
        uint256 requestId; // Reference to the original verification request
    }
    struct Resume {
        address owner;
        ResumeEntry[] entries;
        bool exists;
    }
    struct VerificationRequest {
        uint256 id;
        address employee;
        address employer;
        string content;
        Status status;
    }
    enum Status {
        Pending,
        Verified,
        Rejected
    }

    // Contract's Variables + Constructor -----------//
    VeriToken public veriToken;
    EmployerGovernance public employerGovernance;
    uint256 public verificationRequestCount;
    mapping(address => Resume) public resumes;
    mapping(uint256 => VerificationRequest) public verificationRequests;

    constructor(address _veriToken, address _employerGovernance) {
        veriToken = VeriToken(_veriToken);
        employerGovernance = EmployerGovernance(_employerGovernance);
    }

    // Events ---------------------------------------//
    event ResumeCreated(address indexed employee);
    event ResumeEntryVerified(
        address indexed employee,
        uint256 indexed entryId,
        address indexed employer
    );
    event ResumeViewed(address indexed employee, address indexed employer);

    // Modifiers ------------------------------------//
    modifier onlyEmployer() {
        require(
            employerGovernance.isVerified(msg.sender),
            "Only verified employers can call this function."
        );
        _;
    }
    modifier onlyEmployee() {
        require(
            resumes[msg.sender].exists,
            "Only employees with a resume with us can call this function."
        );
        _;
    }

    // Methods ---------------------------------------//
    // Main Business Processes =======================//
    function createResume() external {
        require(!resumes[msg.sender].exists, "Resume already exists.");
        require(
            veriToken.transferVTFrom(msg.sender, address(this), 1),
            "VeriToken transfer of 1 unit failed."
        );

        Resume storage newResume = resumes[msg.sender];
        newResume.owner = msg.sender;
        newResume.exists = true;

        emit ResumeCreated(msg.sender);
    }

    function sendVerificationRequest(
        string memory content,
        address employer
    ) external onlyEmployee {
        require(
            veriToken.transferVTFrom(
                msg.sender,
                address(employerGovernance),
                1
            ),
            "VeriToken transfer of 1 unit failed."
        );

        verificationRequestCount++;
        verificationRequests[verificationRequestCount] = VerificationRequest({
            id: verificationRequestCount,
            employee: msg.sender,
            employer: employer,
            content: content,
            status: Status.Pending
        });
    }

    function updateVerificationRequestStatus(
        uint256 requestId,
        Status newStatus
    ) external onlyEmployer {
        require(
            requestId > 0 && requestId <= verificationRequestCount,
            "Invalid request id."
        );
        VerificationRequest storage req = verificationRequests[requestId];
        require(
            msg.sender == req.employer,
            "Not authorized for this verification request"
        );
        require(
            veriToken.transferVTFrom(
                msg.sender,
                address(employerGovernance),
                1
            ),
            "VeriToken transfer of 1 unit failed."
        );

        req.status = newStatus;

        if (newStatus == Status.Verified) {
            Resume storage userResume = resumes[req.employee];
            uint256 entryId = userResume.entries.length + 1;

            ResumeEntry memory newEntry = ResumeEntry({
                id: entryId,
                content: req.content,
                status: Status.Verified,
                requestId: requestId
            });

            userResume.entries.push(newEntry);

            emit ResumeEntryVerified(req.employee, requestId, msg.sender);
        }
    }

    // Viewing Methods ===============================//
    function isExist(address employee) external view returns (bool) {
        return resumes[employee].exists;
    }

    function viewMyVerificationRequests()
        external
        view
        returns (VerificationRequest[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            if (
                verificationRequests[i].employee == msg.sender ||
                verificationRequests[i].employer == msg.sender
            ) {
                count++;
            }
        }

        VerificationRequest[] memory result = new VerificationRequest[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            if (
                verificationRequests[i].employee == msg.sender ||
                verificationRequests[i].employer == msg.sender
            ) {
                result[index++] = verificationRequests[i];
            }
        }
        return result;
    }

    function viewAllVerificationRequests()
        external
        view
        onlyEmployer
        returns (VerificationRequest[] memory)
    {
        VerificationRequest[] memory requests = new VerificationRequest[](
            verificationRequestCount
        );
        for (uint256 i = 1; i <= verificationRequestCount; i++) {
            requests[i - 1] = verificationRequests[i];
        }
        return requests;
    }

    function getMyResume() external view onlyEmployee returns (Resume memory) {
        require(resumes[msg.sender].exists, "Resume does not exist.");
        return resumes[msg.sender];
    }

    function viewEmployeeResume(
        address employeeAddr
    ) external returns (Resume memory) {
        require(
            resumes[employeeAddr].exists,
            "Employee resume does not exist."
        );
        require(
            veriToken.transferVTFrom(msg.sender, address(this), 1),
            "Token transfer failed."
        );

        emit ResumeViewed(employeeAddr, msg.sender);
        return resumes[employeeAddr];
    }
}
