# Social Token Marketplace

## Version: 1.2

A non-custodial social token marketplace smart contract with enhanced security checks, implemented in Clarity for the Stacks blockchain.

## Overview

This smart contract implements a decentralized marketplace for social tokens. It allows users to create, mint, transfer, and trade social tokens, as well as manage liquidity pools. The contract includes robust security measures and error handling to ensure safe and reliable operations.

## Features

- Token creation and management
- Token minting and transfers
- Order creation (buy and sell)
- Order execution
- Liquidity pool management
- Governance settings

## Key Functions

### Token Management

- `create-token`: Create a new social token
- `mint-tokens`: Mint additional tokens for an existing social token
- `transfer`: Transfer tokens between users

### Order Management

- `create-sell-order`: Create a new sell order
- `create-buy-order`: Create a new buy order
- `execute-order`: Execute an existing buy or sell order

### Liquidity Pool Management

- `add-liquidity`: Add liquidity to a token's pool
- `remove-liquidity`: Remove liquidity from a token's pool

### Read-Only Functions

- `get-token-details`: Retrieve details of a specific token
- `get-balance`: Get the balance of a specific token for a user
- `get-order`: Retrieve details of a specific order
- `get-liquidity-pool`: Get information about a token's liquidity pool

## Data Structures

- `tokens`: Stores token metadata
- `balances`: Tracks token balances for users
- `orders`: Stores buy and sell orders
- `liquidity-pools`: Manages liquidity pools for tokens
- `governance-settings`: Stores governance parameters

## Error Handling

The contract includes various error codes for different scenarios, ensuring proper validation and error reporting. Some key error codes include:

- `err-owner-only`: Operation restricted to contract owner
- `err-not-token-owner`: User is not the token owner
- `err-insufficient-balance`: Insufficient balance for the operation
- `err-invalid-token`: Invalid token ID
- `err-order-not-found`: Specified order does not exist

## Security Measures

- Access control for administrative functions
- Validation of input parameters
- Checks for sufficient balances and token ownership
- Prevention of self-transfers
- Contract pause functionality for emergency situations

## Usage

To use this contract, deploy it to the Stacks blockchain and interact with it using the provided public functions. Ensure that users have sufficient balances and permissions for their intended actions.

## Governance

The contract includes a governance settings map, which can be used to store and manage various parameters of the marketplace. This allows for potential upgrades and adjustments to the system's behavior.

## Initialization

Upon deployment, the contract sets the deployer as the contract owner and initializes the last token ID and last order ID to 0.

## Note on Pricing

The contract uses a simple pricing mechanism for liquidity pools. The `calculate-new-price` function adjusts the price based on changes in liquidity. More sophisticated pricing models could be implemented for production use.

