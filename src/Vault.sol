// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract Vault {
    // We need to pass the token address to the constructor
    // Create a deposit function that mints tokens to the user = the amount of ETH they deposited
    // Create a redeem function that burns tokens from the user and sends the user ETH
    // Create a way to add rewards to the vault

    address private immutable i_rebaseToken;

    constructor(address _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        //
    }

    function getRebaseTokenAddress() external view returns (address) {
        return i_rebaseToken;
    }
}
