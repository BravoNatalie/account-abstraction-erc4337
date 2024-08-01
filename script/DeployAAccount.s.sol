// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; 
import {AAccount} from  "src/ethereum/AAccount.sol";

contract DeployAAccount is Script {
  function run() public {}

  function deployAAccount() public returns (HelperConfig, AAccount){
    HelperConfig helperConfig = new HelperConfig();
    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    vm.startBroadcast(config.account);

    AAccount aAccount = new AAccount(config.entryPoint);
    aAccount.transferOwnership(config.account);

    vm.stopBroadcast();

    return (helperConfig, aAccount);
  }
}