// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "lib/account-abstraction/contracts/core/UserOperationLib.sol";
import {TokenCallbackHandler} from "lib/account-abstraction/contracts/samples/callback/TokenCallbackHandler.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract AAccount is IAccount, Ownable, TokenCallbackHandler {
  using ECDSA for bytes32;
  using UserOperationLib for PackedUserOperation;

  error AAccount__CallFailed(bytes);
  error AAccount__NotFromEntryPoint();
  error AAccount__NotFromEntryPointOrOwner();
  error AAccount_WrongBatchProvided(uint256 destLength, uint256 valueLength, uint256 functionDataLength);


  event AAccountReceivedNativeToken(address indexed sender, uint256 indexed value);


  IEntryPoint private immutable _entryPoint;


  modifier requireFromEntryPoint() {
    if (msg.sender != address(_entryPoint)) {
        revert AAccount__NotFromEntryPoint();
    }
    _;
  }

  modifier requireFromEntryPointOrOwner() {
    if (msg.sender != address(_entryPoint) && msg.sender != owner()) {
        revert AAccount__NotFromEntryPointOrOwner();
    } 
    _;
  }


  constructor(address entryPointAddr) Ownable(msg.sender){
    _entryPoint = IEntryPoint(entryPointAddr);
  }


  function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external requireFromEntryPoint() returns (uint256 validationData) {
    validationData = _validateSignature(userOp, userOpHash);
    _payPrefund(missingAccountFunds);
  }

  /**
   * execute a transaction (called directly from owner, or by entryPoint)
   * @param dest destination address to call
   * @param value the value to pass in this call
   * @param functionData the calldata to pass in this call
   */
  function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
    _call(dest, value, functionData);
  }

  /**
   * execute a sequence of transactions
   * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
   * @param dest an array of destination addresses
   * @param value an array of values to pass to each call. can be zero-length for no-value calls
   * @param functionData an array of calldata to pass to each call
   */
  function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata functionData) external requireFromEntryPointOrOwner {
    if(dest.length != functionData.length ||(value.length != 0 && value.length != functionData.length)){
      revert AAccount_WrongBatchProvided(dest.length, value.length, functionData.length);
    }

    if (value.length == 0) {
      for (uint256 i = 0; i < dest.length; i++) {
        _call(dest[i], 0, functionData[i]);
      }
    } else {
      for (uint256 i = 0; i < dest.length; i++) {
        _call(dest[i], value[i], functionData[i]);
      }
    }
  }

  
  // EIP-191 version of signed hash
  function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256 validationData){
    /**
    * This could be anything for the signature valitation, but in thi example we are going to use the owner of the contract
     */
    bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

    if(signer != owner()){
      return SIG_VALIDATION_FAILED;
    }
    return SIG_VALIDATION_SUCCESS;
  }


  /**
   * sends to the entrypoint (msg.sender) the missing funds for this transaction.
   * subclass MAY override this method for better funds management
   * (e.g. send to the entryPoint more than the minimum required, so that in future transactions
   * it will not be required to send again)
   * @param missingAccountFunds the minimum value this method should send the entrypoint.
   *  this value MAY be zero, in case there is enough deposit, or the userOp has a paymaster.
   */
  function _payPrefund(uint256 missingAccountFunds) internal {
    if(missingAccountFunds != 0){
      (bool success,) = payable(msg.sender).call{value:missingAccountFunds, gas: type(uint256).max}("");
      (success);
    }
    //ignore failure (its EntryPoint's job to verify, not account.)
  }

  function _call(address dest, uint256 value, bytes calldata functionData) internal {
    (bool success, bytes memory result) = dest.call{value:value}(functionData);
    if(!success){
      revert AAccount__CallFailed(result);
    }
  }

  /**
   * Return the account nonce.
   * This method returns the next sequential nonce.
   * For a nonce of a specific uint192 key, use `entrypoint.getNonce(account, key)`
   */
  function getNonce() public view virtual returns (uint256) {
    // keeping it simple and using only the default key 0
    return entryPoint().getNonce(address(this), 0);
  }

  /**
   * Return the entryPoint used by this account.
  */
  function entryPoint() public view returns (IEntryPoint) {
    return _entryPoint;
  }

  /**
   * Checks the balance of the AAccount within EntryPoint.
   */
  function getDeposit() public view returns (uint256) {
    return entryPoint().balanceOf(address(this));
  }

  /**
   * Adds a deposit for AAccount in EntryPoint.
   */
  function addDeposit() public payable {
    entryPoint().depositTo{value: msg.value}(address(this));
  }

  /**
   * withdraw value from the account's deposit
   * @param withdrawAddress target to send to
   * @param amount to withdraw
  */
  function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
    entryPoint().withdrawTo(withdrawAddress, amount);
  }

  receive() external payable {
    emit AAccountReceivedNativeToken(msg.sender, msg.value);
  }
  
}  