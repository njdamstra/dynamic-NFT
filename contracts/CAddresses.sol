// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Addresses {
    address public owner;

    // Mapping to store contract names to their addresses
    mapping(string => address) private addresses;

    event AddressUpdated(string indexed name, address indexed newAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender; // The deployer is the owner
    }

    // Function to set an address for a given contract name
    function setAddress(string memory name, address newAddress) external onlyOwner {
        require(newAddress != address(0), "Invalid address");
        addresses[name] = newAddress;
        emit AddressUpdated(name, newAddress);
    }

    // Function to get an address for a given contract name
    function getAddress(string memory name) external view returns (address) {
        address addr = addresses[name];
        require(addr != address(0), "Address not found");
        return addr;
    }

    // Function to transfer ownership if needed
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}