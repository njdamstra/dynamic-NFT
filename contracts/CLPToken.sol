// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public pool;

    // Mapping to track if an address is already a holder
    mapping(address => bool) private isHolder;
    // Array to store all holders
    address[] private holders;

    constructor() ERC20("Loan Pool Token", "LPT") {
        pool = msg.sender; // LoanPool contract will deploy this
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only pool can call this function!");
        _;
    }

    // Mint tokens and track holders
    function mint(address to, uint256 amount) external onlyPool {
        if (!isHolder[to] && amount > 0) {
            isHolder[to] = true;
            holders.push(to);
        }
        _mint(to, amount);
    }

    // Burn tokens and remove holder if balance is zero
    function burn(address from, uint256 amount) external onlyPool {
        _burn(from, amount);

        if (balanceOf(from) == 0 && isHolder[from]) {
            isHolder[from] = false;
            _removeHolder(from);
        }
    }

    // Get total number of holders
    function holderCount() external view returns (uint256) {
        return holders.length;
    }

    // Get the amount of LP tokens a specific holder has
    function getAmount(address holder) external view returns (uint256) {
        return balanceOf(holder);
    }

    // Get the total active LP tokens in circulation
    function getActiveTokens() external view returns (uint256) {
        return totalSupply();
    }

    // Get holder at a specific index
    function holderAt(uint256 index) external view returns (address) {
        require(index < holders.length, "[*ERROR*] Index out of bounds!");
        return holders[index];
    }

    // Private function to remove a holder from the array
    function _removeHolder(address holder) private {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == holder) {
                holders[i] = holders[holders.length - 1]; // Replace with the last holder
                holders.pop(); // Remove the last holder
                break;
            }
        }
    }
}
