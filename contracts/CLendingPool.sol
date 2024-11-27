// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CLPToken.sol";
import "./CDBToken.sol";
import "./CCollateralManager.sol";

contract LendingPool {
    mapping(address => uint256) public borrowed; // Tracks ETH borrowed by users
    uint256 public totalBorrowed;    // Total ETH borrowed from the pool
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

    // Allows users to supply ETH to the pool
    function supply(uint256 amount) external payable {
        require(msg.value == amount, "[*ERROR*] Incorrect amount of ETH supplied!");
        require(amount > 0, "[*ERROR*] Cannot supply zero ETH!");

        poolBalance += amount;

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

        // Burn the LP tokens
        lpToken.burn(msg.sender, amount);

        // Transfer the ETH to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
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

        // Burn DB tokens from the borrower
        dbToken.burn(msg.sender, totalDebt);

        borrowed[msg.sender] -= totalDebt;
        totalBorrowed -= totalDebt;
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
        uint256 debtToCover = borrowed[borrower];

        uint256 profit = nftValue > debtToCover ? nftValue - debtToCover : 0;
        uint256 amountToPool = nftValue - profit;

        borrowed[borrower] -= debtToCover;
        totalBorrowed -= debtToCover;
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
        totalDebtETH = borrowed[user];
        lpTokenBalance = lpToken.balanceOf(user);
        dbTokenBalance = dbToken.balanceOf(user);
    }
}
