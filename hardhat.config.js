require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("@nomicfoundation/hardhat-verify");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: { compilers: [{ version: "0.8.18", }, { version: "0.6.0", }, { version: "0.7.0", settings: {}, }], },
  networks: {
    goerli: {
      url :`https://goerli.infura.io/v3/bc73a0b80fd34825b19a824eb43a7b64`,
      accounts: [""],
    },
  },
  etherscan : {
    apiKey: "W4FSKTPHY46TMKAEWYS9IU1BMRI92Z9YTF",
  }

};
