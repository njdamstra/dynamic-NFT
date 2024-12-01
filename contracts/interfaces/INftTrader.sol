// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftTrader {
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
        address buyer,
        uint256 timestamp
    );
    event NFTAuctionEnded(
        address indexed collection,
        uint256 indexed tokenId,
        address winner,
        uint256 finalPrice,
        uint256 timestamp
    );

    // Core Functions
    function initialize(address _collateralManagerAddr, address _pool) external;

    function addListing(
        uint256 basePrice,
        address collection,
        uint256 tokenId,
        bool auction,
        uint256 duration,
        address originalOwner
    ) external;

    function delist(address collection, uint256 tokenId) external;

    function placeBid(address bidder, address collection, uint256 tokenId) external payable;

    function endAuction(address collection, uint256 tokenId) external;

    function purchase(address buyer, address collection, uint256 tokenId) external payable;

    // Helper Functions
    function isListed(address collection, uint256 tokenId) external view returns (bool);

    function viewListing(address collection, uint256 tokenId) external view returns (
        address seller,
        address collectionAddr,
        uint256 token,
        uint256 basePrice,
        uint256 auctionStarted,
        uint256 auctionEnds,
        uint256 highestBid,
        address highestBidder,
        bool buyNow,
        address originalOwner
    );
}