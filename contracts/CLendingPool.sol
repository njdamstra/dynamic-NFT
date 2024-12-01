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

    uint256 public poolBalance;      // Tracks current ETH in the pool

    address public collateralManagerAddr;
    ICollateralManager public iCollateralManager; // Contract managing NFT collateral

    bool public paused = false; // pause contract

    address public owner;
    address public portal;
    address public trader;

    constructor() {
        owner = msg.sender;
    }

    function initialize(address _collateralManagerAddr, address _portal, address _trader) external onlyOwner {

        paused = false;
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
    function withdraw(address lender, uint256 amount) external nonReentrant whenNotPaused onlyPortal {
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
        emit Withdrawn(lender, amount);
    }

    // Allows users to borrow ETH from the pool using NFT collateral
    function borrow(address borrower, uint256 amount) external nonReentrant whenNotPaused onlyPortal {
        require(amount <= poolBalance, "[*ERROR*] Insufficient pool liquidity!");
        require(iCollateralManager.getHealthFactor(borrower) > 150, "[*ERROR*] Health factor too low to borrow more money!");

        // calculate interest as 10% of borrowed amount
        uint256 interest = (amount * 10) / 100; // 10% interest
        uint256 newLoan = amount + interest;
        uint256 oldTotalDebt = totalBorrowedUsers[borrower];
        uint256 newTotalDebt = oldTotalDebt + newLoan;

        // check hf for new loan
        uint256 collateralValue = iCollateralManager.getCollateralValue(borrower);
        uint256 newHealthFactor = calculateHealthFactor(borrower,newTotalDebt, collateralValue);

        require(newHealthFactor > 150, "[*ERROR*] New health factor too low to borrow more money!");

        poolBalance -= amount;

        if (isBorrower(borrower)) {
            totalBorrowedUsers[borrower] += newLoan;
            netBorrowedUsers[borrower] += amount;
        } else {
            addBorrowerIfNotExists(borrower, newLoan);
            netBorrowedUsers[borrower] += amount;
        }

        // send eth to borrower
        (bool success, ) = borrower.call{value: amount}("");
        require(success, "[*ERROR*] Transfer of debt tokens failed!");
        
        emit Borrowed(borrower, amount);
    }

    // @Helper
    function calculateHealthFactor(address borrower, uint256 debtValue, uint256 collateralValue) private returns (uint256) {
        if (debtValue == 0) return type(uint256).max; // Infinite health factor if no debt
        require(collateralValue <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (collateralValue * 100) / debtValue;
    }

    // Allows users to repay borrowed ETH with interest
    function repay(address borrower, uint256 amount) external payable onlyPortal {
        require(isBorrower(borrower), "[*ERROR*] No debt to repay!");
        require(amount > 0, "[*ERROR*] Contains no value");

        uint256 totalDebt = totalBorrowedUsers[borrower];
        uint256 netDebt = netBorrowedUsers[borrower];
        require(amount <= totalDebt, "[*ERROR*] Amount exceeds total debt");

        if (amount >= netDebt) {
            // Calculate the excess amount (interest)
            uint256 interest = amount - netDebt;
            // Clear the net debt and reduce total debt by the amount
            netBorrowedUsers[borrower] = 0;
            totalBorrowedUsers[borrower] -= amount;

            // Allocate the interest if any
            if (interest > 0) {
                allocateInterest(interest);
            }

            if ( netBorrowedUsers[borrower] == 0 && totalBorrowedUsers[borrower] == 0) {
                deleteBorrower(borrower);
            }

        } else {
            // If the repayment is less than netDebt, only reduce netDebt
            netBorrowedUsers[borrower] -= amount;
            totalBorrowedUsers[borrower] -= amount;
        }

        poolBalance += amount;

        emit Repaid(borrower, amount);
    }

    // Liquidates an NFT if the health factor drops below 1.2
    // this function is called by CM who transfers eth to Pool and this function updates LendPool accordingly
    // TODO update according to liquidate in CM
    function liquidate(address borrower, address collection, uint256 tokenId, uint256 amount) external onlyTrader {
        // check healthfactor ready to liquidate
        uint256 healthFactor = iCollateralManager.getHealthFactor(borrower);
        require(healthFactor < 120, "[*ERROR*] Health factor is sufficient, cannot liquidate!");

        // get the nftValue
        uint256 nftValue = iCollateralManager.getNftValue(collection);

        // TODO does the trader do the listing??
        iCollateralManager.liquidateNft(borrower, collection, tokenId);

        uint256 totalDebt = totalBorrowedUsers[borrower];

        // debt is repaid with liquidated amount
        repay(borrower,amount);

        emit Liquidated(borrower, tokenId, 0);
    }

    // Retrieve user account data including LP and DB tokens
    function getUserAccountData(address user) public view returns (
        uint256 totalDebt,
        uint256 netDebt,
        uint256 totalSupplied
    ) {
        totalDebt = totalBorrowedUsers[user];
        netDebt = netBorrowedUsers[user];
        totalSupplied = totalSuppliedUsers[user];
        return (totalDebt, netDebt, totalSupplied);
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

    function getBorrowersList() public view returns (address[] memory) {
        return borrowers;
    }
}
