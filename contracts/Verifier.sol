// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


contract Verifier {
    function verify(address user) external pure returns (bool isValid) {
        // Simulate verification by checking if the user address is valid (non-zero)
        isValid = (user != address(0)); // Example condition: user cannot be the zero address
    }
}