// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool
// https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/protocol/pool/Pool.sol

interface ILendingPool {

    /**
    * Initializes the Pool.
    * @param provider The address of the PoolAddressesProvider
    **/
    function initialize(address provider) external virtual;

    /**
    * Supplies a certain amount of an asset into the protocol, minting the same amount of corresponding
    * aTokens and transferring them to the onBehalfOf address.
    * @param asset The address of the underlying asset being supplied to the pool
    * @param amount The amount of asset to be supplied
    * @param onBehalfOf The address that will receive the corresponding aTokens. This is the only
    * address that will be able to withdraw the asset from the pool. This will be the same as
    * msg.sender if the user wants to receive aTokens into their own wallet, or use a different
    * address if the beneficiary of aTokens is a different wallet
    * @param referralCode Referral supply is currently inactive, you can pass 0
    **/
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) public virtual override;
    /**
    * Withdraws an amount of underlying asset from the reserve, burning the equivalent aTokens
    * owned.
    * @param asset The address of the underlying asset to withdraw, not the aToken
    * @param amount The underlying amount to be withdrawn (the amount supplied), expressed in
    * wei units. Use type(uint).max to withdraw the entire aToken balance
    * @param to The address that will receive the underlying asset. This will be the same as
    * msg.sender if the user wants to receive the tokens into their own wallet, or use a different
    * address if the beneficiary is a different wallet
    **/
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) public virtual override;

    /**
    * Allows users to borrow a specific amount of the reserve underlying asset, provided the borrower
    * has already supplied enough collateral, or they were given enough allowance by a credit
    * delegator on the corresponding debt token (VariableDebtToken)
    * @param asset The address of the underlying asset to borrow
    * @param amount The amount to be borrowed, expressed in wei units
    * @param interestRateMode Should always be passed a value of 2 (variable rate mode)
    * @param referralCode Referral supply is currently inactive, you can pass 0
    * @param onBehalfOf This should be the address of the borrower calling the function if they
    * want to borrow against their own collateral, or the address of the credit delegator if the
    * caller has been given credit delegation allowance
    **/
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) public virtual override;

    /**
    * Repays a borrowed amount on a specific reserve, burning the equivalent debt tokens owned.
    * @param asset The address of the borrowed underlying asset previously borrowed
    * @param amount The amount to repay, expressed in wei units. Use type(uint256).max in order
    * to repay the whole debt, ONLY when the repayment is not executed on behalf of a 3rd party.
    * In case of repayments on behalf of another user, it's recommended to send an amount slightly
    * higher than the current borrowed amount.
    * @param interestRateMode
    * @param onBehalfOf
    **/

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) public virtual override;

    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated,
     * and receives a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
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
    );
}