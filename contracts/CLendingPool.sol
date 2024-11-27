// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CLPToken.sol";
import "./CDBToken.sol";
import "./CCollateralManager.sol";

contract LendingPool {
    mapping(address => uint256) public borrowed; // Tracks ETH borrowed by users
    uint256 public totalBorrowed;    // Total ETH borrowed from the pool
    uint256 public interestReserve;  // Accumulated interest paid by borrowers
    uint256 public poolBalance;      // Total ETH in the pool

    LPToken public lpToken;          // Loan Pool Token
    DBToken public dbToken;          // Debt Token
    CollateralManager public collateralManager; // Contract managing NFT collateral

    address public owner;

    constructor(address _collateralManager) {
        owner = msg.sender;
        lpToken = new LPToken();
        dbToken = new DBToken();
        collateralManager = CollateralManager(_collateralManager);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(uint256 amount, uint256 nftId) external {
        require(
            collateralManager.isCollateralRegistered(msg.sender, nftId),
            "[*ERROR*] NFT collateral not registered!"
        );

        uint256 nftValue = collateralManager.getNFTValue(msg.sender, nftId);
        uint256 hf = (nftValue * 100) / (borrowed[msg.sender] + amount); // Health factor
        require(hf >= 120, "[*ERROR*] Health factor would fall below 1.2!");
        require(amount <= poolBalance, "[*ERROR*] Insufficient liquidity!");

        borrowed[msg.sender] += amount;
        totalBorrowed += amount;
        poolBalance -= amount;

        dbToken.mint(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
    }

    // Allows users to repay borrowed ETH with interest
    function repay(uint256 amount) external payable {
        uint256 totalDebt = borrowed[msg.sender];
        require(totalDebt > 0, "[*ERROR*] No debt to repay!");
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");

        uint256 interest = (totalDebt * 10) / 100; // 10% interest
        require(msg.value == totalDebt + interest, "[*ERROR*] Incorrect repayment amount!");

        dbToken.burn(msg.sender, totalDebt);

        borrowed[msg.sender] -= totalDebt;
        totalBorrowed -= totalDebt;
        poolBalance += totalDebt;
        interestReserve += interest;
    }

    // Liquidates an NFT if the health factor drops below 1.2
    function liquidate(address borrower, uint256 nftId) external onlyOwner {
        uint256 hf = collateralManager.getHealthFactor(borrower, nftId);
        require(hf < 120, "[*ERROR*] Health factor is sufficient, cannot liquidate!");

        uint256 nftValue = collateralManager.liquidateNFT(borrower, nftId);
        uint256 debtToCover = borrowed[borrower];

        uint256 profit = nftValue > debtToCover ? nftValue - debtToCover : 0;
        uint256 amountToPool = nftValue - profit;

        borrowed[borrower] -= debtToCover;
        totalBorrowed -= debtToCover;
        dbToken.burn(borrower, debtToCover);

        poolBalance += amountToPool;
        interestReserve += profit;
    }

    // Retrieve user account data including LP and DB tokens
    function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 healthFactor,
        uint256 lpTokenBalance,
        uint256 dbTokenBalance
    )
    {
        totalDebtETH = borrowed[user];
        availableBorrowsETH = collateralManager.getAvailableBorrows(user);
        healthFactor = collateralManager.getHealthFactor(user, 0); // Simplified for a single NFT
        lpTokenBalance = lpToken.balanceOf(user);
        dbTokenBalance = dbToken.balanceOf(user);
    }
}
