# EIP‑7702 Delegation Front‑Running PoC

## Overview

This PoC is prepared as a part of the World Chain PBH CTF Challenge. It demonstrates a front‑running griefing attack in the current implementation by leveraging EIP‑7702 delegation.


In short, the PBH builder attempts to ensure that calls into the `PBHEntryPoint` come only from `tx.origin` (msg.sender == tx.origin). However, EIP‑7702 delegation allows for EOA's to upgrade their account to a contract and this breaks the assumption that when `msg.sender == tx.origin` then `msg.sender` is not a contract. This, combined with the fact that the nullifier hash is visible in the public sometimes (e.g. in 4337 operations), creates a subtle vulnerability that allows an attacker to front-run and "spend" a nullifier from another proof. 

I'm not actually sure why you would want to do this, but it's a fun attack.

## The Vulnerability

From the team in telegram:

> "It's front running protection on the nullifierHashes mapping. Since the PBHEntryPoint does not verify the integrity of the proof before spending the nullifierHash there is a vulnerability where I can target the PBHEntryPoint at any point in the call trace and spend another proof's nullifierHash. This is especially important for 4337 ops where the nullifier hash may be in a public mempool. We enforce the tx.origin and the PBHSignatureAggregator are the only valid callers into the PBHEntryPoint within the EVM in the payload builder to prevent front running from happening."

In the PBH system, the `PBHEntryPoint` contract uses a `nullifierHashes` mapping to ensure that each proof’s nullifier is used only once (preventing replay attacks). However, because the contract does not verify the integrity of the proof before "spending" the nullifier hash, an attacker can front‑run the system.

Moreover, in parallel Worldchain leverages an offchain block builder that performs other checks to ensure system integrity. One of these checks happens in the `PBHCallTracer`. This enforces the invariant that calls into the PBHEntryPoint must come from the transaction origin (and equal to `msg.sender`). By doing so, the builder ensures that the `PBHEntryPoint` is not called by a contract.

However, [EIP‑7702](https://eips.ethereum.org/EIPS/eip-7702) delegation allows for EOA's to upgrade their account to a contract. When this happens, the `msg.sender` is the original EOA, but the code that gets executed is that of the delegate contract. Moreover, when paired with an EOA *calling their delegated contract themselves* we can create a scenario where:
* `tx.origin` is the original EOA
* `msg.sender` is **also** the contract that lives at the EOA's address
* `msg.sender == tx.origin`

All of this together means that we can craft a transaction that calls into the `PBHEntryPoint` via a smart contract, but which makes it past the `PBHCallTracer` - thereby allowing for an attacker to front-run and "spend" a nullifier from another proof.
## PoC Implementation

7702 is scheduled for inclusion in the [Isthmus](https://github.com/ethereum-optimism/specs/issues/516) hard fork.

Our repository includes three key contracts:

- **PBHEntryPointImplementation.sol**  
  A fake PBH contract that exposes a `pbhMulticall(uint256)` function which marks a nullifier as used in its `nullifierHashes` mapping. This isn't the same as the actual implementation, but it mirrors the actual contract's behavior for the purposes of this PoC.

- **PBHCaller.sol**  
  A simple contract that forwards a call to the target’s `pbhMulticall()` function.

- **EIP7702FrontRunDelegation.t.sol**  
  The Foundry test that demonstrates the frontrunning attack.

The test performs the following steps:

1. **Delegation Upgrade:**  
   Using Foundry’s `vm.signAndAttachDelegation`, Alice’s EOA is upgraded so that its code becomes that of PBHCaller.

2. **Frontrunning Attack:**  
   Alice then calls her upgraded account. The delegate code then calls `pbhMulticall(TEST_NULLIFIER)`, marking the nullifier as used.

3. **Legitimate User Rejection:**  
   When a legitimate user subsequently attempts to use the same nullifier (by calling `pbhMulticall()` directly), the transaction fails because the nullifier is already marked as used.

## Running the PoC

1. **Install Foundry:**  
   If you haven’t already, install Foundry by running:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Compile and Test:**  
   From the project root, run:
   ```bash
   forge test -vvv
   ```
   The test should pass, demonstrating that an attacker can mark a nullifier as used via EIP‑7702 delegation, thereby front‑running legitimate users.


If you re-create this attack, then make sure to add `evm_version = "prague"` to your `foundry.toml` file.

---

Thanks to the Worldchain team for the challenge and the helpful answers to my questions on Telegram, and the Quicknode team for their EIP‑7702 Foundry PoC which was quite helpful.