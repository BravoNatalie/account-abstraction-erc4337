# What is Account Abstraction (ERC4337)?

Account abstraction is a blockchain technology that allows users to use smart contracts as their externally-owned accounts (EOAs). This enables the creation of smart accounts, which have code attached and provide a better user experience by eliminating the need for private keys. The ERC-4337 specification on Ethereum achieves account abstraction without changing the consensus layer protocol by using an entry point contract and UserOperation objects. On zkSync, account abstraction is achieved natively by transforming all EOAs into smart contracts through system contracts, simplifying the setup process.

## What can we use it for?

Account abstraction can be used for several purposes:

### Enhanced User Experience
- **Seamless Onboarding**: Onboard users without requiring wallets or private key management.
- **Simplified Transactions**: Interact with the blockchain without understanding gas mechanics.
- **Social Recovery**: Recover accounts through trusted contacts.
- **Customizable Gas Fees**: Define gas price strategies.
- **Multi-Signature Wallets**: Secure fund management with multiple signatories.

### Improved Security
- **Phishing Protection**: Implement transaction signing challenges.
- **Contract Whitelisting**: Restrict contract interactions.
- **Unauthorized Transaction Prevention**: Require specific conditions for transaction execution.
- **Gasless Transactions**: Use paymaster contracts to cover gas fees.
- **Meta Transactions**: Allow third-party contract-initiated transactions.

## Project Goal

This project aims to comprehensively study and implement the ERC4337 Account Abstraction standard. The objective is to implement a simple account abstraction contract on both EVM and zkSync. To achieve this, the Foundry framework was used to develop the Solidity smart contract, alongside the account abstraction base implementation by eth-infinitism. Additionally, tests were created to validate the contracts.

PS.: Foundry solidity scripts for zksync does not work 100%, therefore the `ts-scripts` was created.

### Ethereum implementation

The account abstraction implementation includes the following features:
- Ownable
- ECDSA Signature
- Execute a sequence of transactions
- Deposit to entry point
- Withdraw deposit


### ZkSync Era implementation

The account abstraction implementation is straightforward with the following features:
- Ownable
- ECDSA Signature


## TODO
- [ ] add paymaster logic
- [ ] add spend threshold
- [ ] sign the tx with github/google session key
