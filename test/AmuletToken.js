const { assertRevert } = require('zos-lib');

const BigNumber = web3.BigNumber;
const AmuletToken = artifacts.require('AmuletToken');
const encodeCall = require('zos-lib/lib/helpers/encodeCall').default;

const should = require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .use(require('chai-as-promised'))
  .should();

contract('AmuletToken', ([_, owner, aWallet, someone, anotherone]) => {
  
  const txParams = {};
  let contract;
  
  async function newContract(fromAddress, kittyMock) {
    const contract = await AmuletToken.new({from: fromAddress});
    const callData = encodeCall('initialize', ['address', 'address'], [fromAddress, kittyMock]);
    
    await contract.sendTransaction({data: callData, from: fromAddress});

    return contract;
  }

  beforeEach(async function() {
    contract = await newContract(owner, 0x0);
  });

  describe('Test genes masks management', function () {

    // Format => [ MASK, MASK_RESULT, MASK_VALUE ] 
    const masksArr = [
      [ '0x0000000000000000000000000000000000000000001f00000000000000000000', '0x0000000000000000000000000000000000000000000500000000000000000000', 2 ], // mauveover (D) - colorprimary
      [ '0x000000000000000000000000000000000000000003e000000000000000000000', '0x000000000000000000000000000000000000000000a000000000000000000000', 1 ] // mauveover (R1) - colorprimary
    ];
    
    it('Should ADD genes mask', async () => {
      for (let item of masksArr) {
        await contract.updateMask(item[0], item[1], item[2], { from: owner });

        let [ maskIndex, maskValue, maskResult ] = await contract.maskInfoMap(item[0]);

        // Check mask result and value configured OK
        maskResult.should.be.bignumber.equal(item[1]);
        maskValue.should.be.bignumber.equal(item[2]);
      }
    });

    it('Should REMOVE genes mask', async () => {
      for (let item of masksArr) {
        await contract.updateMask(item[0], item[1], item[2], { from: owner });
        await contract.removeMask(item[0], { from: owner });

        let [ maskIndex, maskValue, maskResult ] = await contract.maskInfoMap(item[0]);

        // Check mask result and value configured OK
        maskResult.should.be.bignumber.equal(0);
        maskValue.should.be.bignumber.equal(0);
      }
    });

    it('Should FAIL TO ADD genes mask non owner', async () => {
      for (let item of masksArr) {
        await assertRevert(
          contract.updateMask(item[0], item[1], item[2], { from: someone })
        );
      }
    });

    it('Should FAIL TO REMOVE genes mask non owner', async () => {
      for (let item of masksArr) {
        await contract.updateMask(item[0], item[1], item[2], { from: owner });
        await assertRevert(
          contract.removeMask(item[0], { from: someone })
        );
      }
    });

  });

  describe('Test kitties management', function () {
    it('Should DEPOSIT an owned kitty', async () => {
      
    });

    it('Should WITHDRAW an escrowed kitty', async () => {
    
    });
  });

  describe('Amulates', function () {
    it('Should FORGE new amulet', async () => {
    
    });

    it('Should FAIL TO WITHDRAW an already forged kitty', async () => {
    
    });

    it('Should UNFORGE amulet', async () => {
    
    });
  });
  
});