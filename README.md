# EntropyCounter

Counter using EntropyOracle for encrypted randomness

## 🚀 Standard workflow
- Install (first run): `npm install --legacy-peer-deps`
- Compile: `npx hardhat compile`
- Test (local FHE + local oracle/chaos engine auto-deployed): `npx hardhat test`
- Deploy (frontend Deploy button): constructor arg is fixed to EntropyOracle `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
- Verify: `npx hardhat verify --network sepolia <contractAddress> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

## 📋 Overview

This example demonstrates **basic** concepts in FHEVM with **EntropyOracle integration**:
- Integrating with EntropyOracle
- Using encrypted entropy in FHE operations
- Combining entropy with encrypted values
- Entropy-based counter increments

## 🎯 What This Example Teaches

This tutorial will teach you:

1. **How to integrate EntropyOracle** into your smart contract
2. **How to request and use encrypted entropy** from the oracle
3. **How to combine entropy with encrypted values** using FHE operations (XOR, ADD)
4. **How to handle external encrypted inputs** with input proofs
5. **The importance of `FHE.allowThis()`** for permission management
6. **The difference between simple and entropy-enhanced operations**

## 💡 Why This Matters

Traditional counters simply increment by 1. With EntropyOracle, you can:
- **Add randomness** to increments without revealing values
- **Enhance security** by mixing entropy with encrypted data
- **Create unpredictable patterns** while maintaining privacy
- **Learn the foundation** for more complex FHE + Entropy patterns

## 🔍 How It Works

### Contract Structure

The contract has three main components:

1. **Initialization**: Sets up encrypted counter value
2. **Entropy Request**: Requests randomness from EntropyOracle
3. **Entropy-Based Increment**: Uses entropy to enhance counter increments

### Step-by-Step Code Explanation

#### 1. Constructor

```solidity
constructor(address _entropyOracle) {
    require(_entropyOracle != address(0), "Invalid oracle address");
    entropyOracle = IEntropyOracle(_entropyOracle);
}
```

**What it does:**
- Takes EntropyOracle address as parameter
- Validates the address is not zero
- Stores the oracle interface for later use

