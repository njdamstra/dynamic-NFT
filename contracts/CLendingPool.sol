// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // added for security
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./CCollateralManager.sol";
import {IDBToken} from "../interfaces/IDBToken.sol";
import {ILPToken} from "../interfaces/ILPToken.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";


contract LendingPool is ReentrancyGuard {
    address[] lenders;
    address[] borrowers;

    mapping(address => uint256) public totalSuppliedUsers; // Tracks ETH (without interest) supplied by lenders
    mapping(address => uint256) public totalBorrowedUsers; // Tracks ETH (with interest) currently borrowed by users


    mapping(address => uint256) public netBorrowedUsers; // Tracks ETH (without interest) currently borrowed by borrowers

    mapping(address => uint256) public netSuppliedUsers; // Tracks ETH (without interest) supplied by lenders


    uint256 public netBorrowedPool;    // Tracks ETH (without interest) borrowed from the pool
    uint256 public totalBorrowedPool;    // Tracks ETH (with interest) borrowed from the pool
    uint256 public poolBalance;      // Tracks current ETH in the pool

    address public lpTokenAddr;
    //ILPToken public iLPToken;          // Loan Pool Token
    address public dbTokenAddr;
    //IDBToken public iDBToken;          // Debt Token

    //LPToken public lpToken;
    //DBToken public dbToken;

    address public collateralManagerAddr;
    ICollateralManager public iCollateralManager; // Contract managing NFT collateral

    bool public paused = false; // pause contract

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function initialize(address _collateralManagerAddr) external onlyOwner {

        paused = false;
        collateralManagerAddr = _collateralManagerAddr;
        iCollateralManager = ICollateralManager(collateralManagerAddr);
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
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed borrower, uint256 tokenId, uint256 amountRecovered);

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
    function supply(address lender, uint256 amount) external payable {
        require(amount > 0, "[*ERROR*] Cannot supply zero ETH!");

        if (isLender(lender)) {
            totalSuppliedUsers[lender] += amount;
        } else {
            addLenderIfNotExists(lender, amount);
        }
        // Update the pool balance
        poolBalance += amount;
        //netSuppliedUsers[lender] += amount;
        emit Supplied(lender, amount);
    }

    // Allows users to withdraw ETH from the pool
    function withdraw(address lender, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "[*ERROR*] Cannot withdraw zero ETH!");
        require(isLender(lender), "[*ERROR*] User is not a lender");
        require(poolBalance >= amount, "[*ERROR*] Insufficient funds in pool!");
        uint256 userBalance = totalSuppliedUsers[lender];
        require(userBalance >= amount, "[*ERROR*] Insufficient funds in balance!");

        // Update the pool balance
        poolBalance -= amount;

        //update suppliedUsers
        totalSuppliedUsers[lender] -= amount;

        if (!totalSuppliedUsers[lender] > 0) {
            deleteLender(lender);
        }

        // Transfer the ETH to the user
        (bool success, ) = lender.call{value: amount}("");
        require(success, "[*ERROR*] Transfer failed!");
        emit Withdrawn(msg.sender, amount);
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(uint256 amount) external nonReentrant whenNotPaused {
        require(netLoan <= poolBalance, "[*ERROR*] Insufficient pool liquidity!");
        //TODO check hf for Loan and Existing Collateral

        // calculate interest as 10% of borrowed amount
        uint256 netLoan = amount;
        uint256 interest = (amount * 10) / 100; // 10% interest
        uint256 totalLoan = amount + interest;

        //TODO get the NFT value & ensure HF

        // send eth to borrower
        (bool success, ) = msg.sender.call{value: netLoan}("");
        require(success, "[*ERROR*] Transfer of debt tokens failed!");

        //update state of lend pool
        poolBalance -= netLoan;
        netBorrowedPool += netLoan;
        totalBorrowedPool += totalLoan;
        netBorrowedUsers[msg.sender] += netLoan;
        totalBorrowedUsers[msg.sender] += totalLoan;
        // create a borrow event
        emit Borrowed(msg.sender, amount);
    }

    // Allows users to repay borrowed ETH with interest
    function repay(uint256 amount) external payable {
        uint256 netDebt = netBorrowedUsers[msg.sender];
        require(netDebt > 0, "[*ERROR*] No debt to repay!");
        require(totalDebt > 0, "[*ERROR*] No debt to repay!");
        uint256 userBalance = iDBToken.balanceOf(msg.sender);
        require(userBalance >= amount, "[*ERROR*] Insufficient DB tokens!");
        uint256 interest = (netDebt * 10) / 100; // 10% interest
        uint256 totalDebt = netDebt + interest;
        require(amount >= totalDebt, "[*ERROR*] Insufficient amount to cover the debt!");
        require(msg.value == totalDebt, "[*ERROR*] Incorrect repayment amount!");

        // Burn DB tokens from the borrower
        iDBToken.burn(msg.sender, totalDebt);

        poolBalance += totalDebt;
        netBorrowedPool -= netDebt;
        totalBorrowedPool -= totalDebt;

        netBorrowedUsers[msg.sender] -= netDebt;
        totalBorrowedUsers[msg.sender] -= totalDebt;

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
    function liquidate(address borrower, address collection, uint256 tokenId, uint256 amount) external onlyOwner {
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

    function allocateInterest(uint256 amount) private {
        uint256 totalSupplied = getTotalSupplied();
        for (uint256 i = 0; i < lenders.length; i++) {
            address lender = lenders[i];
            uint256 lenderBalance = totalSuppliedUsers[lender];

            if (totalSupplied > 0) {
                uint256 lenderShare = (lenderBalance * amount) / totalSupplied;
                totalSuppliedUsers[lender] += lenderShare; // Update mapping with new balance
            }
        }
    }

    function getTotalSupplied() private view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < lenders.length; i++) {
            total += totalSuppliedUsers[lenders[i]];
        }
        return total;
    }

    function isLender(address lender) public view returns (bool) {
        if (totalSuppliedUsers[lender] == 0) {
            delete totalSuppliedUsers[lender];
            return false;
        }
        for (uint256 i = 0; i < lenders.length; i++) {
            if (lenders[i] == lender) {
                return true;
            }
        }
        return false;
    }

    function addLenderIfNotExists(address lender, uint256 initialAmount) public {
        // Check if the lender already exists using the isLender function
        if (!isLender(lender)) {
            lenders.push(lender); // Add the lender to the lenders array
            totalSuppliedUsers[lender] = initialAmount; // Initialize their supplied amount
        }
    }

    function isBorrower(address borrower) public view returns (bool) {
        if (totalBorrowedUsers[borrower] == 0) {
            delete totalBorrowedUsers[borrower];
            return false;
        }
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower) {
                return true;
            }
        }
        return false;
    }

    function addBorrowerIfNotExists(address borrower, uint256 initialAmount) public {
        // Check if the borrower already exists using the isBorrower function
        if (!isBorrower(borrower)) {
            borrowers.push(borrower); // Add the borrower to the borrowers array
            totalBorrowedUsers[borrower] = initialAmount; // Initialize their borrowed amount
        }
    }

    function deleteLender(address lender) public {
        // Check if the lender exists
        require(isLender(lender), "Lender does not exist");
        // Remove from the lenders array
        for (uint256 i = 0; i < lenders.length; i++) {
            if (lenders[i] == lender) {
                lenders[i] = lenders[lenders.length - 1]; // Move the last element to the deleted spot
                lenders.pop(); // Remove the last element
                break;
            }
        }
        // Remove from the mapping
        delete totalSuppliedUsers[lender];
    }

    function deleteBorrower(address borrower) public {
        // Check if the borrower exists
        require(isBorrower(borrower), "Borrower does not exist");
        // Remove from the borrowers array
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == borrower) {
                borrowers[i] = borrowers[borrowers.length - 1]; // Move the last element to the deleted spot
                borrowers.pop(); // Remove the last element
                break;
            }
        }
        // Remove from the mapping
        delete totalBorrowedUsers[borrower];
    }

}
