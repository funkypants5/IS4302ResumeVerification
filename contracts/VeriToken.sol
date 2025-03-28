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
        uint256 amt = msg.value / 10000000000000000; // Get VTs eligible, 1 VT = 0.01 ETH
        // erc20Contract.transferFrom(owner, msg.sender, amt);
        erc20Contract.mint(msg.sender, amt);
        
    }

    function checkVTBalance() public returns(uint256) {
        uint256 credit = erc20Contract.balanceOf(msg.sender);
        emit creditChecked(credit);
        return credit;
    }

    function transferVT(address receipt, uint256 amt) public {
        erc20Contract.transfer(receipt, amt);
    }

    function transferVTFrom(address from, address to, uint256 amt) public {
        erc20Contract.transferFrom(from, to, amt);
    }

    function changeToETH(uint256 amt) public {
        erc20Contract.burn(msg.sender, amt);
        payable(msg.sender).transfer(amt * 10000000000000000);
    }

}