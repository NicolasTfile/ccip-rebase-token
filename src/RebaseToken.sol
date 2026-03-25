// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Olaniyi Agunloye
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grants the MINT_AND_BURN_ROLE to an account, allowing them to mint and burn tokens. This function can only be called by the owner of the contract.
     * @param _account The address of the account to grant the MINT_AND_BURN_ROLE to.
     * @dev Granting this role allows the user to mint and burn tokens, which is a known security risk and centralization issue. Therefore, this function should be used with caution and only granted to trusted accounts.
     */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets the new interest rate for the token, The interest rate can only decrease.
     * @param _newInterestRate The new interest rate to be set.
     * @dev The function checks if the new interest rate is less than the current interest rate and reverts if it is not. If the new interest rate is valid, it updates the state variable and emits an event.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Logic to set the new interest rate, ensuring it can only decrease
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Returns the principal balance of a user (the number of tokens that have currently been minted to the user excluding accrued interest since the last time the user interacted with the protocol).
     * @param _user The user address to get the principal balance for.
     * @return The principal balance of the user.
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mints the user tokens when they deposit into the vault.
     * @param _to The address of the user to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to); // mint the accrued interest for the user before minting new tokens
        s_userInterestRate[_to] = s_interestRate; // set the user's interest rate to the current global interest rate at the time of minting
        _mint(_to, _amount); // implemented in ERC20
    }

    /**
     * @notice Burns the user's tokens when they withdraw from the vault.
     * @param _from The address of the user to burn tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from); // mint the accrued interest for the user before burning tokens
        _burn(_from, _amount); // implemented in ERC20
    }

    /**
     * @notice Calculates the user's balance including any accrued interest since the last update.
     * (principal balance) + some interest that has accrued.
     * @param _user The user address to calculate the balance for.
     * @return The user's balance including any accrued interest since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principal balance of the user (the number of tokens that have actually been minted to the user)
        // multiply the principal balance by the interest that has accumulated since the balance was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _sender The user to transfer the tokens from
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculates the user's accumulated interest since the last update.
     * @param _user The user address to calculate the accumulated interest for.
     * @return linearInterest The user's accumulated interest since the last update.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the user's balance was last updated
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // principal amount(1 + (user interest rate * time elapsed))
        // deposit: 10 tokens
        // interest rate: 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 +(10 * 0.5 * 2) = 20 tokens
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mints the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer).
     * @param _user The address of the user to mint the accrued interest to.
     * @dev The function calculates the user's current balance including any accrued interest, calculates the number of tokens that need to be minted to the user, updates the user's last updated timestamp, and calls _mint() to mint the tokens to the user.
     */
    function _mintAccruedInterest(address _user) internal {
        // 1. Find their current balance of rebase tokens that has been minted to the user -> principal balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // 2. Calculate their current balance including any accrued interest -> balanceOf
        uint256 currentBalanceWithInterest = balanceOf(_user);
        // 3. Calculate the number of tokens that need to be minted to the user -> interest = {2} - (1)
        uint256 balanceIncrease = currentBalanceWithInterest - previousPrincipalBalance;
        // 4. Set the user's last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // 5. Call _mint() to mint the tokens to the user
        _mint(_user, balanceIncrease); // this function already emits an event, so we don't need to emit another event here
    }

    /**
     * @notice Get the interest rate that is currently set for the protocol/contract. Any future depositors will receive this interest rate.
     * @return The interest rate for the protocol.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
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
