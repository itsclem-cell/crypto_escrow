# Integration Examples

## Native asset escrow creation

Arguments:
- payer: buyer wallet
- payee: seller wallet
- asset: `0x0000000000000000000000000000000000000000`
- amount: escrow amount in wei
- releaseAfter: Unix timestamp
- refundAfter: Unix timestamp
- termsHash: `bytes32`

## ERC-20 escrow creation

Arguments are identical except `asset` is the token contract address.

The payer must then call `approve(escrowAddress, amount)` on the token before calling `depositToken()`.

## Ethers v6 example

```ts
const termsHash = ethers.keccak256(ethers.toUtf8Bytes(JSON.stringify(agreement)));

const tx = await factory.createEscrowCustom(
  payer,
  payee,
  arbiter,
  tokenAddress,
  treasury,
  amount,
  100,
  releaseAfter,
  refundAfter,
  termsHash
);

const receipt = await tx.wait();
```

## Event indexing

Relevant events:
- `EscrowCreated`
- `Deposited`
- `ReleaseApproved`
- `RefundApproved`
- `DisputeRaised`
- `Released`
- `Refunded`

Use these events to build a transaction ledger, operations dashboard, and dispute queue.
