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
    function collateralManagerAddr() external view returns (address);
    function paused() external view returns (bool);

    // Core Functions
    function transfer(uint256 amount) external payable;
    function supply(address lender, uint256 amount) external payable;
    function withdraw(address lender, uint256 amount) external;
    function borrow(address borrower, uint256 amount) external;
    function repay(address borrower, uint256 amount) external payable;
    function liquidate(address borrower, address collection, uint256 tokenId, uint256 amount) external payable;

    // Data Retrieval
    function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalDebt,
        uint256 netDebt,
        uint256 totalSupplied
    );

    function getBorrowerList() external view returns (address[] memory);
    function getLenderList() external view returns (address[] memory);

    // Initialization
    function initialize(address _collateralManagerAddr, address _portal, address _trader) external;

    // Administrative Controls
    function pause() external;
    function unpause() external;

    // Helpers
    function isLender(address lender) external view returns (bool);
    function isBorrower(address borrower) external view returns (bool);
    function addBorrowerIfNotExists(address borrower) external;
    function deleteBorrower(address borrower) external;
    function addLenderIfNotExists(address lender) external;
    function deleteLender(address lender) external;
    function getTotalBorrowedUsers(address borrower) external returns (uint256);
    function updateBorrowersInterest() external;
}
