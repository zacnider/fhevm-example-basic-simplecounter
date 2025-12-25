# EntropyCounter

Learn how to create and increment encrypted counters using FHE.add

## 🎓 What You'll Learn

This example teaches you how to use FHEVM to build privacy-preserving smart contracts. You'll learn step-by-step how to implement encrypted operations, manage permissions, and work with encrypted data.

## 🚀 Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/zacnider/fhevm-example-basic-simplecounter.git
   cd fhevm-example-basic-simplecounter
   ```

2. **Install dependencies:**
   ```bash
   npm install --legacy-peer-deps
   ```

3. **Setup environment:**
   ```bash
   npm run setup
   ```
   Then edit `.env` file with your credentials:
   - `SEPOLIA_RPC_URL` - Your Sepolia RPC endpoint
   - `PRIVATE_KEY` - Your wallet private key (for deployment)
   - `ETHERSCAN_API_KEY` - Your Etherscan API key (for verification)

4. **Compile contracts:**
   ```bash
   npm run compile
   ```

5. **Run tests:**
   ```bash
   npm test
   ```

6. **Deploy to Sepolia:**
   ```bash
   npm run deploy:sepolia
   ```

7. **Verify contract (after deployment):**
   ```bash
   npm run verify <CONTRACT_ADDRESS>
   ```

**Alternative:** Use the [Examples page](https://entrofhe.vercel.app/examples) for browser-based deployment and verification.

---

## 📚 Overview

@title EntropyCounter
@notice Counter using encrypted randomness for encrypted randomness
@dev This example teaches you how to integrate encrypted randomness into your FHEVM contracts: using entropy for counter increments
In this example, you will learn:
- How to integrate encrypted randomness
- How to use encrypted entropy in FHE operations
- How to combine entropy with encrypted values
- Entropy-based counter increments

@notice Constructor - sets encrypted randomness address
@param _encrypted randomness Address of encrypted randomness contract

@notice Initialize counter with an encrypted value
@param encryptedValue Encrypted initial value (euint64)
@param inputProof Input proof for encrypted value
@dev Must be called before incrementing. Can only be called once.

@notice Request entropy for counter increment
@param tag Unique tag for this increment request
@return requestId Request ID from encrypted randomness
@dev Requires 0.00001 ETH fee. Call incrementWithEntropy() after request is fulfilled.

@notice Increment counter using entropy from encrypted randomness
@param requestId Request ID from requestIncrement()
@dev Uses entropy to add randomness to counter increment

@notice Simple increment without entropy (for comparison)
@dev Uses FHE.add to increment the encrypted value by 1
@dev Requires counter to be initialized

@notice Check if counter is initialized
@return True if counter has been initialized

@notice Get the encrypted counter value
@return Encrypted counter value (euint64)
@dev Returns encrypted value - must be decrypted off-chain to see actual value

@notice Get encrypted randomness address
@return Address of encrypted randomness contract

@notice Get increment count
@return Total number of increment requests made



## 🔐 Learn Zama FHEVM Through This Example

This example teaches you how to use the following **Zama FHEVM** features:

### What You'll Learn About

- **ZamaEthereumConfig**: Inherits from Zama's network configuration
  ```solidity
  contract MyContract is ZamaEthereumConfig {
      // Inherits network-specific FHEVM configuration
  }
  ```

- **FHE Operations**: Uses Zama's FHE library for encrypted operations
  - `FHE.add()` - Zama FHEVM operation
  - `FHE.sub()` - Zama FHEVM operation
  - `FHE.mul()` - Zama FHEVM operation
  - `FHE.eq()` - Zama FHEVM operation
  - `FHE.xor()` - Zama FHEVM operation

- **Encrypted Types**: Uses Zama's encrypted integer types
  - `euint64` - 64-bit encrypted unsigned integer
  - `externalEuint64` - External encrypted value from user

- **Access Control**: Uses Zama's permission system
  - `FHE.allowThis()` - Allow contract to use encrypted values
  - `FHE.allow()` - Allow specific user to decrypt
  - `FHE.allowTransient()` - Temporary permission for single operation
  - `FHE.fromExternal()` - Convert external encrypted values to internal

### Zama FHEVM Imports

```solidity
// Zama FHEVM Core Library - FHE operations and encrypted types
import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";

// Zama Network Configuration - Provides network-specific settings
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
```

### Zama FHEVM Code Example

```solidity
// Using Zama FHEVM's encrypted integer type
euint64 private encryptedValue;

// Converting external encrypted value to internal (Zama FHEVM)
euint64 internalValue = FHE.fromExternal(encryptedValue, inputProof);
FHE.allowThis(internalValue); // Zama FHEVM permission system

