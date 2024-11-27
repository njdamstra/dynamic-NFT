// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DBToken is ERC20 {
    address public pool;

    constructor() ERC20("Debt Token", "DBT") {
        pool = msg.sender; // LoanPool contract will deploy this
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only pool can call this function!");
        _;
    }

    function mint(address to, uint256 amount) external onlyPool {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyPool {
        _burn(from, amount);
    }

    // Get the total active LP tokens in circulation
    function getActiveTokens() external view returns (uint256) {
        return totalSupply();
    }
}
