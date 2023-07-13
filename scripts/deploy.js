const {ethers,upgrades} = require("hardhat");

async function main() {

  //const Box = await ethers.getContractFactory("Box");

  /*const box = await upgrades.deployProxy(Box, [42], {
    initializer: "initialize",
  });*/

const pool = await ethers.getContractFactory("Liquidity");
console.log("Deploying liquidity contract...");
//const lock = await upgrades.deployProxy("0xf92827b75548789f90F80bf490Bf00b4DBaACFd1", /{ value: lockedAmount }/ 10000000000);
const lock =await upgrades.deployProxy(pool, {
  initializer: "initialize",
  gasLimit: 3000000,
});

}
main();