// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ILendingPool.sol";

contract LoanPool is ILendingPool {
    mapping(address => uint256) public balances; // Tracks ETH deposited
    mapping(address => uint256) public borrowed; // Tracks ETH borrowed
    uint256 public totalSupply; // Total ETH in the pool
    uint256 public totalBorrowed; // Total ETH borrowed

    address public owner; // Contract owner

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not contract owner!");
        _;
    }

    // Initializes the pool with a provider (placeholder for ETH-only pool)
    function initialize(address provider) external override {
        // Initialization logic can be added here if necessary
    }

    // Supplies ETH to the pool
    function supply(
        address asset, // Ignored for ETH-only
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode // Ignored for simplicity
    ) external payable override {
        require(msg.value == amount, "[*ERROR*] Mismatch in amount! Could not supply.");
        require(amount > 0, "[*ERROR*] Must supply ETH! Could not supply.");
        balances[onBehalfOf] += amount;
        totalSupply += amount;
    }

    // Withdraws ETH from the pool
    function withdraw(
        address asset, // Ignored for ETH-only
        uint256 amount,
        address to
    ) external override {
        require(balances[msg.sender] >= amount, "[*ERROR*] Insufficient balance! Could not withdraw.");
        balances[msg.sender] -= amount;
        totalSupply -= amount;

        (bool success, ) = to.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed! Could not withdraw.");
    }

    // Borrows ETH from the pool
    function borrow(
        address asset, // Ignored for ETH-only
        uint256 amount,
        uint256 interestRateMode, // Ignored for simplicity
        uint16 referralCode, // Ignored for simplicity
        address onBehalfOf
    ) external override {
        require(balances[onBehalfOf] >= amount, "[*ERROR*] Insufficient collateral! Could not borrow.");
        require(amount <= totalSupply - totalBorrowed, "[*ERROR*] Insufficient liquidity! Could not borrow.");
        borrowed[msg.sender] += amount;
        totalBorrowed += amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed! Could not borrow");
    }

    // Repays borrowed ETH
    function repay(
        address asset, // Ignored for ETH-only
        uint256 amount,
        uint256 interestRateMode, // Ignored for simplicity
        address onBehalfOf
    ) external payable override {
        require(msg.value == amount, "[*ERROR*] Mismatch in amount! Could not repay.");
        require(borrowed[onBehalfOf] >= amount, "[*ERROR*] Over-repayment! Could not repay.");
        borrowed[onBehalfOf] -= amount;
        totalBorrowed -= amount;
    }

    // Liquidates unhealthy positions
    function liquidationCall(
        address collateralAsset, // Ignored for ETH-only
        address debtAsset, // Ignored for ETH-only
        address user,
        uint256 debtToCover,
        bool receiveAToken // Ignored for simplicity
    ) external override onlyOwner {
        require(borrowed[user] >= debtToCover, "[*ERROR*] No debt to cover! Could not liquidate");
        borrowed[user] -= debtToCover;
        totalBorrowed -= debtToCover;

        // Transfer collateral back to the liquidator
        uint256 collateralToLiquidator = debtToCover; // For simplicity, 1:1 ratio
        balances[user] -= collateralToLiquidator;
        (bool success, ) = msg.sender.call{value: collateralToLiquidator}("");
        require(success, "[*ERROR*] Collateral transfer failed! Could not liquidate.");
    }

    // Retrieves user account data
    function getUserAccountData(address user)
    external
    view
    override
    returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    )
    {
        totalCollateralETH = balances[user];
        totalDebtETH = borrowed[user];
        availableBorrowsETH = balances[user] - borrowed[user];
        currentLiquidationThreshold = 75; // Placeholder: 75%
        ltv = 50; // Placeholder: 50% loan-to-value
        healthFactor = balances[user] > 0 ? (balances[user] * 100) / borrowed[user] : 0;
    }
}
