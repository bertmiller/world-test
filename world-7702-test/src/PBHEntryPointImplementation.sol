// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/console.sol";

contract PBHEntryPointImplementation {
    // This mapping records used nullifiers.
    mapping(uint256 => bool) public nullifierHashes;

    event PBH(address indexed sender, uint256 signalHash, uint256 nullifierHash);

    constructor() {
    }

    /// @notice Simulated PBH function that writes to the nullifierHashes mapping.
    /// In a real contract, additional payload decoding and proof checks would be here.
    function pbhMulticall(uint256 nullifierHash) external {
        require(msg.sender == tx.origin, "pbhMulticall must be called by the origin of the transaction");
        // In our simplified PoC, we simply require that the nullifier was not used
        require(!nullifierHashes[nullifierHash], "Nullifier already used");
        // Record the nullifier as used.
        nullifierHashes[nullifierHash] = true;
        emit PBH(msg.sender, 0, nullifierHash);
    }
}
