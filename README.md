# Decentralized Escrow for Service Agreements
#### 🤝 Milestone-Based Escrow Smart Contract

[![Clarity](https://img.shields.io/badge/Clarity-Smart%20Contract-blue)](https://clarity-lang.org/)
[![Clarinet](https://img.shields.io/badge/Clarinet-v0.31.1-green)](https://github.com/hirosystems/clarinet)
[![Stacks](https://img.shields.io/badge/Stacks-Blockchain-orange)](https://stacks.co/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A secure, milestone-based escrow smart contract built on the Stacks blockchain using Clarity. This contract facilitates trustless service agreements between clients and providers with dispute resolution capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Security](#security)
- [Testing](#testing)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

The Milestone-Based Escrow Contract enables secure service agreements by:

- **Holding funds in escrow** until milestones are completed
- **Enabling milestone-based payments** for project progression
- **Providing dispute resolution** through trusted arbiters
- **Ensuring trustless execution** with smart contract automation

### How It Works

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │    │  Provider   │    │  Arbiter    │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       │ 1. Create Escrow  │                   │
       ├──────────────────►│                   │
       │                   │                   │
       │ 2. Fund Escrow    │                   │
       ├──────────────────►┤                   │
       │                   │                   │
       │      3. Work      │                   │
       │◄─────────────────►│                   │
       │                   │                   │
       │ 4. Release Payment│                   │
       ├──────────────────►│                   │
       │                   │                   │
       │    5. Dispute?    │                   │
       ├──────────────────►┼──────────────────►│
       │                   │  6. Resolution    │
       │◄─────────────────────────────────────┤
```

## ✨ Features

### 🔐 **Core Security**
- **Multi-party authorization** (Client, Provider, Arbiter)
- **State-based access control** with proper transitions
- **Reentrancy protection** through careful state management
- **Comprehensive input validation** for all parameters

### 💰 **Payment Management**
- **Milestone-based releases** up to 20 milestones per escrow
- **Flexible amount distribution** across project phases
- **Automatic completion tracking** when all milestones are paid
- **Refund mechanisms** for cancelled agreements

### ⚖️ **Dispute Resolution**
- **Neutral arbiter system** for conflict resolution
- **Flexible fund distribution** in dispute settlements
- **Transparent dispute tracking** with event logging
- **Fair resolution process** protecting both parties

### 📊 **Transparency & Tracking**
- **Complete transaction history** through event logs
- **Real-time status tracking** for all escrows
- **Detailed milestone information** with descriptions
- **Query functions** for easy data access

## 🏗️ Architecture

### Data Structures

```clarity
;; Escrow Structure
{
  client: principal,           ;; Service purchaser
  provider: principal,         ;; Service provider  
  arbiter: principal,          ;; Dispute resolver
  total-amount: uint,          ;; Total STX amount
  status: string-ascii,        ;; Current status
  balance: uint,               ;; Remaining balance
  milestones-count: uint       ;; Number of milestones
}

;; Milestone Structure  
{
  description: string-utf8,    ;; Milestone description
  amount: uint,                ;; Payment amount
  paid: bool                   ;; Payment status
}
```

### Status Flow

```
pending → funded → completed
    ↓         ↓         ↑
cancelled   disputed ──┘
```

## 🚀 Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v0.31.1+
- [Node.js](https://nodejs.org/) v16+
- [Stacks CLI](https://github.com/hirosystems/stacks.js) (optional)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/milestone-escrow-contract
   cd milestone-escrow-contract
   ```

2. **Install Clarinet**
   ```bash
   # macOS
   brew install clarinet

   # Or download from releases
   # https://github.com/hirosystems/clarinet/releases
   ```

3. **Initialize project**
   ```bash
   clarinet new escrow-project
   cd escrow-project
   ```

4. **Add the contract**
   ```bash
   # Copy the contract file to contracts/
   cp ../service-escrow-v1.clar contracts/
   ```

5. **Verify installation**
   ```bash
   clarinet check
   # Should show: ✔ 1 contract checked
   ```

## 📖 Usage

### Basic Workflow

#### 1. Create Escrow Agreement

```clarity
;; Create a 2-milestone project worth 10 STX
(contract-call? .service-escrow-v1 create-escrow
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; provider
  'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9   ;; arbiter  
  u10000000  ;; 10 STX in microSTX
  (list u6000000 u4000000)  ;; 6 STX + 4 STX milestones
  (list "Design Phase" "Development Phase"))
```

#### 2. Fund the Escrow

```clarity
;; Client funds the escrow
(contract-call? .service-escrow-v1 fund-escrow u1)
```

#### 3. Release Milestone Payments

```clarity
;; Release first milestone (6 STX)
(contract-call? .service-escrow-v1 release-milestone-payment u1 u1)

;; Release second milestone (4 STX) 
(contract-call? .service-escrow-v1 release-milestone-payment u1 u2)
```

#### 4. Handle Disputes (if needed)

```clarity
;; Raise a dispute
(contract-call? .service-escrow-v1 raise-dispute u1)

;; Arbiter resolves dispute (50/50 split example)
(contract-call? .service-escrow-v1 resolve-dispute u1 u5000000 u5000000)
```

### Query Information

```clarity
;; Get escrow details
(contract-call? .service-escrow-v1 get-escrow-details u1)

;; Get specific milestone
(contract-call? .service-escrow-v1 get-milestone-details u1 u1)

;; Get all milestones
(contract-call? .service-escrow-v1 get-escrow-milestones u1)
```

## 📚 API Reference

### Public Functions

#### `create-escrow`
Creates a new escrow agreement.

```clarity
(create-escrow 
  (provider principal) 
  (arbiter principal) 
  (total-amount uint) 
  (milestone-amounts (list 20 uint)) 
  (milestone-descriptions (list 20 (string-utf8 256))))
→ (response uint uint)
```

**Parameters:**
- `provider`: Service provider's principal
- `arbiter`: Dispute resolver's principal  
- `total-amount`: Total project amount in microSTX
- `milestone-amounts`: List of payment amounts for each milestone
- `milestone-descriptions`: List of milestone descriptions

**Returns:** Escrow ID on success

**Errors:**
- `ERR-INVALID-PRINCIPALS` (u110): Invalid or duplicate principals
- `ERR-NO-MILESTONES` (u109): Empty milestone list
- `ERR-MILESTONE-SUM-MISMATCH` (u111): Milestone sum ≠ total amount
- `ERR-ZERO-AMOUNT` (u113): Zero total amount
- `ERR-TOO-MANY-MILESTONES` (u114): More than 20 milestones

---

#### `fund-escrow`
Client deposits funds into the escrow.

```clarity
(fund-escrow (escrow-id uint)) → (response bool uint)
```

**Authorization:** Client only
**Preconditions:** Escrow status must be "pending"

---

#### `release-milestone-payment`
Releases payment for a completed milestone.

```clarity
(release-milestone-payment (escrow-id uint) (milestone-id uint)) 
→ (response bool uint)
```

**Authorization:** Client only
**Preconditions:** 
- Escrow status must be "funded"
- Milestone must not be already paid
- Sufficient balance in escrow

---

#### `cancel-escrow`
Cancels the escrow and refunds remaining balance.

```clarity
(cancel-escrow (escrow-id uint)) → (response bool uint)
```

**Authorization:** Client or Arbiter
**Preconditions:** Escrow status must be "funded", "disputed", or "pending"

---

#### `raise-dispute`
Initiates a dispute for arbiter resolution.

```clarity
(raise-dispute (escrow-id uint)) → (response bool uint)
```

**Authorization:** Client or Provider
**Preconditions:** Escrow status must be "funded"

---

#### `resolve-dispute`
Arbiter resolves a dispute by distributing funds.

```clarity
(resolve-dispute 
  (escrow-id uint) 
  (amount-to-client uint) 
  (amount-to-provider uint)) 
→ (response bool uint)
```

**Authorization:** Arbiter only
**Preconditions:** 
- Escrow status must be "disputed"
- Amount distribution must equal remaining balance

### Read-Only Functions

#### `get-escrow-details`
```clarity
(get-escrow-details (escrow-id uint)) 
→ (optional {client: principal, provider: principal, ...})
```

#### `get-milestone-details`  
```clarity
(get-milestone-details (escrow-id uint) (milestone-id uint))
→ (optional {description: (string-utf8 256), amount: uint, paid: bool})
```

#### `get-escrow-milestones`
```clarity
(get-escrow-milestones (escrow-id uint))
→ (optional (list 20 (optional milestone-data)))
```

#### `get-last-escrow-id`
```clarity
(get-last-escrow-id) → uint
```

#### `get-contract-balance`
```clarity
(get-contract-balance) → uint
```

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `ERR-ESCROW-NOT-FOUND` | Escrow does not exist |
| u101 | `ERR-UNAUTHORIZED` | Caller not authorized |
| u102 | `ERR-INVALID-STATUS` | Invalid escrow status |
| u103 | `ERR-INSUFFICIENT-FUNDS` | Not enough balance |
| u104 | `ERR-ALREADY-FUNDED` | Escrow already funded |
| u105 | `ERR-MILESTONE-NOT-FOUND` | Milestone does not exist |
| u106 | `ERR-MILESTONE-ALREADY-PAID` | Milestone already paid |
| u107 | `ERR-ESCROW-CANCELLED` | Escrow was cancelled |
| u108 | `ERR-ESCROW-COMPLETED` | Escrow already completed |
| u109 | `ERR-NO-MILESTONES` | No milestones provided |
| u110 | `ERR-INVALID-PRINCIPALS` | Invalid principal addresses |
| u111 | `ERR-MILESTONE-SUM-MISMATCH` | Milestone sum mismatch |
| u112 | `ERR-INVALID-SPLIT` | Invalid dispute split |
| u113 | `ERR-ZERO-AMOUNT` | Zero amount not allowed |
| u114 | `ERR-TOO-MANY-MILESTONES` | Too many milestones |

## 🛡️ Security

### Security Features

✅ **Authorization Controls**
- Role-based access (Client, Provider, Arbiter)
- Function-level permission checks
- Principal validation and uniqueness

✅ **State Management**  
- Atomic state transitions
- Reentrancy protection
- Consistent error handling

✅ **Input Validation**
- Comprehensive parameter checking
- Amount validation and sum verification  
- Principal address validation

✅ **Financial Security**
- Safe STX transfers with error handling
- Balance tracking and verification
- Overflow protection in arithmetic

### Security Considerations

⚠️ **Potential Risks**
- **Arbiter Trust**: Arbiters have significant power in disputes
- **Gas Limits**: Large milestone counts may hit transaction limits
- **Front-running**: Public transaction visibility

🔒 **Mitigation Strategies**
- Choose arbiters carefully and consider multi-sig arbiters
- Limit milestone counts to reasonable numbers (≤20)
- Use commit-reveal schemes for sensitive operations if needed

### Audit Checklist

- [x] **Access Control**: All functions properly restrict access
- [x] **Integer Arithmetic**: Safe math operations throughout  
- [x] **Reentrancy**: State updated before external calls
- [x] **Input Validation**: All user inputs validated
- [x] **Error Handling**: Comprehensive error cases covered
- [x] **State Consistency**: Atomic operations maintain consistency

## 🧪 Testing

### Running Tests

```bash
# Check contract compilation
clarinet check

# Run all tests
clarinet test

# Run specific test file
clarinet test tests/escrow-test.ts
```

### Test Scenarios

#### ✅ **Happy Path Tests**
- Create escrow with valid parameters
- Fund escrow successfully  
- Release milestone payments in order
- Complete escrow when all milestones paid

#### ❌ **Error Condition Tests**
- Create escrow with invalid parameters
- Unauthorized access attempts
- Invalid state transitions
- Insufficient balance scenarios

#### ⚖️ **Dispute Resolution Tests**
- Raise disputes from client/provider
- Resolve disputes with various splits
- Cancel escrows in different states

#### 🔒 **Security Tests**
- Reentrancy attack attempts
- Integer overflow/underflow tests
- Access control bypass attempts

### Sample Test

```typescript
import { Clarinet, Tx, Chain, Account } from 'https://deno.land/x/clarinet/index.ts';
import { assertEquals } from 'https://deno.land/std/testing/asserts.ts';

Clarinet.test({
    name: "Create and fund escrow successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const client = accounts.get('wallet_1')!;
        const provider = accounts.get('wallet_2')!;
        const arbiter = accounts.get('wallet_3')!;

        let block = chain.mineBlock([
            Tx.contractCall('service-escrow-v1', 'create-escrow', [
                provider.address,
                arbiter.address,
                10000000, // 10 STX
                [6000000, 4000000], // 6 STX + 4 STX
                ["Design Phase", "Development Phase"]
            ], client.address),

            Tx.contractCall('service-escrow-v1', 'fund-escrow', [
                1 // escrow-id
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result, '(ok u1)');
        assertEquals(block.receipts[1].result, '(ok true)');
    }
});
```

## 💡 Examples

### Example 1: Web Development Project

```clarity
;; Create escrow for a website project
(contract-call? .service-escrow-v1 create-escrow
  'SP2DEVELOPER123...  ;; Web developer
  'SP3MEDIATOR456...   ;; Freelance mediator
  u50000000           ;; 50 STX total
  (list u15000000 u20000000 u15000000)  ;; 3 phases
  (list "Wireframes & Design" "Frontend Development" "Backend & Deployment"))

;; Fund the project
(contract-call? .service-escrow-v1 fund-escrow u1)

;; Release payments as work completes
(contract-call? .service-escrow-v1 release-milestone-payment u1 u1)  ;; Design done
(contract-call? .service-escrow-v1 release-milestone-payment u1 u2)  ;; Frontend done  
(contract-call? .service-escrow-v1 release-milestone-payment u1 u3)  ;; Project complete
```

### Example 2: Consulting Agreement

```clarity
;; Monthly consulting retainer
(contract-call? .service-escrow-v1 create-escrow
  'SP2CONSULTANT789...  ;; Business consultant
  'SP3NEUTRAL012...     ;; Neutral third party
  u30000000            ;; 30 STX for 3 months
  (list u10000000 u10000000 u10000000)  ;; Monthly payments
  (list "Month 1: Strategy" "Month 2: Implementation" "Month 3: Review"))
```

### Example 3: Handling Disputes

```clarity
;; If issues arise, raise a dispute
(contract-call? .service-escrow-v1 raise-dispute u1)

;; Arbiter investigates and resolves
;; Example: 70% to provider, 30% refund to client
(contract-call? .service-escrow-v1 resolve-dispute u1 u9000000 u21000000)
```

## 🔄 Integration

### Frontend Integration

```javascript
// Using Stacks.js
import { 
  ContractCallRegularOptions,
  makeContractCall,
  broadcastTransaction 
} from '@stacks/transactions';

// Create escrow
const createEscrowTx = await makeContractCall({
  contractAddress: 'SP2YOUR-CONTRACT-ADDRESS',
  contractName: 'service-escrow-v1',
  functionName: 'create-escrow',
  functionArgs: [
    standardPrincipalCV(providerAddress),
    standardPrincipalCV(arbiterAddress), 
    uintCV(totalAmount),
    listCV(milestoneAmounts.map(uintCV)),
    listCV(descriptions.map(stringUtf8CV))
  ],
  senderKey: clientPrivateKey,
  network
});

const result = await broadcastTransaction(createEscrowTx, network);
```

### Backend Monitoring

```javascript
// Monitor escrow events
const contractEvents = await fetch(
  `${apiUrl}/extended/v1/contract/${contractAddress}.${contractName}/events`
);

const events = await contractEvents.json();
events.results
  .filter(event => event.event_type === 'smart_contract_log')
  .forEach(event => {
    const eventData = event.contract_log.value.repr;
    console.log('Escrow event:', eventData);
  });
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

### Development Setup

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Run tests**
   ```bash
   clarinet check
   clarinet test
   ```
5. **Submit a pull request**

### Contribution Guidelines

- **Code Style**: Follow Clarity best practices
- **Testing**: Add tests for new features
- **Documentation**: Update README for API changes  
- **Security**: Consider security implications
- **Backwards Compatibility**: Avoid breaking changes

### Areas for Contribution

- 🔧 **Performance optimizations**
- 🔒 **Security enhancements** 
- 📚 **Documentation improvements**
- 🧪 **Additional test cases**
- 🌟 **New features** (multi-token support, etc.)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Milestone Escrow Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🙏 Acknowledgments

- **Stacks Foundation** for the Stacks blockchain
- **Hiro Systems** for Clarinet development tools  
- **Clarity Language** community for best practices
- **Contributors** who helped improve this contract

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/milestone-escrow-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/milestone-escrow-contract/discussions)
- **Discord**: [Stacks Discord](https://discord.gg/stacks)
- **Documentation**: [Clarity Documentation](https://clarity-lang.org/)

---

**Built with ❤️ on Stacks** 🚀

*Secure milestone-based payments for the decentralized economy.*