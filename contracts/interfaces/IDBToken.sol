// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDBToken {
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    // Core Functions
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    // View Functions
    function holderCount() external view returns (uint256);

    function getAmount(address holder) external view returns (uint256);

    function getActiveTokens() external view returns (uint256);

    function holderAt(uint256 index) external view returns (address);

    function paused() external view returns (bool);
}