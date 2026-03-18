// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /**
     * @notice Fallback function to receive ETH sent directly to the contract. This allows the contract to accept ETH deposits even if the user does not call the deposit function explicitly. The received ETH can then be used for minting rebase tokens when users call the deposit function.
     * @dev The receive function is a special function in Solidity that is executed when the contract receives plain Ether (without any data). It is marked as external and payable, allowing it to accept Ether transfers. This function does not have any logic and simply allows the contract to receive Ether.
     */
    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint the equivalent amount of rebase tokens to their address. The amount of rebase tokens minted is equal to the amount of ETH deposited.
     * @dev The function is payable, allowing users to send ETH along with the transaction. It calls the mint function of the rebase token contract to mint the appropriate amount of tokens to the user's address. An event is emitted to log the deposit action.
     */
    function deposit() external payable {
        // We need to use the amount of ETH the user has sent to mint the same amount of tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase tokens for ETH. The function burns the specified amount of rebase tokens from the user's address and sends the equivalent amount of ETH back to the user. If the transfer of ETH fails, the transaction is reverted.
     * @param _amount The amount of rebase tokens the user wants to redeem for ETH.
     * @dev The function first calls the burn function of the rebase token contract to burn the specified amount of tokens from the user's address. Then, it attempts to send the equivalent amount of ETH back to the user using a low-level call. If the call fails, an error is reverted. An event is emitted to log the redeem action.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender); // if the user wants to burn/redeem all their tokens, we need to calculate the amount based on their balance including interest
        }
        // 1. Burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. Send the user the equivalent amount of ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Returns the address of the rebase token contract associated with this vault.
     * @return The address of the rebase token contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