**Why it matters:**
- Must use the correct oracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`
- This address is fixed and used in all examples

#### 2. Initialize Function

```solidity
function initialize(externalEuint64 encryptedValue, bytes calldata inputProof) external {
    require(!initialized, "Counter already initialized");
    
    // Convert external encrypted value to internal
    euint64 internalValue = FHE.fromExternal(encryptedValue, inputProof);
    
    // Allow contract to use this encrypted value
    FHE.allowThis(internalValue);
    
    // Store encrypted counter
    counter = internalValue;
    initialized = true;
    
    emit CounterInitialized(msg.sender);
}
```

**What it does:**
- Accepts an encrypted value from external source (frontend)
- Validates the encrypted value using input proof
- Converts external encrypted value to internal format
- Grants permission to use the value
- Stores it as the initial counter value

**Key concepts:**
- `externalEuint64`: Encrypted value from outside the contract
- `inputProof`: Cryptographic proof validating the encrypted value
- `FHE.fromExternal()`: Converts external to internal encrypted format
- `FHE.allowThis()`: **CRITICAL** - Grants contract permission to use the value

**Why it's needed:**
- Counter must start with an encrypted value
- Can only be called once (prevents re-initialization)

#### 3. Request Entropy

```solidity
function requestIncrement(bytes32 tag) external payable returns (uint256 requestId) {
    require(initialized, "Counter not initialized");
    require(msg.value >= entropyOracle.getFee(), "Insufficient fee");
    
    // Request entropy from oracle
    requestId = entropyOracle.requestEntropy{value: msg.value}(tag);
    incrementRequests[requestId] = true;
    incrementCount++;
    
    emit IncrementRequested(requestId, msg.sender);
    return requestId;
}
```

**What it does:**
- Checks counter is initialized
- Validates fee payment (0.00001 ETH)
- Requests entropy from EntropyOracle
- Stores request ID for later use
- Returns request ID

**Key concepts:**
- `tag`: Unique identifier for this request (use `keccak256()` for uniqueness)
- `requestEntropy()`: Oracle function that generates encrypted randomness
- `requestId`: Unique identifier returned by oracle
- Fee: Must be exactly 0.00001 ETH (10,000,000,000,000 wei)

**Why two-step process:**
- Entropy generation takes time (oracle needs to collect seeds and generate)
- Request ID allows you to check fulfillment status later

#### 4. Increment with Entropy

```solidity
function incrementWithEntropy(uint256 requestId) external {
    require(initialized, "Counter not initialized");
    require(incrementRequests[requestId], "Invalid request ID");
    require(entropyOracle.isRequestFulfilled(requestId), "Entropy not ready");
    
    // Get encrypted entropy from oracle
    euint64 entropy = entropyOracle.getEncryptedEntropy(requestId);
    
    // Allow contract to use entropy
    FHE.allowThis(entropy);  // CRITICAL!
    
    // Combine counter with entropy for random increment
    // Use XOR to mix entropy with counter
    euint64 mixed = FHE.xor(counter, entropy);
    FHE.allowThis(mixed);
    
    // Add 1 to mixed value (entropy-based increment)
    euint64 one = FHE.asEuint64(1);
    FHE.allowThis(one);
    counter = FHE.add(mixed, one);
    FHE.allowThis(counter);
    
    // Mark request as used
    incrementRequests[requestId] = false;
    
    emit CounterIncremented(requestId, msg.sender);
}
```

**What it does:**
- Validates request ID and fulfillment status
- Gets encrypted entropy from oracle
- **Grants permission** to use entropy (CRITICAL!)
- Combines counter with entropy using XOR
- Adds 1 to the mixed value
- Updates counter with new value

**Key concepts:**
- `isRequestFulfilled()`: Checks if entropy is ready
- `getEncryptedEntropy()`: Retrieves encrypted randomness
- `FHE.xor()`: XOR operation on encrypted values
- `FHE.add()`: Addition on encrypted values
- Multiple `FHE.allowThis()` calls: Required for each encrypted value used

**Why XOR then ADD:**
- XOR mixes entropy with counter (creates randomness)
- ADD increments the mixed value
- Result: Entropy-enhanced increment (not just +1)

**Common mistake:**
- Forgetting `FHE.allowThis(entropy)` causes `SenderNotAllowed()` error

## 🧪 Step-by-Step Testing

### Prerequisites

1. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

2. **Compile contracts:**
   ```bash
   npx hardhat compile
   ```

### Running Tests

```bash
npx hardhat test
```

### What Happens in Tests

1. **Fixture Setup** (`deployContractsFixture`):
   - Deploys FHEChaosEngine locally
   - Initializes master seed (encrypted)
   - Deploys EntropyOracle locally
   - Deploys EntropyCounter with oracle address
   - Returns all contract instances

2. **Test: Deployment**
   ```typescript
   it("Should deploy successfully", async function () {
     const { contract } = await loadFixture(deployContractsFixture);
     expect(await contract.getAddress()).to.be.properAddress;
   });
   ```
   - Verifies contract deploys correctly
   - Checks contract address is valid

3. **Test: Initialization**
   ```typescript
   it("Should initialize with encrypted value", async function () {
     const { contract, contractAddress, owner } = await loadFixture(deployContractsFixture);
     
     const input = hre.fhevm.createEncryptedInput(contractAddress, owner.address);
     input.add64(0);
     const encryptedInput = await input.encrypt();
     
     await contract.initialize(encryptedInput.handles[0], encryptedInput.inputProof);
     
     expect(await contract.isInitialized()).to.be.true;
   });
   ```
   - Creates encrypted input (value: 0)
   - Encrypts using FHEVM SDK
   - Calls `initialize()` with handle and proof
   - Verifies initialization succeeded

4. **Test: Simple Increment**
   ```typescript
   it("Should increment encrypted counter without entropy", async function () {
     // ... initialization code ...
     
     await expect(contract.connect(user1).increment())
       .to.emit(contract, "CounterIncremented")
       .withArgs(0, user1.address);
   });
   ```
   - Increments counter without entropy
   - Verifies event is emitted
   - Counter value increases by 1 (encrypted)

5. **Test: Entropy Request**
   ```typescript
   it("Should request entropy for increment", async function () {
     // ... initialization code ...
     
     const tag = hre.ethers.id("test-increment");
     const fee = await oracle.getFee();
     
     await expect(
       contract.connect(user1).requestIncrement(tag, { value: fee })
     ).to.emit(contract, "IncrementRequested");
   });
   ```
   - Requests entropy with unique tag
   - Pays required fee
   - Verifies request event is emitted

### Expected Test Output

```
  EntropyCounter
    Deployment
      ✓ Should deploy successfully
      ✓ Should not be initialized by default
      ✓ Should have EntropyOracle address set
    Initialization
      ✓ Should initialize with encrypted value
      ✓ Should not allow double initialization
    Simple Increment
      ✓ Should increment encrypted counter without entropy
      ✓ Should not allow increment before initialization
    Entropy-based Increment
      ✓ Should request entropy for increment
      ✓ Should track increment count
    View Functions
      ✓ Should return encrypted counter value
      ✓ Should not return counter before initialization

  10 passing
