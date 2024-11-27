// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftTrader {
    // map original nft contract address to mapping of nftid to Listing struct.
    mapping(address => mapping(uint256 => Listing)) public listings;
    // Listing struct has the price and seller (Pool contract) of the nft to be liquidated
    struct Listing {
        uint256 price;
        address seller;
    }

    address public pool;
    constructor(address _pool) {
        pool = _pool; // caller of contract is the owner of the NFT
        // must make this the address of the pool
    }

    modifier onlyPool() {
        require(msg.sender == pool, "[*ERROR*] Only the pool can call this function!");
        _;
    }


    function addListing(uint256 price, address contractAddr, uint256 tokenId) public onlyPool {
        ERC721 token = ERC721(contractAddr);
        require(token.balanceOf(pool, tokenId) > 0, "Caller must own given token");
        require(token.isApprovedForAll(pool, address(this)), "contract must be approved");

        listings[contractAddr][tokenId] = Listing(price, pool); // pool is always the Listing.seller
    }

    function purchase(address contractAddr, uint256 tokenId) public payable {
        Listing memory item = listings[contractAddr][tokenId];
        uint256 amount = msg.value;
        require(msg.value >= item.price, "Insufficient funds sent"); // msg.value is the amount the purchaser is trying to buy the NFT with
        balances[item.seller] += msg.value; // update pools value with the price of the NFT being sold!

        ERC721 token = ERC721(contractAddr);
        token.safeTransferFrom(item.seller, msg.sender, tokenId);
        withdraw(amount, pool); //sends money from purchase from this contract to the LendingPool contract
    }

    function withdraw(uint256 amount, address payable destAddr) public {
        require(amount <= balances[pool], "insufficient funds");
        // require(amount <= balances[msg.sender], "insufficient funds");
        destAddr.transfer(amount);

        // balances[msg.sender] -= amount;
        balances[pool] -= amount;
   }


}