// Performing encrypted operations using Zama FHEVM
euint64 result = FHE.add(encryptedValue, FHE.asEuint64(1));
FHE.allowThis(result);
```

### FHEVM Concepts You'll Learn

1. **Encrypted Arithmetic**: Learn how to use Zama FHEVM for encrypted arithmetic
2. **Encrypted Comparison**: Learn how to use Zama FHEVM for encrypted comparison
3. **External Encryption**: Learn how to use Zama FHEVM for external encryption
4. **Permission Management**: Learn how to use Zama FHEVM for permission management
5. **Entropy Integration**: Learn how to use Zama FHEVM for entropy integration

### Learn More About Zama FHEVM

- 📚 [Zama FHEVM Documentation](https://docs.zama.org/protocol)
- 🎓 [Zama Developer Hub](https://www.zama.org/developer-hub)
- 💻 [Zama FHEVM GitHub](https://github.com/zama-ai/fhevm)



## 🔍 Contract Code

```solidity
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "./IEntropyOracle.sol";

/**
 * @title EntropyCounter
 * @notice Counter using EntropyOracle for encrypted randomness
 * @dev Example demonstrating EntropyOracle integration: using entropy for counter increments
 * 
 * This example shows:
 * - How to integrate with EntropyOracle
 * - How to use encrypted entropy in FHE operations
 * - How to combine entropy with encrypted values
 * - Entropy-based counter increments
 */
contract EntropyCounter is ZamaEthereumConfig {
    // Entropy Oracle interface
    IEntropyOracle public entropyOracle;
    
    // Encrypted counter value
    euint64 private counter;
    
    // Counter initialized flag
    bool private initialized;
    
    // Track entropy requests for increments
    mapping(uint256 => bool) public incrementRequests;
    uint256 public incrementCount;
    
    event CounterInitialized(address indexed initializer);
    event IncrementRequested(uint256 indexed requestId, address indexed caller);
    event CounterIncremented(uint256 indexed requestId, address indexed caller);
    
    /**
     * @notice Constructor - sets EntropyOracle address
     * @param _entropyOracle Address of EntropyOracle contract
     */
    constructor(address _entropyOracle) {
        require(_entropyOracle != address(0), "Invalid oracle address");
        entropyOracle = IEntropyOracle(_entropyOracle);
    }
    
    /**
     * @notice Initialize counter with an encrypted value
     * @param encryptedValue Encrypted initial value (euint64)
     * @param inputProof Input proof for encrypted value
     * @dev Must be called before incrementing. Can only be called once.
     */
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
    
    /**
     * @notice Request entropy for counter increment
     * @param tag Unique tag for this increment request
     * @return requestId Request ID from EntropyOracle
     * @dev Requires 0.00001 ETH fee. Call incrementWithEntropy() after request is fulfilled.
     */
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
    
    /**
     * @notice Increment counter using entropy from EntropyOracle
     * @param requestId Request ID from requestIncrement()
     * @dev Uses entropy to add randomness to counter increment
     */
    function incrementWithEntropy(uint256 requestId) external {
        require(initialized, "Counter not initialized");
        require(incrementRequests[requestId], "Invalid request ID");
        require(entropyOracle.isRequestFulfilled(requestId), "Entropy not ready");
        
        // Get encrypted entropy from oracle
        euint64 entropy = entropyOracle.getEncryptedEntropy(requestId);
        
        // Allow contract to use entropy
        FHE.allowThis(entropy);
        
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
    
    /**
     * @notice Simple increment without entropy (for comparison)
     * @dev Uses FHE.add to increment the encrypted value by 1
     * @dev Requires counter to be initialized
     */
    function increment() external {
        require(initialized, "Counter not initialized");
        
        // Increment encrypted counter using FHE.add
        euint64 one = FHE.asEuint64(1);
        FHE.allowThis(one);
        counter = FHE.add(counter, one);
        FHE.allowThis(counter);
        
        emit CounterIncremented(0, msg.sender); // requestId = 0 for simple increment
    }
    
    /**
     * @notice Check if counter is initialized
     * @return True if counter has been initialized
     */
    function isInitialized() external view returns (bool) {
        return initialized;
    }
    
    /**
     * @notice Get the encrypted counter value
     * @return Encrypted counter value (euint64)
     * @dev Returns encrypted value - must be decrypted off-chain to see actual value
     */
    function getCounter() external view returns (euint64) {
        require(initialized, "Counter not initialized");
        return counter;
    }
    
    /**
     * @notice Get EntropyOracle address
     * @return Address of EntropyOracle contract
     */
    function getEntropyOracle() external view returns (address) {
        return address(entropyOracle);
    }
    
    /**
     * @notice Get increment count
     * @return Total number of increment requests made
     */
    function getIncrementCount() external view returns (uint256) {
        return incrementCount;
    }
}

```

## 🧪 Tests

See [test file](./test/EntropyCounter.test.ts) for comprehensive test coverage.

```bash
npm test
```


## 📚 Category

**basic**



## 🔗 Related Examples

- [All basic examples](https://github.com/zacnider/entrofhe/tree/main/examples)

## 📝 License

BSD-3-Clause-Clear
