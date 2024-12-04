// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAddresses {

    event AddressUpdated(string indexed name, address indexed newAddress);

    function setAddress(string memory name, address newAddress) external;

    function getAddress(string memory name) external view returns (address);
}