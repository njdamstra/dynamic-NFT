// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftTrader {

    struct Listing {
        address seller; // in the case of one lending pool, this will always be the same (CM)
        address collection;
        uint256 tokenId;
        uint256 basePrice; // first bid has to be at least this amount
        uint256 auctionStarted; // when listing was created
        uint256 auctionEnds; // how long auction will last
        uint256 highestBid; // highest bid if one
        address highestBidder; // addr of the last bid
        bool buyNow; // if auction duration has passed, then the liquidator can buy immediately at basePrice
        address originalOwner;
    }
    // Events
    event NFTListed(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 basePrice,
        address seller,
        bool auction,
        uint256 timestamp
    );
    event NFTDelisted(address indexed collection, uint256 indexed tokenId, uint256 timestamp);
    event NFTPurchased(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 price,
        address indexed buyer,
        uint256 timestamp
    );
    event AuctionEndedWithNoWinner(address indexed collection, uint256 indexed tokenId);
    event AuctionWon(address indexed winner, address indexed collection, uint256 tokenId, uint256 amount);
    event NewBid(address indexed bidder, address indexed collection, uint256 tokenId, uint256 amount);

    // Core Functions
    function initialize() external;

    function addListing(
        uint256 basePrice,
        address collection,
        uint256 tokenId,
        bool auction,
        uint256 duration,
        address originalOwner
    ) external;

    function delist(address collection, uint256 tokenId) external;

    function endAllConcludedAuctions() external;

    function placeBid(address bidder, address collection, uint256 tokenId) external payable;

    function endAuction(address collection, uint256 tokenId) external;

    function purchase(address buyer, address collection, uint256 tokenId) external payable;

    // Helper Functions
    function isListing(address collection, uint256 tokenId) external view returns (bool);

    function listingState(address collection, uint256 tokenId) external view returns (uint);

    function getListing(address collection, uint256 tokenId) external view returns (Listing memory);
}