```

**Note:** Encrypted values appear as handles in test output. Decrypt off-chain using FHEVM SDK to see actual values.

## 🚀 Step-by-Step Deployment

### Option 1: Frontend (Recommended)

1. Navigate to [Examples page](https://entrofhe.vercel.app/examples)
2. Find "EntropyCounter" in Tutorial Examples
3. Click **"Deploy"** button
4. Approve transaction in wallet
5. Wait for deployment confirmation
6. Copy deployed contract address

**Advantages:**
- Constructor argument automatically included
- No manual ABI encoding needed
- Real-time transaction status

### Option 2: CLI

1. **Create deploy script** (`scripts/deploy.ts`):
   ```typescript
   import hre from "hardhat";

   async function main() {
     const ENTROPY_ORACLE_ADDRESS = "0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361";
     
     const ContractFactory = await hre.ethers.getContractFactory("EntropyCounter");
     const contract = await ContractFactory.deploy(ENTROPY_ORACLE_ADDRESS);
     await contract.waitForDeployment();
     
     const address = await contract.getAddress();
     console.log("EntropyCounter deployed to:", address);
   }

   main().catch((error) => {
     console.error(error);
     process.exitCode = 1;
   });
   ```

2. **Deploy:**
   ```bash
   npx hardhat run scripts/deploy.ts --network sepolia
   ```

3. **Save contract address** for verification

## ✅ Step-by-Step Verification

### Option 1: Frontend

1. After deployment, click **"Verify"** button on Examples page
2. Wait for verification confirmation
3. View verified contract on Etherscan

### Option 2: CLI

```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361
```

**Important:** Constructor argument must be the EntropyOracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

### Verification Output

```
Successfully verified contract EntropyCounter on Etherscan.
https://sepolia.etherscan.io/address/<CONTRACT_ADDRESS>#code
```

## 📊 Expected Outputs

### After Initialization

- `isInitialized()` returns `true`
- `getCounter()` returns encrypted value (handle)
- `CounterInitialized` event emitted

### After Simple Increment

- Counter value increases by 1 (encrypted)
- `CounterIncremented` event emitted with `requestId = 0`
- Counter remains encrypted (decrypt off-chain to see value)

### After Entropy-Based Increment

- Counter value increases with entropy mixing
- `CounterIncremented` event emitted with actual `requestId`
- Counter value is unpredictable (due to entropy)
- All operations performed on encrypted data

## ⚠️ Common Errors & Solutions

### Error: `SenderNotAllowed()`

**Cause:** Missing `FHE.allowThis()` call on encrypted value.

**Example:**
```solidity
euint64 entropy = entropyOracle.getEncryptedEntropy(requestId);
// Missing: FHE.allowThis(entropy);
euint64 result = FHE.add(counter, entropy); // ❌ Error!
```

**Solution:**
```solidity
euint64 entropy = entropyOracle.getEncryptedEntropy(requestId);
FHE.allowThis(entropy); // ✅ Required!
euint64 result = FHE.add(counter, entropy);
```

**Prevention:** Always call `FHE.allowThis()` on encrypted values before using them in FHE operations.

---

### Error: `Entropy not ready`

**Cause:** Calling `incrementWithEntropy()` before entropy is fulfilled.

**Example:**
```typescript
const requestId = await contract.requestIncrement(tag, { value: fee });
await contract.incrementWithEntropy(requestId); // ❌ Too soon!
```

**Solution:**
```typescript
const requestId = await contract.requestIncrement(tag, { value: fee });

// Wait for fulfillment
let fulfilled = false;
while (!fulfilled) {
  fulfilled = await contract.entropyOracle.isRequestFulfilled(requestId);
  if (!fulfilled) {
    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
  }
}

await contract.incrementWithEntropy(requestId); // ✅ Now it's ready
```

**Prevention:** Always check `isRequestFulfilled()` before using entropy.

---

### Error: `Invalid oracle address`

**Cause:** Wrong or zero address passed to constructor.

**Example:**
```solidity
constructor(address _entropyOracle) {
    entropyOracle = IEntropyOracle(_entropyOracle); // ❌ No validation
}
```

**Solution:**
```solidity
constructor(address _entropyOracle) {
    require(_entropyOracle != address(0), "Invalid oracle address"); // ✅
    entropyOracle = IEntropyOracle(_entropyOracle);
}
```

**Prevention:** Always use the fixed EntropyOracle address: `0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361`

---

### Error: `Counter already initialized`

**Cause:** Trying to initialize counter twice.

**Solution:** Initialize only once. If you need to reset, deploy a new contract.

---

### Error: `Insufficient fee`

**Cause:** Not sending enough ETH when requesting entropy.

**Solution:** Always send exactly 0.00001 ETH (10,000,000,000,000 wei):
```typescript
const fee = await contract.entropyOracle.getFee();
await contract.requestIncrement(tag, { value: fee });
```

---

### Error: Verification failed - Constructor arguments mismatch

**Cause:** Wrong constructor argument used during verification.

**Solution:** Always use the EntropyOracle address:
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> 0x75b923d7940E1BD6689EbFdbBDCD74C1f6695361
```

## 🔗 Related Examples

- [EntropyArithmetic](../basic-arithmetic/) - Entropy-based arithmetic operations
- [EntropyEqualityComparison](../basic-equalitycomparison/) - Entropy-based comparisons
- [EntropyEncryption](../encryption-encryptsingle/) - Encrypting values with entropy
- [Category: basic](../)

## 📚 Additional Resources

- [Full Tutorial Track Documentation](../../../frontend/src/pages/Docs.tsx) - Complete educational guide
- [Zama FHEVM Documentation](https://docs.zama.org/) - Official FHEVM docs
- [GitHub Repository](https://github.com/zacnider/fhevm-example-basic-simplecounter) - Source code

## 📝 License

BSD-3-Clause-Clear
