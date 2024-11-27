// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct. // should we not use tokenId instead of nttId as uint256? -F
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public balances; //dont understand this mapping why do we track balances of users? -F
    // Listing struct has the price and seller (collateralManager contract) of the nft to be liquidated
    struct Listing {
        address seller;
        uint256 price;
    }

    address public collateralManager;
    constructor(address _collateralManager) {
        collateralManager = _collateralManager; // caller of contract is the owner of the NFT
        // must make this the address of the collateralManager
    }

    modifier onlyCollateralManager() {
        require(msg.sender == collateralManager, "[*ERROR*] Only the collateralManager can call this function!");
        _;
    }

    // Events for transparency
    event NFTListed(address indexed contractAddress, uint256 indexed tokenId, uint256 price, address seller);
    event NFTDelisted(address indexed contractAddress, uint256 indexed tokenId);
    event NFTPurchased(address indexed contractAddress, uint256 indexed tokenId, uint256 price, address buyer);
    event Withdrawal(address indexed destination, uint256 amount);

    // Add an NFT listing
    function addListing(uint256 price, address contractAddress, uint256 tokenId) public onlyCollateralManager {
        ERC721 token = ERC721(contractAddress);

        // Ensure the NFT is owned and approved by the collateralManager
        require(token.ownerOf(tokenId) == collateralManager, "[*ERROR*] Caller must own the NFT!");
        require(token.isApprovedForAll(collateralManager, address(this)), "[*ERROR*] Contract is not approved!");

        // Add the listing
        listings[contractAddress][tokenId] = Listing(collateralManager, price);

        emit NFTListed(contractAddress, tokenId, price, collateralManager);
    }

    // Delist an NFT
    function delist(address contractAddress, uint256 tokenId) public onlyCollateralManager {
        require(listings[contractAddress][tokenId].price > 0, "[*ERROR*] NFT is not listed!");

        // Remove the listing
        delete listings[contractAddress][tokenId];

        emit NFTDelisted(contractAddress, tokenId);
    }

    // purchase an NFT (user purchases from CollateralManager) ??-F
    function purchase(address contractAddress, uint256 tokenId) public payable {
        Listing memory item = listings[contractAddress][tokenId];
        require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        require(msg.value >= item.price, "[*ERROR*] Insufficient funds!");

        uint256 overpayment = msg.value - item.price;

        // Update balances and transfer NFT
        balances[item.seller] += item.price; // should the money not go to the pool?

        ERC721 token = ERC721(contractAddress);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);

        // Remove the listing
        delete listings[contractAddress][tokenId];

        // Refund overpayment if any //TODO pay pool instead of refund
        if (overpayment > 0) {
            (bool refundSuccess, ) = item.seller.call{value: overpayment}("");
            require(refundSuccess, "[*ERROR*] Refund failed!");
        }

        emit NFTPurchased(contractAddress, tokenId, item.price, msg.sender);
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