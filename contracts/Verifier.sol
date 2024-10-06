// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Verifier {
    /**
     * @dev Verifies the zkProof by comparing the keccak256 hash of the proof to the document hash.
     * @param zkProof The zero-knowledge proof, represented as a byte array.
     * @param documentHash The expected document hash that should match the zkProof.
     * @return isValid True if the zkProof corresponds to the documentHash, false otherwise.
     */
    function verify(bytes memory zkProof, bytes32 documentHash) external pure returns (bool isValid) {
        // Simulate verification by checking if keccak256(zkProof) == documentHash
        bytes32 proofHash = keccak256(zkProof);
        isValid = (proofHash == documentHash);
    }
}
