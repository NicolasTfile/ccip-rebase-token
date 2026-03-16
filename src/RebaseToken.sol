// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Olaniyi Agunloye
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") {}

    /**
     * @notice Sets the new interest rate for the token, The interest rate can only decrease.
     * @param _newInterestRate The new interest rate to be set.
     * @dev The function checks if the new interest rate is less than the current interest rate and reverts if it is not. If the new interest rate is valid, it updates the state variable and emits an event.
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // Logic to set the new interest rate, ensuring it can only decrease
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mints the user tokens when they deposit into the vault.
     * @param _to The address of the user to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to); // mint the accrued interest for the user before minting new tokens
        s_userInterestRate[_to] = s_interestRate; // set the user's interest rate to the current global interest rate at the time of minting
        _mint(_to, _amount); // implemented in ERC20
    }

    /**
     * @notice Calculates the user's balance including any accrued interest since the last update.
     * (principle balance) + some interest that has accrued.
     * @param _user The user address to calculate the balance for.
     * @return The user's balance including any accrued interest since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principle balance of the user (the number of tokens that have actually been minted to the user)
        // multiply the princriple balance by the interest that has accumulated since the balance was last updated
        return super.balanceOf(_user) * calculateUserAccumulatedInterestSinceLastUpdate(_user);
    }

    function _mintAccruedInterest(address _user) internal {
        // 1. Find their current balance of rebase tokens that has been minted to the user -> principle balance
        // 2. Calculate their current balance including any accrued interest -> balanceOf
        // 3. Calculate the number of tokens that need to be minted to the user -> interest = {2} - (1)
        // 4. Call _mint() to mint the tokens to the user
        // Set the user's last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice Get the interest rate for the user.
     * @param _user The address of the user.
     * @return The interest rate for the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
