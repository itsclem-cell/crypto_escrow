# Architecture

## Core contracts

### EscrowFactory
Creates new escrow contracts, stores registry data, and manages default treasury, arbiter, and fee settings.

### Escrow
One contract per escrow. Supports:
- native asset settlement using `address(0)`
- ERC-20 settlement using token address
- dual release approval
- dual refund approval
- dispute escalation
- arbiter resolution
- release and refund deadlines
- fee collection
- immutable commercial terms via `termsHash`

## State machine

`AwaitingDeposit -> Funded -> Released`

`AwaitingDeposit -> Funded -> Refunded`

`Funded -> Disputed -> Released`

`Funded -> Disputed -> Refunded`

`AwaitingDeposit -> Cancelled`

## Commercial model

The contract stores:
- payer
- payee
- arbiter
- asset
- principal amount
- fee recipient
- fee amount
- release deadline
- refund deadline
- hashed off-chain terms

## Recommended off-chain flow

1. Draft and sign commercial terms off-chain.
2. Hash the canonical terms file.
3. Create escrow through factory.
4. Payer funds escrow.
5. Parties approve release or refund, or a timeout/dispute path is used.
6. Index contract events in the backend for reporting and reconciliation.

## Terms hashing

Use a canonical JSON or PDF digest. Example:
- SHA-256 of a JSON agreement document
- convert or map to `bytes32` when creating the escrow

The hash allows the on-chain escrow to reference a fixed off-chain agreement without storing the full document on-chain.
