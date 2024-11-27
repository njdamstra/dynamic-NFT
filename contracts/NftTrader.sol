// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct.
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public balances;
    // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated
    struct Listing {
        uint256 price;
        address seller;
    }

    address public collateralManager;
    constructor(address _collateralManager) {
        collateralManager = _collateralManager; // caller of contract is the owner of the NFT
        // must make this the address of the collateralManager
    }

    modifier onlycollateralManager() {
        require(msg.sender == collateralManager, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }


    function addListing(uint256 price, address contractAddr, uint256 tokenId) public onlycollateralManager {
        ERC721 token = ERC721(contractAddr);
        require(token.ownerOf(tokenId) == collateralManager, "Caller must own given token");
        require(token.isApprovedForAll(collateralManager, address(this)), "contract must be approved");

        listings[contractAddr][tokenId] = Listing(price, collateralManager); // collateralManager is always the Listing.seller
    }

    function purchase(address contractAddr, uint256 tokenId) public payable {
        Listing memory item = listings[contractAddr][tokenId];

        require(item.price > 0, "NFT not listed for sale");
        uint256 amount = msg.value;
        require(msg.value >= item.price, "Insufficient funds sent"); // msg.value is the amount the purchaser is trying to buy the NFT with
        balances[item.seller] += msg.value; // update collateralManagers value with the price of the NFT being sold!

        ERC721 token = ERC721(contractAddr);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);

        delete listings[contractAddr][tokenId];
        withdraw(amount, collateralManager); //sends money from purchase from this contract to the LendingcollateralManager contract

    }

    function withdraw(uint256 amount, address payable destAddr) public {
        require(amount <= balances[collateralManager], "insufficient funds");
        // require(amount <= balances[msg.sender], "insufficient funds");

        // balances[msg.sender] -= amount;
        balances[collateralManager] -= amount;

        (bool success, ) = destAddr.call{value: amount}("");
        require(success, "Transfer to collateralManager failed");
   }

   receive() external payable {}

}