// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


interface ICollateralManager {

    struct Nft {
        address collectionAddress;
        uint256 tokenId;
        IERC721 nftContract;
        bool isLiquidatable; // Indicates if the NFT is eligible for liquidation
    }

    // Events
    event NFTListed(
        address indexed borrower,
        address indexed collection,
        uint256 tokenId,
        uint256 valueListing,
        uint256 timestamp
    );
    event NFTDeListed(
        address indexed collection,
        uint256 tokenId,
        uint256 timestamp
    );
    event CollateralAdded(
        address indexed borrower,
        address indexed collection,
        uint256 tokenId,
        uint256 value,
        uint256 timestamp
    );
    event Liquidated(
        address indexed borrower,
        address indexed collectionAddress,
        uint256 tokenId,
        uint256 liquidated,
        uint256 timestamp
    );

    // Initialization
    function initialize(
        address _pool,
        address _nftTrader,
        address _nftValues,
        address _portal
    ) external;

    // Public/External Read Functions
    function isNftValid(
        address sender,
        address collection,
        uint256 tokenId
    ) external view returns (bool);

    function getHealthFactor(address borrower) external returns (uint256);

    function getliquidatableCollateral(
        address borrower
    ) external returns (Nft[] memory); // Use `Nft[]` as per the contract.

    function getCollateralValue(address borrower) external view returns (uint256);

    function getBasePrice(
        address collection,
        uint256 tokenId
    ) external returns (uint256);

    // Collateral Management
    function addCollateral(
        address borrower,
        address collectionAddress,
        uint256 tokenId
    ) external;

    function redeemCollateral(
        address borrower,
        address collectionAddress,
        uint256 tokenId
    ) external;

    // Liquidation
    function liquidateNft(
        address borrower,
        address collectionAddress,
        uint256 tokenId,
        uint256 amount
    ) external;

    function getNftValue(
        address collectionAddress
    ) external returns (uint256);

}
