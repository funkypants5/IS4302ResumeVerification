// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract VeriToken {
    ERC20 public erc20Contract;
    address public owner;

    constructor() {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
    }

    event creditChecked(uint256 credit);

    function mintVT() public payable {
        uint256 amt = msg.value / 1000000000000000; // Get VTs eligible, 1 VT = 0.001 ETH
        erc20Contract.mint(msg.sender, amt);
    }

    function checkVTBalance() public returns (uint256) {
        uint256 credit = erc20Contract.balanceOf(msg.sender);
        emit creditChecked(credit);
        return credit;
    }

    function checkVTBalance(address _owner) public returns (uint256) {
        uint256 credit = erc20Contract.balanceOf(_owner);
        emit creditChecked(credit);
        return credit;
    }

    function approveVT(address spender, uint256 amount) public returns (bool) {
        return erc20Contract.approve(msg.sender, spender, amount);
    }

    // You might also want to add a function to check allowances
    function allowanceVT(address _owner, address spender)
        public
        view
        returns (uint256)
    {
        return erc20Contract.allowance(_owner, spender);
    }

    function transferVT(address receipt, uint256 amt) public {
        erc20Contract.transferFrom(msg.sender, receipt, amt);
    }

    function transferVTFrom(
        address from,
        address to,
        uint256 amt
    ) public returns (bool) {
<<<<<<< HEAD
        erc20Contract.transferFrom(from, to, amt);
        return true; // or check the return value of transferFrom if it has one
=======
        erc20Contract.transferFromWithSpender(msg.sender, from, to, amt);
        return true;
>>>>>>> be36f45ac8704e7f6ffe853548b28313b7aaacd0
    }

    function changeToETH(uint256 amt) public {
        erc20Contract.burn(msg.sender, amt);
        payable(msg.sender).transfer(amt * 10000000000000000);
    }
}