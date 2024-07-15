// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


contract MinimalAccount is IAccount, Ownable {
  ////////////////////  ERRORS  ////////////////////////
  error MinimalAccount__CallFailed(bytes);
  error MinimalAccount__NotFromEntryPoint();
  error MinimalAccount__NotFromEntryPointOrOwner();

  ////////////////////  STATE VARIABLES  ////////////////////////
  IEntryPoint private immutable i_entryPoint;

  ////////////////////  MODIFIERS  ////////////////////////
  modifier requireFromEntryPoint() {
    if (msg.sender != address(i_entryPoint)) {
        revert MinimalAccount__NotFromEntryPoint();
    }
    _;
  }

  modifier requireFromEntryPointOrOwner() {
    if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
        revert MinimalAccount__NotFromEntryPointOrOwner();
    }
    _;
  }

  ////////////////////  FUNCTIONS  ////////////////////////
  constructor(address entryPoint) Ownable(msg.sender){
    i_entryPoint = IEntryPoint(entryPoint);
  }

  receive() external payable {}

  ////////////////////  EXTERNAL FUNCTIONS  ////////////////////////
  function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external requireFromEntryPoint() returns (uint256 validationData) {
    validationData = _validateSignature(userOp, userOpHash);
    // TODO: _validateNonce()
    _payPrefund(missingAccountFunds);
  }

  //TODO: add natspec
  function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
    (bool success, bytes memory result) = dest.call{value:value}(functionData);
    if(!success){
      revert MinimalAccount__CallFailed(result);
    }
  }

  ////////////////////  INTERNAL FUNCTIONS  ////////////////////////
  // EIP-191 version of signed hash
  function  _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256 validationData){
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

  function _payPrefund(uint256 missingAccountFunds) internal {
    // payback the entrypoint contract
    if(missingAccountFunds != 0){
      (bool success,) = payable(msg.sender).call{value:missingAccountFunds, gas: type(uint256).max}("");
      (success);
    }
  }

  ////////////////////  GETTERS  ////////////////////////
  function getEntryPoint() external view returns (address) {
    return address(i_entryPoint);
  }
}  