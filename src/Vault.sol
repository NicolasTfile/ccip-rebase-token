// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract Vault {
    // We need to pass the token address to the constructor
    // Create a deposit function that mints tokens to the user = the amount of ETH they deposited
    // Create a redeem function that burns tokens from the user and sends the user ETH
    // Create a way to add rewards to the vault

    address private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);

    constructor(address _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        // We need to use the amount of ETH the user has sent to mint the same amount of tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return i_rebaseToken;
    }
}
