// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; 
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AAccount} from "src/ethereum/AAccount.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SendPackedUserOp is Script {
  using MessageHashUtils for bytes32;

  // Make sure you trust this user - don't run this on Mainnet!
  address constant RANDOM_APPROVER = 0xB2613E02F232d00bCf060c2c70A9b60d0930959A;

  function run() public {
    // Setup
        HelperConfig helperConfig = new HelperConfig();
        address dest = helperConfig.getConfig().usdc; // USDC address
        uint256 value = 0;
        address aAccountAddress = DevOpsTools.get_most_recent_deployment("AAccount", block.chainid);

        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(AAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory userOp =
            generateSignedUserOperation(executeCalldata, helperConfig.getConfig(), aAccountAddress);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
  }

  function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config, address aAccount) public view returns (PackedUserOperation memory) {
    //uint256 nonce = vm.getNonce(aAccount) - 1;
    // Get the nonce for the wallet address with a key of 0
    uint256 nonce = IEntryPoint(config.entryPoint).getNonce(
      aAccount,
      0
    );

    PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, aAccount, nonce);

    bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
    bytes32 digest = userOpHash.toEthSignedMessageHash();


    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    if (block.chainid == 31337) {
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
    } else {
        (v, r, s) = vm.sign(config.account, digest);
    }
    
    userOp.signature = abi.encodePacked(r,s,v);
    return userOp;
  }

  function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce) internal pure returns (PackedUserOperation memory) {
    uint128 verificationGasLimit = 106533;
    uint128 callGasLimit = verificationGasLimit;
    uint128 maxPriorityFeePerGas = 256;
    uint128 maxFeePerGas = maxPriorityFeePerGas;

    return PackedUserOperation({
      sender: sender,
      nonce: nonce,
      callData: callData,
      initCode: hex"", // TODO: in the future consider initialize a contract
      accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
      preVerificationGas: verificationGasLimit,
      gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
      paymasterAndData: hex"",
      signature: hex""
    });
  }
}