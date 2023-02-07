import { ethers } from 'hardhat'
import { utils } from 'ethers'

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
      'Deploy wallet balance:',
      ethers.utils.formatEther(await deployer.getBalance())
  );
  console.log('Deployer wallet public key:', deployer.address);

  const DaoCredit = await ethers.getContractFactory('DaoCredit')
  const daoCredit = await DaoCredit.deploy()

  await daoCredit.deployed()

  console.log(`DaoCredit deployed to ${daoCredit.address}`)

  const DaoNft = await ethers.getContractFactory('DaoNft')
  const daoNft = await DaoNft.deploy(daoCredit.address)

  await daoNft.deployed()

  // await daocredit.upgradeNftMaster(daoNft.address)

  console.log(`DaoNft deployed to ${daoNft.address}`)  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
