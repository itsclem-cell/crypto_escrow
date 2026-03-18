# EVM Escrow Suite

Production-grade escrow contracts for EVM-compatible chains.

This repository includes:
- native asset escrow support
- ERC-20 escrow support
- dual-party release and refund approval
- dispute escalation to an arbiter
- release and refund deadlines
- fee collection
- factory deployment and registry
- tests, deployment script, and public repo documentation

## Repository structure

```text
contracts/
  core/
    Escrow.sol
    EscrowFactory.sol
    MockERC20.sol
  interfaces/
    IEscrow.sol
  utils/
    AssetLib.sol
scripts/
  deploy.ts
test/
  EscrowFactory.test.ts
docs/
  architecture.md
  security.md
  api-examples.md
```

## Quick start

### 1. Install dependencies

```bash
npm install
```

### 2. Compile

```bash
npm run build
```

### 3. Run tests

```bash
npm test
```

### 4. Configure deployment

Copy `.env.example` to `.env` and fill in:

```bash
cp .env.example .env
```

Required variables:
- `DEPLOYER_PRIVATE_KEY`
- `ALCHEMY_API_KEY`
- `OWNER_ADDRESS`
- `TREASURY_ADDRESS`
- `DEFAULT_ARBITER_ADDRESS`

### 5. Deploy

Sepolia:

```bash
npm run deploy:sepolia
```

Base Sepolia:

```bash
npm run deploy:base-sepolia
```

## Contract model

Each escrow is its own contract with immutable commercial terms set at creation:
- payer
- payee
- arbiter
- asset
- amount
- fee recipient
- fee amount
- release deadline
- refund deadline
- terms hash

### Native asset
Use `address(0)` as the asset and fund using `depositNative()`.

### ERC-20 asset
Use the token address and fund using `approve()` then `depositToken()`.

## Core workflows

### Release path
1. Payer deposits funds.
2. Payer and payee both approve release.
3. Contract sends net amount to payee and fee to treasury.

### Refund path
1. Payer deposits funds.
2. Payer and payee both approve refund.
3. Contract refunds the payer.

### Dispute path
1. Either party raises a dispute.
2. Arbiter resolves by releasing or refunding.

### Timeout path
- `releaseByTimeout()` after `releaseAfter`
- `refundByTimeout()` after `refundAfter`

## Recommended public repo standards

Before publishing:
- replace placeholder addresses in examples
- add deployment addresses after each network deployment
- add badges if wanted
- enable branch protection in GitHub
- use a multisig for owner and treasury roles in live environments

## Important notes

- Fee-on-transfer and rebasing tokens are not supported in this base release.
- This codebase is intended to be understandable and extensible, but high-value production use should still go through independent security review and audit.

## Suggested next extensions

- milestone escrows
- split payouts
- EIP-712 signature approvals
- proxy or clone deployment patterns
- batch escrow creation
- role-based arbiter registry
- richer metadata and dispute reason codes
