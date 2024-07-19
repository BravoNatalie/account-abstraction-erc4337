// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

// zkSync Era Imports
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

// OZ Imports
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Lifecycle of a type 113 (0x71) transaction
 * msg.sender is the bootloader system contract
 *
 * Phase 1 Validation (light node)
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 * 2. The zkSync API client checks to see the the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 Execution (main node)
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executeTransaction
 * 9. If a paymaster was used, the postTransaction is called
 */
contract ZkMinimalAccount is IAccount, Ownable {
  using MemoryTransactionHelper for Transaction;

  ////////////////////  ERRORS  ////////////////////////
  error ZkMinimalAccount__NotEnoughBalance();
  error ZkMinimalAccount__NotFromBootLoader();
  error ZkMinimalAccount__ExecutionFailed();
  error ZkMinimalAccount__NotFromBootLoaderOrOwner();
  error ZkMinimalAccount__FailedToPay();
  error ZkMinimalAccount__InvalidSignature();


  ////////////////////  MODIFIERS  ////////////////////////
  modifier requireFromBootLoader() {
    if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
        revert ZkMinimalAccount__NotFromBootLoader();
    }
    _;
  }

  modifier requireFromBootLoaderOrOwner() {
    if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
        revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
    }
    _;
  }


  ////////////////////  EXTERNAL FUNCTIONS  ////////////////////////
  constructor() Ownable(msg.sender) {}

  receive() external payable {}

  /**
   * @notice Since this version does not have a paymaster, we need to check if there's enough balance in our account
   */
  function validateTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external payable requireFromBootLoader returns (bytes4 magic){
    return _validateTransaction(_transaction);
  }

  /**
   * @notice only the bootloader can call this function. The paymaster is going to pay for the gas.
   */
  function executeTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external requireFromBootLoaderOrOwner payable {
    return _executeTransaction(_transaction);
  }

  /**
   * @notice we can sign a transaction and allow anyone to call this function. Who is calling is going to pay for the gas.
   */
  function executeTransactionFromOutside(Transaction memory _transaction) external payable {
    bytes4 magic = _validateTransaction(_transaction);
    if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
      revert ZkMinimalAccount__InvalidSignature();
    }
    _executeTransaction(_transaction);
  }

  function payForTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external payable {
    bool success = _transaction.payToTheBootloader();
    if (!success) {
      revert ZkMinimalAccount__FailedToPay();
    }
  }

  function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction) external payable{ 

  }

  ////////////////////  INTERNAL FUNCTIONS  ////////////////////////

  function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic){
    // zksync system call simulation, this is used to call the NonceHolder system contract
    SystemContractsCaller.systemCallWithPropagatedRevert(
      uint32(gasleft()), 
      address(NONCE_HOLDER_SYSTEM_CONTRACT), 
      0, 
      abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
    );

    // check the fee to pay
    uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
    if(totalRequiredBalance > address(this).balance){
      // TODO: add logic for paymaster
      revert ZkMinimalAccount__NotEnoughBalance();
    }

    // check the signature
    bytes32 txHash = _transaction.encodeHash();
    address signer = ECDSA.recover(txHash, _transaction.signature);

    bool isValidSigner = signer == owner();
    if (isValidSigner) {
      magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
    } else {
      magic = bytes4(0);
    }
    return magic;
  }

  function _executeTransaction(Transaction memory _transaction) internal {
    address to = address(uint160(_transaction.to));
    uint128 value = Utils.safeCastToU128(_transaction.value);
    bytes memory data = _transaction.data;

    if(to == address(DEPLOYER_SYSTEM_CONTRACT)){
      uint32 gas = Utils.safeCastToU32(gasleft());
      SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
    }else{
      bool success;
      assembly {
        // (success,) = payable(msg.sender).call{value:missingAccountFunds, gas: type(uint256).max}("");
        success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
      }
      if(!success){
        revert ZkMinimalAccount__ExecutionFailed();
      }
    }
  }
}