# Security Notes

This repository is structured for public use and extension, but anyone deploying it for real value should still perform a formal review and audit.

## Included controls
- Solidity `0.8.24` overflow protections
- `ReentrancyGuard`
- `SafeERC20`
- immutable role and commercial parameters per escrow
- restricted arbiter controls
- strict state transitions
- explicit native/token deposit paths
- fee cap

## Operational recommendations
- use a multisig as factory owner
- use a dedicated treasury wallet
- use a dedicated dispute arbiter or arbiter service wallet
- keep timeout windows commercially realistic
- hash final terms after both parties agree them
- index every escrow event off-chain
- monitor for stuck funds and unusual token behaviour

## Known design constraints
- fee-on-transfer tokens are not supported
- rebasing tokens are not recommended
- ERC-777 style hooks can create complexity and should be avoided in production integrations
- arbitration is single-arbiter in this base release
- no milestone splitting in this base release

## Before mainnet
- complete a professional smart contract audit
- test against the exact ERC-20 assets you plan to support
- verify deployment parameters per network
- publish addresses and ABI versions
- create runbooks for dispute resolution and pause handling
