// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VeriToken.sol";
import "./ResumeVerification.sol";

contract EmployerGovernance {
    VeriToken public veriToken;
    ResumeVerification public resumeContract;

    struct Employer {
        bool hasApplied;
        bool isVerified;
        uint256 totalStake;
        uint256 stakeFor;
        uint256 stakeAgainst;
        mapping(address => uint256) voterStakes;
        mapping(address => bool) votedFor;
        address[] voters; // Store addresses of actual voters
    }

    mapping(address => Employer) public employerApplications;
    address[] public appliedEmployers;
    mapping(address => bool) public verifiedEmployers;

    uint256 public constant APPLICATION_STAKE = 0.01 ether;
    uint256 public constant MINIMUM_STAKE = 100;
    uint256 public constant VOTE_THRESHOLD_PERCENTAGE = 20;
    uint256 public constant REWARD_PERCENTAGE = 5; // 5% bonus for correct voters

    event EmployerApplied(address indexed employer);
    event EmployerVoted(
        address indexed employer,
        address voter,
        bool approved,
        uint256 stake
    );
    event EmployerVerified(address indexed employer);
    event EmployerRejected(address indexed employer);
    event RewardPaid(address indexed voter, uint256 amount);

    constructor(address _veriTokenAddress, address _resumeContract) {
        veriToken = VeriToken(_veriTokenAddress);
        resumeContract = ResumeVerification(_resumeContract);
    }

    modifier onlyVoters() {
        require(verifiedEmployers[msg.sender] || resumeContract.isExist(msg.sender), "Not eligible to vote");
        _;
    }

    function isVerified(address employer) public view returns (bool) {
        return verifiedEmployers[employer];
    }

    function applyForVerification() public payable {
        require(!verifiedEmployers[msg.sender], "Already verified");
        require(
            !employerApplications[msg.sender].hasApplied,
            "Already applied"
        );
        require(
            msg.value == APPLICATION_STAKE,
            "0.01 eth required for application"
        );

        Employer storage newEmployer = employerApplications[msg.sender];
        appliedEmployers.push(msg.sender);
        newEmployer.isVerified = false;
        newEmployer.hasApplied = true;
        newEmployer.totalStake = 0;
        newEmployer.stakeFor = 0;
        newEmployer.stakeAgainst = 0;

        emit EmployerApplied(msg.sender);
    }

    function voteOnEmployer(
        address _employer,
        bool _approve,
        uint256 _stake
    ) public onlyVoters {
        require(
            !employerApplications[_employer].isVerified,
            "Employer already verified"
        );
        require(
            employerApplications[_employer].voterStakes[msg.sender] == 0,
            "Already voted for this employer"
        );
        require(_stake > 0, "Stake must be greater than 0");
        require(
            employerApplications[_employer].hasApplied,
            "Employer hasn't applied"
        );

        // Check allowance first
        uint256 allowance = veriToken.allowanceVT(msg.sender, address(this));
        require(allowance >= _stake, "Insufficient token allowance");

        // Check balance
        uint256 balance = veriToken.checkVTBalance(msg.sender);
        require(balance >= _stake, "Insufficient token balance");

        require(
            veriToken.transferVTFrom(msg.sender, address(this), _stake),
            "Token transfer failed"
        );

        // Record vote and stake
        employerApplications[_employer].totalStake += _stake;
        employerApplications[_employer].voterStakes[msg.sender] = _stake;
        employerApplications[_employer].votedFor[msg.sender] = _approve;
        employerApplications[_employer].voters.push(msg.sender);

        if (_approve) {
            employerApplications[_employer].stakeFor += _stake;
        } else {
            employerApplications[_employer].stakeAgainst += _stake;
        }

        emit EmployerVoted(_employer, msg.sender, _approve, _stake);

        // Check if decision can be made
        finalizeVote(_employer);
    }

    function finalizeVote(address _employer) internal {
        Employer storage employer = employerApplications[_employer];

        // Ensure minimum stake threshold is met
        if (employer.totalStake < MINIMUM_STAKE) {
            return;
        }

        // Calculate voting percentages
        uint256 totalStake = employer.totalStake;
        uint256 upvotePercentage = (employer.stakeFor * 100) / totalStake;
        uint256 downvotePercentage = (employer.stakeAgainst * 100) / totalStake;

        bool approved = false;
        if (
            upvotePercentage > downvotePercentage &&
            (upvotePercentage - downvotePercentage) >= VOTE_THRESHOLD_PERCENTAGE
        ) {
            employer.isVerified = true;
            verifiedEmployers[_employer] = true;
            resumeContract.addEmployer(_employer);
            approved = true;
            payable(_employer).transfer(APPLICATION_STAKE);
            emit EmployerVerified(_employer);
        } else if (
            downvotePercentage > upvotePercentage &&
            (downvotePercentage - upvotePercentage) >= VOTE_THRESHOLD_PERCENTAGE
        ) {
            emit EmployerRejected(_employer);
        } else {
            return;
        }

        distributeRewards(_employer, approved);
    }

    function distributeRewards(address _employer, bool approved) internal {
        Employer storage employer = employerApplications[_employer];

        for (uint256 i = 0; i < employer.voters.length; i++) {
            address voter = employer.voters[i];
            uint256 stake = employer.voterStakes[voter];

            if (stake > 0) {
                if (employer.votedFor[voter] == approved) {
                    uint256 reward = (stake * REWARD_PERCENTAGE) / 100;
                    veriToken.transferVTFrom(address(this), voter, stake + reward);
                }
                employer.voterStakes[voter] = 0;
            }
        }
    }

    function getRandomUnverifiedEmployer() public view returns (address) {
        uint256 count = 0;

        // First pass: count valid candidates
        for (uint256 i = 0; i < appliedEmployers.length; i++) {
            address employerAddr = appliedEmployers[i];
            Employer storage employer = employerApplications[employerAddr];

            if (
                employer.hasApplied &&
                !employer.isVerified &&
                employer.voterStakes[msg.sender] == 0
            ) {
                count++;
            }
        }

        require(count > 0, "No unvoted unverified employers");

        // Second pass: choose a random one
        uint256 randIndex = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % count;

        count = 0;
        for (uint256 i = 0; i < appliedEmployers.length; i++) {
            address employerAddr = appliedEmployers[i];
            Employer storage employer = employerApplications[employerAddr];

            if (
                employer.hasApplied &&
                !employer.isVerified &&
                employer.voterStakes[msg.sender] == 0
            ) {
                if (count == randIndex) {
                    return employerAddr;
                }
                count++;
            }
        }

        // Should never reach here
        revert("Random selection failed");
    }
}
