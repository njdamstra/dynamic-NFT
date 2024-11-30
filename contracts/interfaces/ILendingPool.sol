// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    // Events
    event Supplied(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, uint256 tokenId, uint256 amountRecovered);

    // State Variables
    function poolBalance() external view returns (uint256);
    function netBorrowedPool() external view returns (uint256);
    function totalBorrowedPool() external view returns (uint256);
    function netBorrowedUsers(address user) external view returns (uint256);
    function totalBorrowedUsers(address user) external view returns (uint256);
    function netSuppliedUsers(address user) external view returns (uint256);
    function totalSuppliedUsers(address user) external view returns (uint256);
    function lpTokenAddr() external view returns (address);
    function dbTokenAddr() external view returns (address);
    function collateralManagerAddr() external view returns (address);
    function paused() external view returns (bool);

    // Core Functions
    function supply(uint256 amount) external payable;
    function withdraw(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external payable;
    function liquidate(address borrower, address collection, uint256 tokenId, uint256 amount) external;

    // Data Retrieval
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalDebtETH,
            uint256 lpTokenBalance,
            uint256 dbTokenBalance
        );

    // Initialization
    function initialize(address _lpTokenAddr, address _dbTokenAddr, address _collateralManagerAddr) external;

    // Administrative Controls
    function pause() external;
    function unpause() external;
}
