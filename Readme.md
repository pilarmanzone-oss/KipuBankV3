# KipuBankV3: Multi-Token Smart Contract

---

## Overview

`KipuBankV3.sol` is the latest iteration of KipuBank, providing **multi-token deposit and withdrawal functionality** with **automatic conversion to USDC via Uniswap V2**, **role-based access control**, and **reentrancy protection**.

**Key Focus:**
- Security
- Extensibility
- Gas efficiency
- Auditable and simple design

All deposits are credited internally in **USDC (6 decimals)**.

---

## 1. High-Level Improvements

### Multi-Token Support and Automatic Conversion

| Feature | Description |
|---------|------------|
| ETH deposits | Deposited ETH is automatically converted to USDC via Uniswap V2. |
| ERC20 deposits | Any ERC20 token with a direct USDC pair is converted to USDC. |
| Direct USDC | Users can deposit USDC directly without conversion. |

**Why:** Simplifies asset management while maintaining a single accounting currency.

---

### Access Control

| Role | Permissions |
|------|------------|
| ADMIN_ROLE | Allows/disallows tokens for deposit, updates bank cap. |

**Why:** Restricts critical operations to trusted administrators, improving security.

---

### Cap Management and Safety

| Feature | Description |
|---------|------------|
| Bank cap | Limits total deposits (`bankCapUsd6`). |
| Reentrancy protection | All deposits and withdrawals are `nonReentrant`. |
| Cap enforcement | Internal accounting ensures `totalDepositedUsd6` never exceeds `bankCapUsd6`. |

---

### Efficiency and Design

- Uses `immutable` and `constant` variables for gas optimization.
- Minimal swap paths (`token -> USDC` or `WETH -> USDC`) for efficiency.
- `_isTokenSupported()` ensures only tokens with direct USDC pairs are allowed.

---

## 2. Deployment and Interaction (Foundry)

### Constructor Parameters

```solidity
constructor(
    address admin,
    address usdcAddr,
    address uniswapRouterAddr,
    address uniswapFactoryAddr,
    uint256 initialCapUsd6
)
```
| Parameter | Description |
|-----------|------------|
| `admin` | Address that receives `ADMIN_ROLE`. |
| `usdcAddr` | USDC token contract address (6 decimals). |
| `uniswapRouterAddr` | Uniswap V2 router address. |
| `uniswapFactoryAddr` | Uniswap V2 factory address. |
| `initialCapUsd6` | Bank cap in USDC (6 decimals). |

### Example Deployment Command (Sepolia Testnet)

```bash
forge script script/DeployKipuBankV3.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```
*After deployment, the admin can enable allowed tokens using `setTokenAllowed(token, true)`.*

---

## Main Functions

| Function | Description |
|---------|------------|
| `setTokenAllowed(token, bool)` | Allow or disallow a token for deposits |
| `setBankCapUsd6(newCap)` | Update the global bank cap |
| `depositUsdc(amount)` | Deposit USDC directly |
| `depositEthAndSwap(amountOutMin)` | Deposit ETH and convert to USDC |
| `depositTokenAndSwap(token, amount, amountOutMin)` | Deposit ERC20 and convert to USDC |
| `withdrawUsdc(amount)` | Withdraw USDC from balance |
| `balanceOfUsdc(user)` | Query user's USDC balance |

---

## 3. Test Coverage and Methods

**Framework:** Foundry (`forge test`, `forge coverage`)  

### Coverage Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Total lines | **84.88%** | Main contract: 100.00% |
| Functions covered | **84.21%** | Main contract: 100.00% |
| Branches covered | 75.00% | KipuBankV3Additional.t.sol for added branch coverage |
| Key test files | `test/ReentrancyAttack.sol`, `test/mocks/MockERC20.sol`, `test/mocks/MockUniswapRouter.sol` | Covers reentrancy, swaps, and deposits |

### Testing Methods

- **Unit Tests:** deposits, withdrawals, swaps, cap enforcement, balance queries.  
- **Integration Tests:** full flow with ETH/ERC20 deposits via Uniswap V2 mock router.  
- **Security Tests:** reentrancy, token allowance checks, bank cap enforcement.  
- **Tools:** Foundry (`forge test`, `forge coverage`), Solidity 0.8.20.

**Future Improvements:**

- Expand negative test coverage (deposit 0, withdraw > balance, unsupported tokens).  
- Optionally add multi-hop swap support (`token -> WETH -> USDC`).

---

## 4. Threat Analysis & Design Trade-offs

### Threats Addressed

| Threat | Mitigation |
|--------|-----------|
| Reentrancy | All deposit/withdraw functions use `nonReentrant` |
| Over-depositing | Bank cap enforcement (`totalDepositedUsd6 ≤ bankCapUsd6`) |
| Unsupported tokens | Only tokens with direct USDC pair allowed |

### Weaknesses / Maturity Steps

| Weakness | Suggested Improvement |
|----------|---------------------|
| Multi-hop token limitation | Allow routes like `token -> WETH -> USDC` |
| Centralized admin | Consider multisig or DAO governance for admin |
| Lower branch coverage | Expand tests  |

### Design Trade-offs

- **Simplicity vs Flexibility:** Only direct pairs supported for security and auditability.  
- **Internal Accounting:** USDC-only for clear audits and minimal conversion errors.  
- **OpenZeppelin Libraries:** AccessControl & ReentrancyGuard for standard, audited security.

---

## 5. Technical Analysis & Coverage Summary

### Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Lines covered | **84.88%** | Main contract: 100.00% |
| Functions covered | **84.21%** | Main contract: 100.00% |
| Branches covered | 75.00% | KipuBankV3Additional.t.sol for added branch coverage |
| Key test files | `test/ReentrancyAttack.sol`, `test/mocks/MockERC20.sol`, `test/mocks/MockUniswapRouter.sol` | Reentrancy, swaps, deposits |

### Threats & Weaknesses

- Reentrancy mitigated using `nonReentrant`  
- Cap enforcement prevents over-depositing  
- Only direct USDC pair tokens allowed  
- Admin privileges are centralized  
- Multi-hop swaps unsupported

### Steps for Maturity

1. Add negative test cases for full branch coverage.  
2. Optional multi-hop swap support.  
3. Consider decentralized admin controls (multisig or DAO).

---

## Objectives Fulfilled

| Requirement | Description | 
|--------|-------|
| **1️️ Handle exchangeable tokens (Uniswap V2)** | Supports any token with direct pair token↔USDC via router. |
| **2️️ Automatic swaps within the contract** | Execution of 'swapExactTokensForTokens` and 'swapExactETHForTokens'. |
| **3️️ Preserve KipuBank V2 functionality** | Maintains deposits, withdrawals and ownership through AccessControl.  |
| **4️️ `bankCap` Observed** | Verification 'require(total + deposit ≤ bankCap)` in each flow. |
| **5️️ Coverage ≥ 50 %** | 84.88% lines - requirement exceeded. |

---

## Conclusion

KipuBank V3 is a **secure, efficient, and extensible multi-token vault**, integrating with Uniswap V2 for automatic token conversion and enforcing bank caps. This version provides a solid foundation for DeFi applications requiring controlled multi-asset deposits.

---

© 2025 KipuBank Project — MIT License








