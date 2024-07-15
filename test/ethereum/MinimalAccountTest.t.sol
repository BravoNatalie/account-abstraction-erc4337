// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from  "src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
  using MessageHashUtils for bytes32;

  HelperConfig helperConfig;
  MinimalAccount minimalAccount;
  SendPackedUserOp sendPackedUserOp;
  ERC20Mock usdc;

  address randomUser = makeAddr("randomUser");

  uint256 constant AMOUNT = 1e18;

  function setUp() public {
    DeployMinimalAccount deployMinimalAccount = new DeployMinimalAccount();
    (helperConfig, minimalAccount) = deployMinimalAccount.deployMinimalAccount();
    sendPackedUserOp = new SendPackedUserOp();
    usdc = new ERC20Mock();
  }

  /**
    Test Scenerio: USDC Approval

    Description:
      0. USDC Mint
      1. msg.sender --call-> MinimalAccount
      2. approve some amount
      3. USDC contract
      4. come from the entrypoint
   */

  /**
    @dev Test if the minimalAccount owner can mint a erc20 token
  */
  function testOwnerCanExecuteCommands() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);

    address dest =  address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

    // Act
    vm.prank(minimalAccount.owner());
    minimalAccount.execute(dest, value, functionData);

    // Assert
    assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
  }

  function testNonOwnerCannotExecuteCommands() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);

    address dest =  address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

    // Act
    vm.prank(randomUser);
    vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
    minimalAccount.execute(dest, value, functionData);
  }

  function testRecoverSignedOp() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);

    // tells the AA contract to call the erc20 contract and mint
    address dest =  address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

    // tells the entryPoint contract to call the AA contract and make the above call
    bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig());
    bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    
    // Act
    address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
    console2.log("minimalaccount: ", minimalAccount.owner());
    console2.log("actualSigner: ", actualSigner);
    // Assert
    assertEq(actualSigner, minimalAccount.owner());
  }

  function testValidationOfUserOps() public {
    // Arrange


    // Act


    // Assert
  }

}