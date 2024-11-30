// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // added for security
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./CCollateralManager.sol";
import {IDBToken} from "../interfaces/IDBToken.sol";
import {ILPToken} from "../interfaces/ILPToken.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";


contract LendingPool is ReentrancyGuard {
    mapping(address => uint256) public netBorrowedUsers; // Tracks ETH (without interest) currently borrowed by borrowers
    mapping(address => uint256) public totalBorrowedUsers; // Tracks ETH (with interest) currently borrowed by users

    mapping(address => uint256) public netSuppliedUsers; // Tracks ETH (without interest) supplied by lenders
    mapping(address => uint256) public totalSuppliedUsers; // Tracks ETH (without interest) supplied by lenders


    uint256 public netBorrowedPool;    // Tracks ETH (without interest) borrowed from the pool
    uint256 public totalBorrowedPool;    // Tracks ETH (with interest) borrowed from the pool
    uint256 public poolBalance;      // Tracks current ETH in the pool

    address public lpTokenAddr;
    ILPToken public iLPToken;          // Loan Pool Token
    address public dbTokenAddr;
    IDBToken public iDBToken;          // Debt Token

    LPToken public lpToken;
    DBToken public dbToken;

    address public collateralManagerAddr;
    ICollateralManager public iCollateralManager; // Contract managing NFT collateral

    bool public paused = false; // pause contract

    address public owner;
    address public portal;
    address public trader;

    constructor() {
        owner = msg.sender;
    }

    // TODO: Logic behind interfaces for LP and DB Tokens
    function initialize(address _lpTokenAddr, address _dbTokenAddr, address _collateralManagerAddr, address _portal, address _trader) external onlyOwner {
        require(lpToken == address(0), "Already initialized");
        require(_lpTokenAddr != address(0) && _dbTokenAddr != address(0) && _collateralManagerAddr != address(0), "Invalid addresses");

        paused = false;
        lpTokenAddr = _lpTokenAddr;
        //iLPToken = ILPToken(lpTokenAddr);
        dbTokenAddr = _dbTokenAddr;
        //iDBToken = IDBToken(dpTokenAddr);
        collateralManagerAddr = _collateralManagerAddr;
        iCollateralManager = ICollateralManager(collateralManagerAddr);

        portal = _portal;
        trader = _trader;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }

    modifier onlyPortal() {
        require(msg.sender == portal, "[*ERROR*] Not the contract owner!");
        _;
    }

    modifier onlyTrader() {
        require(msg.sender == trader, "[*ERROR*] Not the contract owner!");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "[*ERROR*] Contract is paused!");
        _;
    }
    // events for transparency
    event Supplied(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, uint256 tokenId, uint256 amountRecovered);

    // Transfers ETH into the pool with minting tokens
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

    receive() external payable {
        require(msg.value > 0, "[*ERROR*] Cannot send zero ETH!");
        poolBalance += msg.value;
    }

    // Allows users to supply ETH to the pool
    function supply(address lender, uint256 amount) external payable onlyPortal {
        require(msg.value == amount, "[*ERROR*] Incorrect amount of ETH supplied!");
        require(amount > 0, "[*ERROR*] Cannot supply zero ETH!");

        // Update the pool balance
        poolBalance += amount;
        netSuppliedUsers[msg.sender] += amount;

        // Mint LP tokens proportional to the supplied amount
        iLPToken.mint(msg.sender, amount);
        emit Supplied(msg.sender, amount);
    }

    // Allows users to withdraw ETH from the pool
    function withdraw(address lender, uint256 amount) external nonReentrant whenNotPaused onlyPortal {
        require(amount > 0, "[*ERROR*] Cannot withdraw zero ETH!");
        uint256 userBalance = iLPToken.balanceOf(lender);
        require(userBalance >= amount, "[*ERROR*] Insufficient LP tokens!");

        // Update the pool balance
        poolBalance -= amount;
        netSuppliedUsers[lender] -= amount;

        // Burn the LP tokens
        iLPToken.burn(lender, amount);

        // Transfer the ETH to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
        emit Withdrawn(lender, amount);
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(address borrower, uint256 amount) external nonReentrant whenNotPaused onlyPortal {
        require(netLoan <= poolBalance, "[*ERROR*] Insufficient pool liquidity!");
        //TODO check hf for Loan and Existing Collateral

        // calculate interest as 10% of borrowed amount
        uint256 netLoan = amount;
        uint256 interest = (amount * 10) / 100; // 10% interest
        uint256 totalLoan = amount + interest;

        //TODO get the NFT value & ensure HF


        // mint and give debt tokens to borrower
        iDBToken.mint(borrower, totalLoan);

        // send eth to borrower
        (bool success, ) = msg.sender.call{value: netLoan}("");
        require(success, "[*ERROR*] Transfer of debt tokens failed!");

        //update state of lend pool
        poolBalance -= netLoan;
        netBorrowedPool += netLoan;
        totalBorrowedPool += totalLoan;
        netBorrowedUsers[borrower] += netLoan;
        totalBorrowedUsers[borrower] += totalLoan;
        // create a borrow event
        emit Borrowed(borrower, amount);
    }

    // Allows users to repay borrowed ETH with interest
    function repay(address borrower, uint256 amount) external payable onlyPortal {
        uint256 netDebt = netBorrowedUsers[borrower];
        require(netDebt > 0, "[*ERROR*] No debt to repay!");
        require(totalDebt > 0, "[*ERROR*] No debt to repay!");
        uint256 userBalance = iDBToken.balanceOf(borrower);
        require(userBalance >= amount, "[*ERROR*] Insufficient DB tokens!");
        uint256 interest = (netDebt * 10) / 100; // 10% interest
        uint256 totalDebt = netDebt + interest;
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");
        require(msg.value == totalDebt, "[*ERROR*] Incorrect repayment amount!");

        // Burn DB tokens from the borrower
        iDBToken.burn(borrower, totalDebt);

        poolBalance += totalDebt;
        netBorrowedPool -= netDebt;
        totalBorrowedPool -= totalDebt;

        netBorrowedUsers[borrower] -= netDebt;
        totalBorrowedUsers[borrower] -= totalDebt;

        // Distribute interest proportionally as LP tokens or add to pool if no lenders
        uint256 activeTokens = iLPToken.getActiveTokens();
        if (activeTokens > 0) {
            // Distribute interest proportionally among lenders
            for (uint256 i = 0; i < activeTokens; i++) {
                address lender = iLPToken.holderAt(i); // Assumes LPToken has a holder-tracking feature
                uint256 lenderShare = (iLPToken.balanceOf(lender) * interest) / activeTokens;
                //TODO ? do we need the token structure DBT?
                uint256 before = netSuppliedUsers[lender]
                uint256 after =
                iLPToken.mint(lender, lenderShare);
            }
        } else {
            // If no lenders, add interest to the pool balance
            poolBalance += interest;
        }
        emit Repaid(msg.sender, amount);
    }

    // Liquidates an NFT if the health factor drops below 1.2
    // this function is called by CM who transfers eth to Pool and this function updates LendPool accordingly
    // TODO update according to liquidate in CM
    function liquidate(address borrower, address collection, uint256 tokenId, uint256 amount) external onlyTrader {
        // uint256 healthFactor = collateralManager.getHealthFactor(borrower, nftId);
        // require(healthFactor < 120, "[*ERROR*] Health factor is sufficient, cannot liquidate!");
        uint256 nftValue = iCollateralManager.getNftValue(borrower, collection, tokenId);
        // TODO does the trader do the listing??
        iCollateralManager.liquidateNft(borrower, collection, tokenId);

        uint256 totalDebt = totalBorrowedUsers[borrower];

        uint256 debtReduction = amount > totalDebt ? totalDebt : amount;
        uint256 remainingDebt = totalDebt > debtReduction ? totalDebt - debtReduction : 0;

        iDBToken.burn(borrower, debtReduction);

        netBorrowedUsers[borrower] = remainingDebt;
        totalBorrowedUsers[borrower] = remainingDebt;

        poolBalance += debtReduction;

        uint256 profit = amount > totalDebt ? amount - totalDebt : 0;

        // Distribute profit as interest
        uint256 activeTokens = iLPToken.getActiveTokens()();
        if (activeTokens > 0 && profit > 0) {
            for (uint256 i = 0; i < activeTokens; i++) {
                address lender = iLPToken.holderAt(i); // Assumes iLPToken has a holder-tracking feature
                uint256 lenderShare = (iLPToken.balanceOf(lender) * profit) / activeTokens;
                iLPToken.mint(lender, lenderShare);
            }
        } else {
            poolBalance += profit; // If no lenders, add profit to pool balance
        }

        netBorrowedPool -= totalDebt;
        totalBorrowedPool -= totalDebt;

        emit Liquidated(borrower, tokenId, amountToPool);
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
        lpTokenBalance = iLPToken.balanceOf(user);
        dbTokenBalance = iDBToken.balanceOf(user);
    }

}
