// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CLPToken.sol";
import "./CDBToken.sol";

contract LoanPool {
    mapping(address => uint256) public balances; // Tracks ETH deposited by users
    mapping(address => uint256) public borrowed; // Tracks ETH borrowed by users

    uint256 public totalSupply;       // Total ETH in the pool
    uint256 public totalBorrowed;    // Total ETH borrowed from the pool
    uint256 public interestReserve;  // Accumulated interest paid by borrowers

    LPToken public lpToken; // Loan Pool Token
    DBToken public dbToken; // Debt Token

    address public owner;

    constructor() {
        owner = msg.sender;
        lpToken = new LPToken();
        dbToken = new DBToken();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }

    // Allows users to supply ETH to the pool
    function supply(
        address asset, // Placeholder for ETH-only pool
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode // Ignored
    ) external payable {
        require(msg.value == amount, "[*ERROR*] Incorrect amount of ETH supplied!");
        require(amount > 0, "[*ERROR*] Cannot supply zero ETH!");

        balances[onBehalfOf] += amount;
        totalSupply += amount;

        // Mint LP tokens to the supplier
        lpToken.mint(onBehalfOf, amount);
    }

    // Allows users to withdraw ETH from the pool
    function withdraw(
        address asset, // Placeholder for ETH-only pool
        uint256 amount,
        address to
    ) external {
        require(balances[msg.sender] >= amount, "[*ERROR*] Insufficient balance to withdraw!");

        // Calculate the lender's share of the interest reserve
        uint256 interestShare = (interestReserve * amount) / totalSupply;

        // Update balances and interest reserve
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        interestReserve -= interestShare;

        // Burn LP tokens from the withdrawer
        lpToken.burn(msg.sender, amount);

        // Transfer the principal and the interest share
        uint256 payout = amount + interestShare;
        (bool success, ) = to.call{value: payout}("");
        require(success, "[*ERROR*] Transfer failed!");
    }

    // Allows users to borrow ETH from the pool
    function borrow(
        address asset, // Placeholder for ETH-only pool
        uint256 amount,
        uint256 interestRateMode, // Ignored
        uint16 referralCode, // Ignored
        address onBehalfOf
    ) external {
        require(balances[onBehalfOf] >= amount / 2, "[*ERROR*] Insufficient collateral!"); // 50% LTV
        require(amount <= totalSupply - totalBorrowed, "[*ERROR*] Insufficient liquidity!");

        borrowed[msg.sender] += amount;
        totalBorrowed += amount;

        // Mint DB tokens to the borrower
        dbToken.mint(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
    }

    // Allows users to repay borrowed ETH with interest
    function repay(
        address asset, // Placeholder for ETH-only pool
        uint256 amount,
        uint256 interestRateMode, // Ignored
        address onBehalfOf
    ) external payable {
        require(amount > 0, "[*ERROR*] Repayment amount must be greater than zero!");
        uint256 totalDebt = borrowed[onBehalfOf];
        require(totalDebt > 0, "[*ERROR*] No debt to repay!");
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");

        // Calculate interest (10% of the borrowed amount)
        uint256 interest = (totalDebt * 10) / 100;

        // Require the borrower to pay principal + interest
        require(msg.value == totalDebt + interest, "[*ERROR*] Incorrect repayment amount!");

        // Burn DB tokens from the borrower
        dbToken.burn(onBehalfOf, totalDebt);

        // Update borrowed amount and interest reserve
        borrowed[onBehalfOf] -= totalDebt;
        totalBorrowed -= totalDebt;
        interestReserve += interest;
    }

    // Retrieve user account data
    function getUserAccountData(address user)
    external
    view
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
        availableBorrowsETH = balances[user] / 2 - borrowed[user]; // 50% LTV
        currentLiquidationThreshold = 75; // Arbitrary threshold
        ltv = 50; // 50% LTV
        healthFactor = balances[user] > 0 ? (balances[user] * 100) / borrowed[user] : 0;
    }
}
