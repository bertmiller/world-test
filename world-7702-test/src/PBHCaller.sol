// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPBHEntryPoint {
    function pbhMulticall(uint256 nullifierHash) external;
}

/**
 * @title PBHCaller
 * @notice A storage-less contract used for EIP‑7702 delegation.
 * It contains a function that accepts a target address and a nullifier,
 * then calls pbhMulticall() on that target.
 */
contract PBHCaller {
    /// @notice Forwards the call to pbhMulticall on the provided target.
    function callPBH(address target, uint256 nullifier) external {
        IPBHEntryPoint(target).pbhMulticall(nullifier);
    }
}
