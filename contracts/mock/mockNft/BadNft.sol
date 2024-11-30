// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BadNFT is ERC721 {
    uint256 public currentTokenId;

    constructor() ERC721("BadNFT", "BNFT") {}

    // Mint an NFT
    function mint(address to) external {
        _safeMint(to, currentTokenId);
        currentTokenId++;
    }
}