// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // added for security

import "./CCollateralManager.sol";
import "./CDBToken.sol";
import "./CLPToken.sol";


contract LendingPool is ReentrancyGuard {
    mapping(address => uint256) public netBorrowedUsers; // Tracks ETH (without interest) currently borrowed by users
    mapping(address => uint256) public netSuppliedUsers; // Tracks ETH (without interest) supplied by users
    mapping(address => uint256) public totalBorrowedUsers; // Tracks ETH (with interest) currently borrowed by users

    uint256 public netBorrowedPool;    // Tracks ETH (without interest) borrowed from the pool
    uint256 public totalBorrowedPool;    // Tracks ETH (with interest) borrowed from the pool
    uint256 public poolBalance;      // Tracks current ETH in the pool

    LPToken public lpToken;          // Loan Pool Token
    DBToken public dbToken;          // Debt Token

    CollateralManager public collateralManager; // Contract managing NFT collateral

    bool public paused = false; // pause contract

    address public owner;

    constructor(address _collateralManager) {
        paused = false;
        owner = msg.sender;
        lpToken = new LPToken();
        dbToken = new DBToken();
        collateralManager = CollateralManager(_collateralManager);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "[*ERROR*] Contract is paused!");
        _;
    }
    // events for transparency
    event Supplied(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount, uint256 nftId);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, uint256 nftId, uint256 amountRecovered);

    // Transfers ETH into the pool without return tokens
    function transfer(uint256 amount) external payable {
        require(msg.value == amount, "[*ERROR*] Incorrect ETH amount sent!");
        require(amount > 0, "[*ERROR*] Cannot transfer zero ETH!");

        // Update the pool balance
        poolBalance += amount;
    }

    fallback() external payable {
        require(msg.value > 0, "[*ERROR*] Cannot send zero ETH!");
        poolBalance += msg.value;
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
        emit Supplied(msg.sender, amount);
    }

    // Allows users to withdraw ETH from the pool
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
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
        emit Withdrawn(msg.sender, amount);
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(uint256 amount, uint256 nftId) external nonReentrant whenNotPaused {
        require(netLoan <= poolBalance, "[*ERROR*] Insufficient pool liquidity!");
        // calculate interest as 10% of borrowed amount
        uint256 netLoan = amount;
        uint256 interest = (amount * 10) / 100; // 10% interest
        uint256 totalLoan = amount + interest;

        // check if NFT is registered within the pool
        require(
            collateralManager.isCollateralRegistered(msg.sender, nftId),
            "[*ERROR*] NFT collateral not registered!"
        );

        // check if NFT value is sufficient for healthFactor > 1.2
        uint256 nftValue = collateralManager.getNFTValue(msg.sender, nftId);
        uint256 healthFactor = (nftValue * 100) / (netBorrowedUsers[msg.sender] + totalLoan); // Health factor
        require(healthFactor >= 120, "[*ERROR*] Health factor would fall below 1.2!");

        dbToken.mint(msg.sender, totalLoan);
        (bool success, ) = msg.sender.call{value: totalLoan}("");
        require(success, "[*ERROR*] Transfer failed!");

        poolBalance -= netLoan;
        netBorrowedPool += netLoan;
        totalBorrowedPool += totalLoan;

        netBorrowedUsers[msg.sender] += netLoan;
        totalBorrowedUsers[msg.sender] += totalLoan;

        emit Borrowed(msg.sender, amount, nftId);

    }

    // Allows users to repay borrowed ETH with interest
    function repay(uint256 amount) external payable {
        uint256 netDebt = netBorrowedUsers[msg.sender];
        require(netDebt > 0, "[*ERROR*] No debt to repay!");
        require(totalDebt > 0, "[*ERROR*] No debt to repay!");
        uint256 interest = (netDebt * 10) / 100; // 10% interest
        uint256 totalDebt = netDebt + interest;
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");
        require(msg.value == totalDebt, "[*ERROR*] Incorrect repayment amount!");

        // Burn DB tokens from the borrower
        dbToken.burn(msg.sender, totalDebt);

        poolBalance += totalDebt;
        netBorrowedPool -= netDebt;
        totalBorrowedPool -= totalDebt;

        netBorrowedUsers[msg.sender] -= netDebt;
        totalBorrowedUsers[msg.sender] -= totalDebt;

        // Distribute interest proportionally as LP tokens or add to pool if no lenders
        uint256 activeTokens = lpToken.getActiveTokens();
        if (activeTokens > 0) {
            // Distribute interest proportionally among lenders
            for (uint256 i = 0; i < activeTokens; i++) {
                address lender = lpToken.holderAt(i); // Assumes LPToken has a holder-tracking feature
                uint256 lenderShare = (lpToken.balanceOf(lender) * interest) / activeTokens;
                lpToken.mint(lender, lenderShare);
            }
        } else {
            // If no lenders, add interest to the pool balance
            poolBalance += interest;
        }
        emit Repaid(msg.sender, amount);
    }

    // Liquidates an NFT if the health factor drops below 1.2
    function liquidate(address borrower, uint256 nftId) external onlyOwner {
        uint256 healthFactor = collateralManager.getHealthFactor(borrower, nftId);
        require(healthFactor < 120, "[*ERROR*] Health factor is sufficient, cannot liquidate!");

        uint256 nftValue = collateralManager.liquidateNFT(borrower, nftId);
        uint256 totalDebt = totalBorrowedUsers[borrower];

        uint256 profit = nftValue > totalDebt ? nftValue - totalDebt : 0;
        uint256 amountToPool = nftValue - profit;

        dbToken.burn(borrower, totalDebt);

        poolBalance += amountToPool;
        netBorrowedPool -= totalDebt;
        totalBorrowedPool -= totalDebt;

        netBorrowedUsers[borrower] -= totalDebt;
        totalBorrowedUsers[borrower] -= totalDebt;

        // Distribute profit as interest
        uint256 activeTokens = lpToken.getActiveTokens()();
        if (activeTokens > 0 && profit > 0) {
            for (uint256 i = 0; i < activeTokens; i++) {
                address lender = lpToken.holderAt(i); // Assumes LPToken has a holder-tracking feature
                uint256 lenderShare = (lpToken.balanceOf(lender) * profit) / activeTokens;
                lpToken.mint(lender, lenderShare);
            }
        } else {
            poolBalance += profit; // If no lenders, add profit to pool balance
        }
        emit Liquidated(borrower, nftId, amountToPool);
    }

    // Retrieve user account data including LP and DB tokens
    function getUserAccountData(address user) external view
    returns (
        uint256 totalDebtETH,
        uint256 lpTokenBalance,
        uint256 dbTokenBalance
    )
    {
        totalDebtETH = totalBorrowedUsers[user];
        lpTokenBalance = lpToken.balanceOf(user);
        dbTokenBalance = dbToken.balanceOf(user);
    }

}
