// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ResumeVerification {
    struct Endorsement {
        address endorser;
        string message;
        uint256 timestamp;
    }

    struct Resume {
        string personalInfo;
        string experience;
        string education;
        mapping(address => Endorsement) endorsements;
    }

    mapping(address => Resume) public userResumes;

    function createResume(
        string memory _personalInfo,
        string memory _experience,
        string memory _education
    ) public {
        require(
            bytes(userResumes[msg.sender].personalInfo).length == 0,
            "Resume already exists"
        );
        userResumes[msg.sender].personalInfo = _personalInfo;
        userResumes[msg.sender].experience = _experience;
        userResumes[msg.sender].education = _education;
    }

    function addEndorsement(address _user, string memory _message) public {
        require(
            bytes(userResumes[_user].personalInfo).length > 0,
            "Resume does not exist"
        );
        userResumes[_user].endorsements[msg.sender] = Endorsement(
            msg.sender,
            _message,
            block.timestamp
        );
    }

    function getResume(
        address _user
    )
        public
        view
        returns (
            string memory personalInfo,
            string memory experience,
            string memory education
        )
    {
        require(
            bytes(userResumes[_user].personalInfo).length > 0,
            "Resume does not exist"
        );
        Resume storage resume = userResumes[_user];
        return (resume.personalInfo, resume.experience, resume.education);
    }

    function getEndorsements(
        address _user
    ) public view returns (Endorsement[] memory) {
        require(
            bytes(userResumes[_user].personalInfo).length > 0,
            "Resume does not exist"
        );
        uint256 count = 0;
        for (uint256 i = 0; i < 2 ** 160; i++) {
            address endorser = address(uint160(i));
            if (userResumes[_user].endorsements[endorser].timestamp != 0) {
                count++;
            }
        }
        Endorsement[] memory result = new Endorsement[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < 2 ** 160; i++) {
            address endorser = address(uint160(i));
            if (userResumes[_user].endorsements[endorser].timestamp != 0) {
                result[index] = userResumes[_user].endorsements[endorser];
                index++;
            }
        }
        return result;
    }
}
