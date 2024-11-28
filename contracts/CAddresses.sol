// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Addresses {
    event LendPoolUpdated(address indexed newAddress);
    event CollateralManagerUpdated(address indexed newAddress);
    event NftValuesUpdated(address indexed newAddress);
    event NftTraderUpdated(address indexed newAddress);
    event LPTokenUpdated(address indexed newAddress);
    event DBTokenUpdated(address indexed newAddress);

    function getLendPool() external view returns (address);

    function setLendPool(address addr) external;

    function getCollateralManager() external view returns (address);

    function setCollateralManager(address addr) external;

    function getNftValues() external view returns (address);

    function setNftValues(address addr) external;

    function getNftTrader() external view returns (address);

    function setNftTrader(address addr) external;

    function getLPToken() external view returns (address);

    function setLPToken(address addr) external;

    function getDBToken() external view returns (address);

    function setDBToken(address addr) external;
}