// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VeriToken.sol";

contract ResumeVerification {
    VeriToken public veriToken;
    address[] public employers;
    address[] public employees;
    uint256 public verificationRequestCount;

    enum Status {
        Pending,
        Verified,
        Rejected
    }

    event EmployerAdded(address indexed newEmployer, address indexed addedBy);
    event EmployeeAdded(address indexed newEmployee);
    event ResumeCreated(address indexed employee);
    event ResumeEntryVerified(
        address indexed employee,
        uint256 indexed entryId,
        address indexed employer
    );
    event ResumeViewed(address indexed employee, address indexed employer);

    struct ResumeEntry {
        uint256 id;
        string content;
        Status status;
        uint256 requestId; // 🔗 Reference to the original verification request
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

    mapping(address => Resume) public resumes;
    mapping(uint256 => VerificationRequest) public verificationRequests;

    modifier onlyEmployer() {
        bool isEmployer = false;
        for (uint256 i = 0; i < employers.length; i++) {
            if (msg.sender == employers[i]) {
                isEmployer = true;
                break;
            }
        }
        require(
            isEmployer,
            "Only registered employers can call this function."
        );
        _;
    }

    modifier onlyEmployee() {
        bool isEmployee = false;
        for (uint256 i = 0; i < employees.length; i++) {
            if (msg.sender == employees[i]) {
                isEmployee = true;
                break;
            }
        }
        require(
            isEmployee,
            "Only registered employees can call this function."
        );
        _;
    }

    constructor(address _veriToken) {
        veriToken = VeriToken(_veriToken);
    }

    function isExist(address employee) external view returns (bool) {
        return resumes[employee].exists;
    }

    function addEmployer(address _newEmployer) external {
        employers.push(_newEmployer);
        emit EmployerAdded(_newEmployer, msg.sender);
    }

    function createResume() external {
        require(!resumes[msg.sender].exists, "Resume already exists.");
        require(
            veriToken.transferVTFrom(msg.sender, address(this), 1),
            "Token transfer failed."
        );

        employees.push(msg.sender);
        Resume storage newResume = resumes[msg.sender];
        newResume.owner = msg.sender;
        newResume.exists = true;

        emit EmployeeAdded(msg.sender);
        emit ResumeCreated(msg.sender);
    }

    function sendVerificationRequest(
        string memory content,
        address employer
    ) external onlyEmployee {
        require(resumes[msg.sender].exists, "You must create a resume first.");
        require(
            veriToken.transferVTFrom(msg.sender, address(this), 1),
            "Token transfer failed."
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

        req.status = newStatus;

        if (newStatus == Status.Verified) {
            require(
                veriToken.transferVTFrom(msg.sender, req.employee, 1),
                "Refund failed."
            );

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

    function getMyResume() external view onlyEmployee returns (Resume memory) {
        require(resumes[msg.sender].exists, "Resume does not exist.");
        return resumes[msg.sender];
    }

    function viewEmployeeResume(
        address employeeAddr
    ) external onlyEmployer returns (Resume memory) {
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

    function getResumeItems(
        address _employee,
        address _employer
    ) external view returns (ResumeEntry[] memory) {
        require(resumes[_employee].exists, "Employee resume does not exist.");
        Resume storage userResume = resumes[_employee];

        // Count matching entries
        uint256 count = 0;
        for (uint256 i = 0; i < userResume.entries.length; i++) {
            uint256 reqId = userResume.entries[i].requestId;
            if (
                reqId > 0 && verificationRequests[reqId].employer == _employer
            ) {
                count++;
            }
        }

        // Populate result array
        ResumeEntry[] memory matchedEntries = new ResumeEntry[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < userResume.entries.length; i++) {
            uint256 reqId = userResume.entries[i].requestId;
            if (
                reqId > 0 && verificationRequests[reqId].employer == _employer
            ) {
                matchedEntries[index++] = userResume.entries[i];
            }
        }

        return matchedEntries;
    }
}
