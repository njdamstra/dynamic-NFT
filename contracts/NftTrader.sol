// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct. // should we not use tokenId instead of nttId as uint256? -F
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public poolBalances; //dont understand this mapping why do we track balances of users? -F
    // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated
    struct Listing {
        address seller; // in the case of one llending pool, this will always be the same (CM)
        uint256 basePrice;
        uint256 startTimeStamp; // when listing was created
        uint256 duration; 
        uint256 highestBid;
        address highestBidder;
        bool buyNow; // if auction duration has passed, then the liquidator can buy immediately at basePrice
    }


    address public collateralManager;
    constructor(address _collateralManager, address _pool) {
        collateralManager = _collateralManager; // caller of contract is the owner of the NFT
        // must make this the address of the collateralManager
        pool = _pool // where we transfer money to
    }

    modifier onlyCollateralManager() {
        require(msg.sender == collateralManager, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    // Events for transparency
    event NFTListed(address indexed collection, uint256 indexed tokenId, uint256 price, address seller);
    event NFTDelisted(address indexed collection, uint256 indexed tokenId);
    event NFTPurchased(address indexed collection, uint256 indexed tokenId, uint256 price, address buyer);
    event Withdrawal(address indexed destination, uint256 amount);

    // Add an NFT listing
    function addListing(uint256 basePrice, address collection, uint256 tokenId) public onlyCollateralManager {
        ERC721 token = ERC721(collection);
        // Ensure the NFT is owned and approved by the collateralManager
        require(token.ownerOf(tokenId) == collateralManager, "[*ERROR*] Caller must own the NFT!");
        require(token.isApprovedForAll(collateralManager, address(this)), "[*ERROR*] Contract is not approved!");
        // Add the listing
        listings[collection][tokenId] = Listing(collateralManager, price);
        emit NFTListed(collection, tokenId, price, collateralManager);
    }

    // Delist an NFT
    function delist(address collection, uint256 tokenId) public onlyCollateralManager {
        require(listings[collection][tokenId].price > 0, "[*ERROR*] NFT is not listed!");

        // Remove the listing
        delete listings[collection][tokenId];

        emit NFTDelisted(collection, tokenId);
    }

    // TODO: 
    function activeAuction(Listing listing) public view returns (bool) {

    }

    //TODO: liquidate at highest bid
    function endAuction(Listing listing) {
        // called only if auction duration has been completed.
        // if there is a bid, automatically transfer NFT to highest bidders address
        // if no bid made, change buyNow bool from false to true

    }
    // TODO
    function viewListing() public view returns (struct) {
    }

    // TODO
    function redunancyCheck() {}

    //TODO 
    function checkIfSold() {}

    // purchase an NFT (user purchases from CollateralManager) ??-F
    function purchase(address collection, uint256 tokenId) public payable {
        Listing memory item = listings[collection][tokenId];
        require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        require(msg.value >= item.price, "[*ERROR*] Insufficient funds!");

        uint256 overpayment = msg.value - item.price;

        // Update balances and transfer NFT
        balances[item.seller] += item.price; // should the money not go to the pool?

        ERC721 token = ERC721(collection);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);

        // Remove the listing
        delete listings[collection][tokenId];

        // Refund overpayment if any //TODO pay pool instead of refund
        if (overpayment > 0) {
            (bool refundSuccess, ) = item.seller.call{value: overpayment}("");
            require(refundSuccess, "[*ERROR*] Refund failed!");
        }

        emit NFTPurchased(collection, tokenId, item.price, msg.sender);
    }

    // Withdraw funds
    function withdraw(uint256 amount, address payable destinationAddress) public onlyCollateralManager {
        require(amount <= balances[collateralManager], "[*ERROR*] Insufficient funds!");

        balances[collateralManager] -= amount;

        (bool success, ) = destinationAddress.call{value: amount}("");
        require(success, "[*ERROR*] Withdrawal failed!");

        emit Withdrawal(destinationAddress, amount);
    }

   receive() external payable {}

}