import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { constants, utils } from 'ethers'

const account0 = ''
const account1 = ''
const account2 = ''
const account3 = ''
const account4 = ''
const account5 = ''
const account6 = ''
const account7 = ''
const account8 = ''
const account9 = ''

const account_a = ''
const account_b = ''
const account_c = ''

let daocredit = null
let daonft = null

describe('Abidao', function () {
  async function deployAbidaoFixture() {
    const [owner, receipt, alice, bob] = await ethers.getSigners()
  }

  describe('Deployment', function () {
    it('Should get the right contract address', async function () {
      const DaoCredit = await ethers.getContractFactory('DaoCredit')
      daocredit = await DaoCredit.attach('')
      await daocredit.deployed()

      const DaoNft = await ethers.getContractFactory('DaoNft')
      daonft = await DaoNft.attach('')
      await daonft.deployed()

      await daocredit.upgradeNftMaster('')

    })
  })

})
