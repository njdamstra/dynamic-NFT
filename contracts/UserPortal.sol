// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {INftTrader} from "./interfaces/INftTrader.sol";
import {INftValues} from "./interfaces/INftValues.sol";
import {ICollateralManager} from "./interfaces/ICollateralManager.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract UserPortal is ReentrancyGuard, IERC721Receiver {

    address public CMAddr;
    address public LPAddr;
    address public NTAddr;
    INftTrader public iTrader;
    ICollateralManager public iCollateralManager;
    ILendingPool public iPool;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor () {
        owner = msg.sender;
    }

    function initialize(address _CMAddr, address _LPAddr, address _NTAddr) external onlyOwner {
        CMAddr = _CMAddr;
        LPAddr = _LPAddr;
        NTAddr = _NTAddr;
        iTrader = INftTrader(NTAddr);
        iPool = ILendingPool(LPAddr);
        iCollateralManager = ICollateralManager(CMAddr);
    }

    // Fallback functions to receive ETH
    receive() external payable {}
    fallback() external payable {}



    /////////// ** LENDER FUNCTIONS ** /////////////

    function supply(uint256 amount) external payable nonReentrant {
        
        require(msg.value == amount, "Incorrect WEI amount sent!");
        require(msg.value > 0, "[*ERROR*] msg.value: Cannot send 0 WEI");
        require(amount > 0, "[*ERROR*] amount: Cannot send 0 WEI");
        // Forward ETH to LendingPool and call `supply`
        iPool.supply{ value: amount }(msg.sender, amount);
    }


    function withdraw(uint256 amount) external nonReentrant {
        iPool.withdraw(msg.sender, amount);
    }



    ////////// ** BORROWER FUNCTIONS ** ///////////

    function addCollateral(address collection, uint256 tokenId) external nonReentrant {
        IERC721 nft = IERC721(collection);
        // Ensure UserPortal is approved for the NFT
        require(nft.ownerOf(tokenId) == msg.sender, "User is not the owner of this Nft");
        require(nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)), "UserPortal not approved!");

        // Transfer the NFT from user to UserPortal
        nft.safeTransferFrom(msg.sender, CMAddr, tokenId);

        // Call addCollateral on CollateralManager
        iCollateralManager.addCollateral(msg.sender, collection, tokenId);
    }
    
    function borrow(uint256 amount) external nonReentrant {
        iPool.borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external payable {
        require(msg.value == amount, "Incorrect ETH amount sent!");
        iPool.repay{value: amount}(msg.sender, amount);
    }

    function redeemCollateral(address collection, uint256 tokenId) external nonReentrant {
        // Call redeemCollateral on CollateralManager
        
        iCollateralManager.redeemCollateral(msg.sender, collection, tokenId);

        // Transfer NFT back to the user
        // IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
    }


    ///////////// ** LIQUIDATORS FUNCTIONS ** ////////////////

    function placeBid(address collection, uint256 tokenId) external payable nonReentrant {
        require(msg.value > 0, "Bid amount must be greater than 0");

        // Forward the ETH and call placeBid on NftTrader
        iTrader.placeBid{value: msg.value}(msg.sender, collection, tokenId);
    }

    function purchase(address collection, uint256 tokenId) external payable {
        require(msg.value > 0, "Purchase amount must be greater than 0");

        // Forward the ETH and call purchase on NftTrader
        iTrader.purchase{value: msg.value}(msg.sender, collection, tokenId);
    }

    function endAuction(address collection, uint256 tokenId) external {
        iTrader.endAuction(collection, tokenId);
    }


    //////// ** CONTRACT MANAGER FUNCTIONS ** ///////////
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }


}