// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract GoodNFT is ERC721 {
    uint256 public currentTokenId;

    constructor() ERC721("GoodNFT", "GNFT") {}

    // Mint an NFT
    function mint(address to) external {
        _safeMint(to, currentTokenId);
        currentTokenId++;
    }
}