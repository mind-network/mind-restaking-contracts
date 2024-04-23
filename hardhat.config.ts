import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('@openzeppelin/hardhat-upgrades');

import { deployAccount, testAccount } from "./secrets";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
      chainId: 31337
    },
    sepolia: {
      url: "https://rpc.sepolia.org/",
      accounts: [deployAccount["General"], testAccount["General"]],
      chainId: 11155111
    },
    holesky: {
      url: "https://ethereum-holesky.publicnode.com/",
      accounts: [deployAccount["Holesky"]],
      chainId: 17000
    }
  },
};

export default config;
