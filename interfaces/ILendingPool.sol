// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    /**
    * Transfers ETH directly into the pool without minting LP tokens.
    * @param amount The amount of ETH being transferred into the pool.
    */
    function transfer(uint256 amount) external payable;

    /**
    * Supplies ETH to the pool, minting the corresponding LP tokens for the user.
    * @param amount The amount of ETH to supply to the pool.
    */
    function supply(uint256 amount) external payable;

    /**
    * Withdraws ETH from the pool, burning the corresponding LP tokens owned by the user.
    * @param amount The amount of ETH to withdraw from the pool.
    */
    function withdraw(uint256 amount) external;

    /**
    * Borrows a specific amount of ETH from the pool using NFT collateral.
    * @param amount The amount of ETH to borrow.
    * @param nftId The ID of the NFT being used as collateral.
    */
    function borrow(uint256 amount, uint256 nftId) external;

    /**
    * Repays a borrowed amount of ETH, including interest, burning the equivalent DB tokens owned.
    * @param amount The amount of ETH to repay, including principal and interest.
    */
    function repay(uint256 amount) external payable;

    /**
    * Liquidates a non-healthy position with a Health Factor below 1.2.
    * - The liquidator covers the debt of the user and receives the NFT collateral.
    * @param borrower The address of the borrower being liquidated.
    * @param nftId The ID of the NFT collateral being liquidated.
    */
    function liquidate(address borrower, uint256 nftId) external;

    /**
    * Retrieves user account data, including their collateral, debt, and token balances.
    * @param user The address of the user to retrieve data for.
    * @return totalCollateralETH The total collateral in ETH deposited by the user.
    * @return totalDebtETH The total debt in ETH borrowed by the user.
    * @return lpTokenBalance The balance of LP tokens owned by the user.
    * @return dbTokenBalance The balance of DB tokens owned by the user.
    */
    function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 lpTokenBalance,
        uint256 dbTokenBalance
    );
}
