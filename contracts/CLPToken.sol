// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public pool;

    mapping(address => uint256) private holderIndex; // Holder index in the array
    address[] private holders;

    bool public paused;

    constructor() ERC20("Loan Pool Token", "LPT") {
        pool = msg.sender; // LoanPool contract will deploy this
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only pool can call this function!");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "[*ERROR*] Contract is paused!");
        _;
    }

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    // Mint tokens and track holders
    function mint(address to, uint256 amount) external onlyPool whenNotPaused {
        require(to != address(0), "[*ERROR*] Cannot mint to zero address!");
        if (balanceOf(to) == 0 && amount > 0) {
            holderIndex[to] = holders.length;
            holders.push(to);
        }
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // Burn tokens and remove holder if balance is zero
    function burn(address from, uint256 amount) external onlyPool whenNotPaused {
        _burn(from, amount);

        if (balanceOf(from) == 0) {
            _removeHolder(from);
        }
        emit TokensBurned(from, amount);
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
        uint256 index = holderIndex[holder];
        uint256 lastIndex = holders.length - 1;

        if (index != lastIndex) {
            address lastHolder = holders[lastIndex];
            holders[index] = lastHolder; // Replace with the last holder
            holderIndex[lastHolder] = index; // Update index
        }

        holders.pop(); // Remove the last holder
        delete holderIndex[holder]; // Delete holder index
    }

    // Pause or unpause contract
    function pause() external onlyPool {
        paused = true;
    }

    function unpause() external onlyPool {
        paused = false;
    }
}
