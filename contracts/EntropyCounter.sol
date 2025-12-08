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
