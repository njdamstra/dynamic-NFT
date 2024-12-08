// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {INftTrader} from "./interfaces/INftTrader.sol";
import {INftValues} from "./interfaces/INftValues.sol";
import {ICollateralManager} from "./interfaces/ICollateralManager.sol";
import {IAddresses} from "./interfaces/IAddresses.sol";
import {IMockOracle} from "./interfaces/IMockOracle.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract UserPortal is ReentrancyGuard, IERC721Receiver {

    address public CMAddr;
    address public LPAddr;
    address public NTAddr;
    address public NVAddr;
    INftTrader public iTrader;
    ICollateralManager public iCollateralManager;
    ILendingPool public iPool;
    INftValues public iNftValues;
    IMockOracle public iMockOracle;

    address public addressesAddr;
    IAddresses public addresses;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor (address _addressesAddr) {
        owner = msg.sender;
        addressesAddr = _addressesAddr;
        addresses = IAddresses(addressesAddr);
    }

    function initialize() external onlyOwner {
        CMAddr = addresses.getAddress("CollateralManager");
        LPAddr = addresses.getAddress("LendingPool");
        NTAddr = addresses.getAddress("NftTrader");
        NVAddr = addresses.getAddress("NftValues");
        iMockOracle = IMockOracle(addresses.getAddress("MockOracle"));

        iTrader = INftTrader(NTAddr);
        iPool = ILendingPool(LPAddr);
        iCollateralManager = ICollateralManager(CMAddr);
        iNftValues = INftValues(NVAddr);
    }

    // Fallback functions to receive ETH
    receive() external payable {}
    fallback() external payable {}


    // refreshes all contracts so that there state is fully updated.
    function refresh() public {
        iNftValues.requestNftOracleUpdates();
        iCollateralManager.updateAllLiquidatableCollateral();
        iPool.updateBorrowersInterest();
        iTrader.endAllConcludedAuctions();
    }

    function getPoolData() public view returns (
        uint256 poolBalance,
        bool paused
    ) {
        paused = iPool.paused();
        poolBalance = iPool.poolBalance();
        return (poolBalance, paused);
    }



    /////////// ** LENDER FUNCTIONS ** /////////////

    function supply(uint256 amount) external payable nonReentrant {
        refresh();
        require(msg.value == amount, "Incorrect WEI amount sent!");
        require(msg.value > 0, "[*ERROR*] msg.value: Cannot send 0 WEI");
        require(amount > 0, "[*ERROR*] amount: Cannot send 0 WEI");
        // Forward ETH to LendingPool and call `supply`
        iPool.supply{ value: amount }(msg.sender, amount);
    }


    function withdraw(uint256 amount) external nonReentrant {
        refresh();
        iPool.withdraw(msg.sender, amount);
    }

    function getLenderAccountData() public view returns (
        uint256 totalSupplied
    ) {
        ( , , totalSupplied, , )= iPool.getUserAccountData(msg.sender);
        return totalSupplied;
    }



    ////////// ** BORROWER FUNCTIONS ** ///////////

    function addCollateral(address collection, uint256 tokenId) external nonReentrant {
        refresh();
        IERC721 nft = IERC721(collection);
        // Ensure UserPortal is approved for the NFT
        require(nft.ownerOf(tokenId) == msg.sender, "User is not the owner of this Nft");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "UserPortal not approved!");

        // Transfer the NFT from user to UserPortal
        nft.safeTransferFrom(msg.sender, CMAddr, tokenId);

        // Call addCollateral on CollateralManager
        iCollateralManager.addCollateral(msg.sender, collection, tokenId);
    }
    
    function borrow(uint256 amount) external nonReentrant {
        refresh();
        iPool.borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external payable {
        refresh();
        require(msg.value == amount, "Incorrect ETH amount sent!");
        iPool.repay{value: amount}(msg.sender, amount);
    }

    function redeemCollateral(address collection, uint256 tokenId) external nonReentrant {
        // Call redeemCollateral on CollateralManager
        refresh();
        iCollateralManager.redeemCollateral(msg.sender, collection, tokenId);

        // Transfer NFT back to the user
        // IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function getBorrowerAccountData() public view returns (
        uint256 totalDebt,
        uint256 netDebt,
        uint256 collateralValue,
        uint256 healthFactor,
        uint256 periodicalInterest,
        uint256 lastUpdated,
        uint256 periodDuration
    ) {
        (totalDebt, netDebt, , collateralValue, healthFactor) = iPool.getUserAccountData(msg.sender);
        (periodicalInterest, , lastUpdated, periodDuration) = iPool.getInterestProfile(msg.sender);
        return (totalDebt, netDebt, collateralValue, healthFactor, periodicalInterest, lastUpdated, periodDuration);
    }


    ///////////// ** LIQUIDATORS FUNCTIONS ** ////////////////

    function placeBid(address collection, uint256 tokenId) external payable nonReentrant {
        refresh();
        require(msg.value > 0, "Bid amount must be greater than 0");

        // Forward the ETH and call placeBid on NftTrader
        iTrader.placeBid{value: msg.value}(msg.sender, collection, tokenId);
    }

    function purchase(address collection, uint256 tokenId) external payable {
        refresh();
        require(msg.value > 0, "Purchase amount must be greater than 0");

        // Forward the ETH and call purchase on NftTrader
        iTrader.purchase{value: msg.value}(msg.sender, collection, tokenId);
    }

    function getListings() public view returns (
        address[] memory collectionAddresses,
        uint256[] memory tokenIds
    ) {
        collectionAddresses = iTrader.getListingCollectionAddr();
        tokenIds = iTrader.getListingTokenIds();
        return (collectionAddresses, tokenIds);
    }

    function getListingData(address collectionAddress, uint256 tokenId) public view returns (
        uint256 basePrice,
        uint256 auctionStarted,
        uint256 auctionEnds,
        uint256 highestBid,
        bool buyNow
    ) {
        (basePrice, auctionStarted, auctionEnds, highestBid, buyNow) = iTrader.getListingData(collectionAddress, tokenId);
        return (basePrice, auctionStarted, auctionEnds, highestBid, buyNow);
    }


    //////// ** CONTRACT MANAGER FUNCTIONS ** ///////////
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }


}