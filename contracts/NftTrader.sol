// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct. // should we not use tokenId instead of nttId as uint256? -F
    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(address => uint256) public balances;
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

    function addListing(uint256 price, address contractAddress, uint256 tokenId) public onlyCollateralManager {
        ERC721 token = ERC721(contractAddress);
        require(token.ownerOf(tokenId) == collateralManager, "[*ERROR*] Caller (CollateralManager) must own given token!");
        require(token.isApprovedForAll(collateralManager, address(this)), "[*ERROR*] Contract is not approved!"); //what is operator for? -F

        listings[contractAddress][tokenId] = Listing(collateralManager, price); // collateralManager is always the Listing.seller
    }

    function purchase(address contractAddress, uint256 tokenId) public payable {
        Listing memory item = listings[contractAddress][tokenId];

        require(item.price > 0, "[*ERROR*] NFT not listed for sale!");
        uint256 amount = msg.value;
        require(amount >= item.price, "[*ERROR*] Insufficient funds sent!"); // msg.value is the amount the purchaser is trying to buy the NFT with
        balances[item.seller] += amount; // update collateralManagers value with the price of the NFT being sold! //wouldn't the value (balance) go down since we buy a NFT?

        ERC721 token = ERC721(contractAddress);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);

        delete listings[contractAddress][tokenId];
        withdraw(amount, collateralManager); //sends money from purchase from this contract to the Lending CollateralManager contract

    }

    function withdraw(uint256 amount, address payable destinationAddress) public {
        require(amount <= balances[collateralManager], "[*ERROR*] Insufficient funds!");
        // require(amount <= balances[msg.sender], "insufficient funds");

        // balances[msg.sender] -= amount;
        balances[collateralManager] -= amount;

        (bool success, ) = destinationAddress.call{value: amount}("");
        require(success, "[*ERROR*] Transfer to collateralManager failed!");
   }

   receive() external payable {}

}