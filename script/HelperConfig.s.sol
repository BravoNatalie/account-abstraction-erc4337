// SPDX-Licence-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
  error HelperConfig__InvalidChainId();

  struct NetworkConfig {
    address usdc;
    address account;
    address entryPoint;
  }

  uint256 constant LOCAL_CHAIN_ID = 31337;
  uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
  uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;

  address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address BURNER_WALLET = vm.envAddress("BURNER_WALLET");
 

  NetworkConfig public localNetworkConfig;
  mapping(uint256 chainId => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
  }

  function getConfig() public returns (NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
    if (chainId == LOCAL_CHAIN_ID) {
        return getOrCreateAnvilEthConfig();
    } else if (networkConfigs[chainId].account != address(0)) {
        return networkConfigs[chainId];
    } else {
        revert HelperConfig__InvalidChainId();
    }
  }

  function getEthSepoliaConfig() public view returns (NetworkConfig memory) {
    return NetworkConfig({
        entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
        usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
        account: BURNER_WALLET
    });
  }

  function getZkSyncSepoliaConfig() public view returns (NetworkConfig memory) {
    return NetworkConfig({
        entryPoint: address(0), // There is no entrypoint in zkSync!
        usdc: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E, // not the real USDC on zksync sepolia
        account: BURNER_WALLET
    });
  }

  function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // deploy mocks
        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        console2.log("Mocks deployed!");

        localNetworkConfig =
            NetworkConfig({entryPoint: address(entryPoint), usdc: address(erc20Mock), account: ANVIL_DEFAULT_ACCOUNT});
        return localNetworkConfig;
    }

}