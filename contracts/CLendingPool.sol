// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CLPToken.sol";
import "./CDBToken.sol";
import "./CCollateralManager.sol";

contract LendingPool {
    mapping(address => uint256) public netBorrowedUsers; // Tracks ETH (without interest) currently borrowed by users
    mapping(address => uint256) public netSuppliedUsers; // Tracks ETH (without interest) supplied by users
    mapping(address => uint256) public totalBorrowedUsers; // Tracks ETH (with interest) currently borrowed by users

    uint256 public netBorrowedPool;    // Tracks ETH (without interest) borrowed from the pool
    uint256 public totalBorrowedPool;    // Tracks ETH (with interest) borrowed from the pool
    uint256 public poolBalance;      // Tracks current ETH in the pool

    uint256 public activeLpTokens; // Tracks active LPT
    uint256 public activeDbToken; // Tracks active DBT

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

    // Allows users to supply ETH to the pool
    function supply(uint256 amount) external payable {
        require(msg.value == amount, "[*ERROR*] Incorrect amount of ETH supplied!");
        require(amount > 0, "[*ERROR*] Cannot supply zero ETH!");

        // Update the pool balance
        poolBalance += amount;
        netSuppliedUsers[msg.sender] += amount;

        // Mint LP tokens proportional to the supplied amount
        lpToken.mint(msg.sender, amount);
    }

    // Allows users to withdraw ETH from the pool
    function withdraw(uint256 amount) external {
        require(amount > 0, "[*ERROR*] Cannot withdraw zero ETH!");
        uint256 userBalance = lpToken.balanceOf(msg.sender);
        require(userBalance >= amount, "[*ERROR*] Insufficient LP tokens!");

        // Update the pool balance
        poolBalance -= amount;
        netSuppliedUsers[msg.sender] -= amount;

        // Burn the LP tokens
        lpToken.burn(msg.sender, amount);

        // Transfer the ETH to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(uint256 amount, uint256 nftId) external {
        // calculate interest as 10% of borrowed amount
        uint256 netLoan = amount;
        uint256 interest = (amount * 10) / 100; // 10% interest
        uint256 totalLoan = amount += interest;

        // check if NFT is registered within the pool
        require(
            collateralManager.isCollateralRegistered(msg.sender, nftId),
            "[*ERROR*] NFT collateral not registered!"
        );

        uint256 nftValue = collateralManager.getNFTValue(msg.sender, nftId);

        // check if NFT value is sufficient for healthFactor > 1.2
        uint256 healthFactor = (nftValue * 100) / (netBorrowedUsers[msg.sender] + totalLoan); // Health factor
        require(healthFactor >= 120, "[*ERROR*] Health factor would fall below 1.2!");
        require(amount <= poolBalance, "[*ERROR*] Insufficient liquidity!");

        netBorrowedUsers[msg.sender] += amount;
        totalBorrowedPool += amount;
        poolBalance -= amount;


        dbToken.mint(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
    }

    // Allows users to repay borrowed ETH with interest
    function repay(uint256 amount) external payable {
        uint256 initialDebt = netBorrowedUsers[msg.sender];
        require(initialDebt > 0, "[*ERROR*] No debt to repay!");
        uint256 interest = (initialDebt * 10) / 100; // 10% interest
        uint256 totalDebt = initialDebt += interest;
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");

        require(msg.value == totalDebt, "[*ERROR*] Incorrect repayment amount!");

        // Burn DB tokens from the borrower
        dbToken.burn(msg.sender, totalDebt);

        netBorrowedUsers[msg.sender] -= totalDebt;
        totalBorrowedPool -= totalDebt;
        poolBalance += totalDebt;

        // Distribute interest proportionally as LP tokens or add to pool if no lenders
        uint256 totalSupply = lpToken.totalSupply();
        if (totalSupply > 0) {
            // Distribute interest proportionally among lenders
            for (uint256 i = 0; i < totalSupply; i++) {
                address lender = lpToken.holderAt(i); // Assumes LPToken has a holder-tracking feature
                uint256 lenderShare = (lpToken.balanceOf(lender) * interest) / totalSupply;
                lpToken.mint(lender, lenderShare);
            }
        } else {
            // If no lenders, add interest to the pool balance
            poolBalance += interest;
        }
    }

    // Liquidates an NFT if the health factor drops below 1.2
    function liquidate(address borrower, uint256 nftId) external onlyOwner {
        uint256 hf = collateralManager.getHealthFactor(borrower, nftId);
        require(hf < 120, "[*ERROR*] Health factor is sufficient, cannot liquidate!");

        uint256 nftValue = collateralManager.liquidateNFT(borrower, nftId);
        uint256 debtToCover = netBorrowedUsers[borrower];

        uint256 profit = nftValue > debtToCover ? nftValue - debtToCover : 0;
        uint256 amountToPool = nftValue - profit;

        netBorrowedUsers[borrower] -= debtToCover;
        totalBorrowedPool -= debtToCover;
        dbToken.burn(borrower, debtToCover);

        poolBalance += amountToPool;

        // Distribute profit as interest
        uint256 totalSupply = lpToken.totalSupply();
        if (totalSupply > 0) {
            for (uint256 i = 0; i < totalSupply; i++) {
                address lender = lpToken.holderAt(i); // Assumes LPToken has a holder-tracking feature
                uint256 lenderShare = (lpToken.balanceOf(lender) * profit) / totalSupply;
                lpToken.mint(lender, lenderShare);
            }
        } else {
            poolBalance += profit; // If no lenders, add profit to pool balance
        }
    }

    // Retrieve user account data including LP and DB tokens
    function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalDebtETH,
        uint256 lpTokenBalance,
        uint256 dbTokenBalance
    )
    {
        totalDebtETH = netBorrowedUsers[user];
        lpTokenBalance = lpToken.balanceOf(user);
        dbTokenBalance = dbToken.balanceOf(user);
    }
}
