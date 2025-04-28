# ResumeVerification - Resume Verification on Blockchain

**ResumeVerification** is a blockchain-based resume verification system, developed as my first experience with **Solidity** and smart contract development.

---

## Purpose

The goal of Veritoken is to **simplify and secure resume verification** by leveraging decentralized mechanisms:
- **Voting** is used to verify the legitimacy of employers.
- **Staking** of a native token, **Veritoken**, is required for participation and verification processes.
- This system ensures trust and transparency without relying on centralized authorities.

---

## Tech Stack

- **Blockchain**: Ethereum
- **Smart Contracts**: Solidity
- **Token**: Custom ERC-20 styled "Veritoken"

to initialize repo on your local machine, run the command below in your root folder

```
npm install
```

to compile smart contracts

```
npx hardhat compile
```

to start blockchain network

```
npx hardhat node
```

to deploy contracts, open a new terminal and run

```
npx hardhat run scripts/deploy.js --network localhost
```
