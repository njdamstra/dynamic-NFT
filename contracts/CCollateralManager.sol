// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {INftTrader} from "./interfaces/INftTrader.sol";
import {INftValues} from "./interfaces/INftValues.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IAddresses} from "./interfaces/IAddresses.sol";

contract CollateralManager is IERC721Receiver {
    struct CollateralProfile {
        // uint256 nftListLength;
        Nft[] nftList;
        bool isLiquidatable;
    }

    struct Nft {
        address collectionAddress;
        uint256 tokenId;
        IERC721 nftContract;
        bool isBeingLiquidated; // if NFT is currently being auctioned off or still hasn't been bought by liquidator
    }

    mapping(address => CollateralProfile) public borrowersCollateral;// Tracks users collateral profile for multiple nfts
    // mapping(address => Nft[]) public liquidatableCollateral; // borrowers address maps to there NFT list
    // mapping(address => mapping(uint256 => bool)) public isBeingLiquidated; // Tracks NFTs currently in liquidation

    address public owner;
    address public poolAddr;
    address public nftTraderAddress;
    address public nftValuesAddress;
    address public portal;
    INftValues public iNftValues;
    INftTrader public iNftTrader;
    ILendingPool public iLendingPool;

    address public addressesAddr;
    IAddresses public addresses;

    constructor(address _addressesAddr) {
        // unsure if pool will be deploying this contract or if we'll deploy it through the deploy script
        owner = msg.sender; // LendingPool is the owner
        addressesAddr = _addressesAddr;
        addresses = IAddresses(addressesAddr);
    }

    // Initialize function to set dependencies
    function initialize() external onlyOwner {
        // require(_pool != address(0) && _nftTrader != address(0) && _nftValues != address(0), "Invalid addresses");
        portal = addresses.getAddress("UserPortal");
        poolAddr = addresses.getAddress("LendingPool");
        nftTraderAddress = addresses.getAddress("NftTrader");
        nftValuesAddress = addresses.getAddress("NftValues");
        iNftTrader = INftTrader(nftTraderAddress);
        iNftValues = INftValues(nftValuesAddress);
        iLendingPool = ILendingPool(poolAddr);
    }

    modifier onlyPool() {
        require(msg.sender == poolAddr, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    modifier onlyPortal() {
        require(msg.sender == portal, "[*ERROR*] Only the pool can call this function!");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "[*ERROR*] Not the contract owner!");
        _;
    }
    // Events
    event NFTListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 valueListing, uint256 timestamp);
    event NFTDeListed(address indexed borrower, address indexed collection, uint256 tokenId, uint256 timestamp);
    event CollateralAdded(address indexed borrower, address indexed collection, uint256 tokenId, uint256 value, uint256 timestamp);
    event Liquidated(address indexed borrower, address indexed collectionAddress, uint256 tokenId, uint256 liquidated, uint256 timestamp);
    event CollateralRedeemed(address indexed borrower, address indexed collectionAddress, uint256 tokenId);
    event FailedToDelist(address indexed borrower, address indexed collection, uint256 tokenId, string reason);
    function isNftValid(address sender, address collection, uint256 tokenId) public view returns (bool) {
        IERC721 nft = IERC721(collection);
        if (nft.ownerOf(tokenId) != sender) return false;
        return true;
    }

    // Calculate the health factor for a user
    function getHealthFactor(address borrower) public returns (uint256) {
        uint256 totalCollateral = getCollateralValue(borrower);
        uint256 totalDebt = iLendingPool.getTotalBorrowedUsers(borrower);
        return calculateHealthFactor(totalDebt, totalCollateral);
    }

    function calculateHealthFactor(uint256 totalDebt, uint256 collateralValue) public view returns (uint256) {
        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(collateralValue <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (collateralValue * 75) / totalDebt; // 150 L2V
    }

    function calculateBorrowersHealthFactor(address borrower, uint256 collateralValue) public returns (uint256) {
        uint256 totalDebt = iLendingPool.getTotalBorrowedUsers(borrower);
        if (totalDebt == 0) return type(uint256).max; // Infinite health factor if no debt
        require(collateralValue <= type(uint256).max / 100, "[*ERROR*] Collateral value too high!");
        return (collateralValue * 75) / totalDebt;
    }

    function updateAllLiquidatableCollateral() external {
        address[] memory borrowerList = iLendingPool.getBorrowerList();
        for (uint256 i = 0; i < borrowerList.length; i++) {
            address borrower = borrowerList[i];
            updateLiquidatableCollateral(borrower);
        }
    }

    // This function is called only by the Pool after the Trader sold the NFT and called liquidate in the pool
    function liquidateNft(address borrower, address collectionAddress, uint256 tokenId, uint256 amount) public onlyPool {
        // 1. update borrowersCollateral
        _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);
        // 2. update liquidatableCollateral
        updateLiquidatableCollateral(borrower);
        // 3. emit event to show this NFT was liquidated!
        //TODO get actual timestamp
        emit Liquidated(borrower, collectionAddress, tokenId, amount, 1);
    }

    // @Helper for liquidateNft
    function _deleteNftFromCollateralProfile(
        address borrower,
        address collectionAddress,
        uint256 tokenId
    ) internal {
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftList.length;

        for (uint256 i = 0; i < length; i++) {
            Nft storage nft = collateralProfile.nftList[i];
            if (nft.collectionAddress == collectionAddress && nft.tokenId == tokenId) {
                // Swap the last element with the current element
                collateralProfile.nftList[i] = collateralProfile.nftList[length - 1];
                collateralProfile.nftList.pop(); // Remove the last element
                // collateralProfile.nftListLength--; // Decrement the count
                // delete isBeingLiquidated[collectionAddress][tokenId];
                break;
            }
        }
    }

    function addCollateral(address borrower, address collectionAddress, uint256 tokenId) public onlyPortal {
        // require(isNftValid(msg.sender, collectionAddress, tokenId), "[*ERROR*] NFT collateral is invalid!");
        // check whether borrower already exists
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftList.length;
        for (uint256 i = 0; i < length; i++) {
            require(!(
                collateralProfile.nftList[i].collectionAddress == collectionAddress && collateralProfile.nftList[i].tokenId == tokenId
                ), "[*ERROR*] Duplicate NFT in collateral!");
        }
        // uint256 nftValue = getNftValue(collectionAddress, tokenId);
        // if borrower does not exist yet, add him to the pool borrower mapping
        iLendingPool.addBorrowerIfNotExists(borrower);
        // CollateralProfile collateralProfile = CollateralProfile;
        // collateralProfile.nftListLength = 0;

        IERC721 nftContract = IERC721(collectionAddress);
        Nft memory nft = Nft(collectionAddress, tokenId, nftContract, false);
        collateralProfile.nftList.push(nft);
        // collateralProfile.nftListLength++;

        registerNft(collectionAddress, tokenId); // sends to NftValues to add to list of NFTs it keeps track of
        nftContract.approve(nftTraderAddress, tokenId); // Approves NftTrader to transfer NFT on CM's behalf -N

        // isBeingLiquidated[collectionAddress][tokenId] = false;
        emit CollateralAdded(borrower, collectionAddress, tokenId, 1, block.timestamp);
    }

    function redeemCollateral(address borrower, address collectionAddress, uint256 tokenId) public onlyPortal {
        uint256 healthFactor = getHealthFactor(borrower);
        // require(isNftValid(borrower, collectionAddress,tokenId), "[*ERROR* Nft not valid]");
        require(healthFactor > 100,"[*ERROR*] Health Factor has to be above 1.5 to redeem collateral!");

        // get a new List without the redeemed Nft
        // Nft[] memory nftListCopy = getNftList(borrower);
        // uint256 length = nftListCopy.length;

        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftList.length;

        bool found = false;
        // remove NFT from collateral profiles NFT List
        for (uint256 i = 0; i < length; i++) {
            Nft storage nft = collateralProfile.nftList[i];
            if (nft.collectionAddress == collectionAddress && nft.tokenId == tokenId) {
                // Swap with the last element and remove
                collateralProfile.nftList[i] = collateralProfile.nftList[length - 1];
                collateralProfile.nftList.pop();
                found = true;
                break;
            }
        }
        require(found, "NFT not found in collateral profile.");
        // Recalculate health factor after removing the NFT
        uint256 newCollateralValue = getCollateralValue(borrower);
        uint256 newHealthFactor = calculateBorrowersHealthFactor(borrower, newCollateralValue);
        require(newHealthFactor > 100, "[*ERROR*] Health Factor would fall below 1.2 after redemption!");

        // Proceed to redeem the NFT
        IERC721 nftContract = IERC721(collectionAddress);
        nftContract.transferFrom(address(this), borrower, tokenId);
        // _deleteNftFromCollateralProfile(borrower, collectionAddress, tokenId);

        emit CollateralRedeemed(borrower, collectionAddress, tokenId);
    }

    // Get the total value of all NFTs in a borrower's collateral profile
    function getNftList(address borrower) public view returns (Nft[] memory) {
        // CollateralProfile memory collateralProfile = borrowersCollateral[borrower];
        // return collateralProfile.nftList;
        CollateralProfile storage collateralProfile = borrowersCollateral[borrower];
        uint256 length = collateralProfile.nftList.length;
        Nft[] memory nftList = new Nft[](length);
        for (uint256 i = 0; i < length; i++) {
            nftList[i] = collateralProfile.nftList[i];
        }
        return nftList;
    }

    function getNftValue(address collectionAddress, uint256 tokenId) public view returns (uint256) {
        return iNftValues.getNftPrice(collectionAddress, tokenId);
    }

    function getListValue(Nft[] memory nftList) public view returns (uint256) {
        uint256 result = 0;
        for (uint i = 0; i < nftList.length; i++) {
            address collectionAddress = nftList[i].collectionAddress;
            uint256 tokenId = nftList[i].tokenId;
            result += getNftValue(collectionAddress, tokenId); // Accumulate the value of each NFT
        }
        return result;
    }

    function getCollateralValue(address borrower) public view returns (uint256) {
        Nft[] memory nftList = getNftList(borrower);
        return getListValue(nftList);
    }

    function addTradeListing(address borrower, address collection, uint256 tokenId) private {
        uint256 basePrice = getBasePrice(collection, tokenId);
        // determine basePrice calculation.
        uint256 duration = 20000; // 20000 seconds
        iNftTrader.addListing(basePrice, collection, tokenId, true, duration, borrower);

        //TODO emit NFTListed event
        emit NFTListed(borrower, collection, tokenId, basePrice, block.timestamp);
    }

    function delistTrade(address borrower, address collection, uint256 tokenId) private {
        uint traderState = iNftTrader.listingState(collection, tokenId);
        if (traderState == 0 || traderState == 3) {
            iNftTrader.delist(collection, tokenId);
            uint stateAfter = iNftTrader.listingState(collection, tokenId);
            if (stateAfter != 2) {
                emit FailedToDelist(borrower, collection, tokenId, "Internal Error");
            } else {
                emit NFTDeListed(borrower, collection, tokenId, block.timestamp);
            }
        } else if (traderState == 1) {
            emit FailedToDelist(borrower, collection, tokenId, "Bought");
        } else if (traderState == 2) {
            emit FailedToDelist(borrower, collection, tokenId, "Not Listed");
        } else {
            emit FailedToDelist(borrower, collection, tokenId, "Unrecognized Reason");
        }
        // } else if (traderState == 3) {
        //     emit FailedToDelist(borrower, collection, tokenId, "Has A Bid");
        // }
    }

    function getBasePrice(address collection, uint256 tokenId) public view returns (uint256) {
        uint256 price = getNftValue(collection, tokenId);
        return (price * 95) / 100;
    }
    function registerNft(address collection, uint256 tokenId) private {
        iNftValues.addNft(collection, tokenId);
    }
    // for testing
    function getCollateralProfile(address borrower) external view returns (CollateralProfile memory) {
        return borrowersCollateral[borrower];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getBeingLiquidated(address borrower) public view returns (bool) {
        return borrowersCollateral[borrower].isLiquidatable;
    }

    ///////// ***** NEW NFT LIQUIDATION MECHANISM ******** ///////////

    function updateLiquidatableCollateral(address borrower) private {
        uint256 healthFactor = getHealthFactor(borrower);
        CollateralProfile storage profile = borrowersCollateral[borrower];
        uint256 nftListLength = profile.nftList.length;

        if (healthFactor < 100) {
            // Determine the minimal set of NFTs to liquidate
            (Nft[] memory nftsToLiquidate, Nft[] memory nftsNotToLiquidate) = getNFTsToLiquidate(borrower);
            // Mark selected NFTs as being liquidated
            for (uint256 i = 0; i < nftListLength; i++) {
                Nft storage item = profile.nftList[i];
                bool liquidate = false;
                for (uint256 j = 0; j < nftsToLiquidate.length; j++) {
                    Nft memory nft = nftsToLiquidate[j];
                    if (
                        item.collectionAddress == nft.collectionAddress &&
                        item.tokenId == nft.tokenId
                    ) {
                        liquidate = true;
                        if (!item.isBeingLiquidated) {
                            item.isBeingLiquidated = true;
                            addTradeListing(borrower, item.collectionAddress, item.tokenId);
                        }
                        break;
                    }
                }
                if (!liquidate) {
                    for (uint256 j = 0; j < nftsNotToLiquidate.length; j++) {
                        Nft memory nft = nftsNotToLiquidate[j];
                        if (
                            item.collectionAddress == nft.collectionAddress &&
                            item.tokenId == nft.tokenId
                        ) {
                            if (item.isBeingLiquidated) {
                                item.isBeingLiquidated = false;
                                delistTrade(borrower, item.collectionAddress, item.tokenId);
                            }
                            break;
                        }
                    }
                }
            }
            profile.isLiquidatable = true;
        } else {
            // Delist NFTs that were being liquidated
            for (uint256 i = 0; i < nftListLength; i++) {
                Nft storage item = profile.nftList[i];
                if (item.isBeingLiquidated) {
                    delistTrade(borrower, item.collectionAddress, item.tokenId);
                    item.isBeingLiquidated = false;
                }
            }
            profile.isLiquidatable = false;
        }
    }

    function getNFTsToLiquidate(address borrower) public view returns (Nft[] memory nftsToLiquidate, Nft[] memory nftsNotToLiquidate) {
        uint256 totalDebt = iLendingPool.getTotalBorrowedUsers(borrower);
        //console.log("initial Total debt: %s", totalDebt);
        Nft[] memory nftList = getNftList(borrower);
        uint256 nftCount = nftList.length;
        //console.log("nftCount: %s", nftCount);
        uint256 collateralValue = getListValue(nftList);
        //console.log("initial total collateralValue: %s", collateralValue);
        uint256 healthFactor = calculateHealthFactor(totalDebt, collateralValue);
        //console.log("initial health factor: %s", healthFactor);
        // If health factor is already >= 120, no need to liquidate
        if (healthFactor >= 100) {
            Nft[] memory emptyNft = new Nft[](0);
            return (emptyNft, nftList); // Return empty array
        }
        // Prepare array to store NFTs to liquidate
        Nft[] memory nftsToLiquidate = new Nft[](nftCount);
        uint256 nftsToLiquidateCount = 0;
        Nft[] memory nftsNotToLiquidate = new Nft[](nftCount);
        uint256 nftsNotToLiquidateCount = 0;

        Nft[] memory sortedNfts = sortNftsByValueDescending(nftList);
        uint256 updatedCollateralValue = collateralValue;
        uint256 updatedTotalDebt = totalDebt;
        // Iterate over NFTs to determine which ones to liquidate
        for (uint256 i = 0; i < nftCount; i++) {
            Nft memory nft = sortedNfts[i];
            // uint256 nftSoldPrice = getNftValue(nft.collectionAddress, nft.tokenId);
            uint256 nftSoldPrice = getBasePrice(nft.collectionAddress, nft.tokenId);
            console.log("Evaluating NFT tokenId: %s with sold price: %s", nft.tokenId, nftSoldPrice);

            uint256 currentHealthFactor = calculateHealthFactor(updatedTotalDebt, updatedCollateralValue);

            // Liquidate this NFT if the current health factor is still below 100
            if (currentHealthFactor < 100) {
                nftsToLiquidate[nftsToLiquidateCount] = nft;
                nftsToLiquidateCount++;

                // Simulate liquidation
                updatedCollateralValue = updatedCollateralValue > nftSoldPrice ? (updatedCollateralValue - nftSoldPrice) : 0;
                uint256 debtReduction = nftSoldPrice > updatedTotalDebt ? updatedTotalDebt : nftSoldPrice;
                updatedTotalDebt = updatedTotalDebt > debtReduction ? (updatedTotalDebt - debtReduction) : 0;

                console.log("After liquidation - updated collateral value: %s", updatedCollateralValue);
                console.log("After liquidation - updated total debt: %s", updatedTotalDebt);
                console.log("After liquidation - updated health factor: %s", calculateHealthFactor(updatedTotalDebt, updatedCollateralValue));
            } else {
                // If health factor is restored, add remaining NFTs to `nftsNotToLiquidate`
                nftsNotToLiquidate[nftsNotToLiquidateCount] = nft;
                nftsNotToLiquidateCount++;
            }
        }
        // Resize the array;
        Nft[] memory finalNftsToLiquidate = resizeNftArray(nftsToLiquidate, nftsToLiquidateCount);
        Nft[] memory finalNftsNotToLiquidate = resizeNftArray(nftsNotToLiquidate, nftsNotToLiquidateCount);
        return (finalNftsToLiquidate, finalNftsNotToLiquidate);
    }

    function sortNftsByValueDescending(Nft[] memory nfts) internal view returns (Nft[] memory) {
        uint256 n = nfts.length;
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                uint256 valueI = getNftValue(nfts[i].collectionAddress, nfts[i].tokenId);
                uint256 valueJ = getNftValue(nfts[j].collectionAddress, nfts[j].tokenId);
                if (valueI < valueJ) {
                    // Swap
                    Nft memory temp = nfts[i];
                    nfts[i] = nfts[j];
                    nfts[j] = temp;
                }
            }
        }
        return nfts;
    }

    // Helper function to resize the arrays
    function resizeNftArray(
        Nft[] memory nftArray,
        uint256 arrayCount
    ) internal pure returns (Nft[] memory) {
        Nft[] memory newArray = new Nft[](arrayCount);
        for (uint256 i = 0; i < arrayCount; i++) {
            newArray[i] = nftArray[i];
        }
        return newArray;
    }
}
