const { assertRevert } = require('zos-lib');

const BigNumber = web3.BigNumber;
const encodeCall = require('zos-lib/lib/helpers/encodeCall').default;

const AmuletToken = artifacts.require('AmuletToken');
const KittyMock = artifacts.require('KittyMock');

const should = require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .use(require('chai-as-promised'))
  .should();

function checkDepositEvent(log, kittyId, depositor) {
  log.event.should.be.eq('LogKittieDeposited');
  log.args.assetId.should.be.bignumber.equal(kittyId);
  log.args.depositor.should.be.equal(depositor);
}

function checkWithdrawEvent(log, kittyId, withdrawer) {
  log.event.should.be.eq('LogKittieWithdrawed');
  log.args.assetId.should.be.bignumber.equal(kittyId);
  log.args.withdrawer.should.be.equal(withdrawer);
}

function checkForgeEvent(log, forger) {
  log.event.should.be.eq('LogAmuletForged');
  log.args.owner.should.be.equal(forger);
}

function checkUnForgeEvent(log, amuletId, unforger) {
  log.event.should.be.eq('LogAmuletUnForged');
  log.args.assetId.should.be.bignumber.equal(amuletId);
  log.args.owner.should.be.equal(unforger);
}


contract('AmuletToken', ([_, owner, aWallet, someone, anotherone]) => {
  
  const txParams = {};
  let contract;
  
  async function newContract(fromAddress, kittyMock) {
    const amuletToken = await AmuletToken.new({ from: fromAddress });
    const callData = encodeCall('initialize', ['address', 'address'], [fromAddress, kittyMock]);
    
    await amuletToken.sendTransaction({data: callData, from: fromAddress});

    return amuletToken;
  }

  async function newKittyMock(fromAddress, kittiesOwner) {
    const kittyMock = await KittyMock.new({ from: fromAddress });
    
    // Create 19 test kitties with random genes.
    for (let kittyId = 1; kittyId < 20; kittyId++) {
      let d = Math.random();
      let kittyGenes = web3.sha3(d.toString());

      // Create mock kitty. Ids starts from 1 
      kittyMock.createKitty(kittyId, kittyGenes, { from: kittiesOwner });
    }

    return kittyMock;
  }

  // Set up contracts first. 
  before(async function() {
    const kittyMock = await newKittyMock(owner, someone);
    contract = await newContract(owner, kittyMock.address);
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
      const kittyId = 1;      
      const { logs } = await contract.depositKitty(kittyId, { from: someone });

      checkDepositEvent(logs[0], kittyId, someone);
    });
    
    it('Should assert deposited kitties == 1', async () => {
      const escrowedLen = await contract.getTotalEscrowed(someone);

      escrowedLen.should.be.bignumber.equal(1);
    })

    it('Should WITHDRAW an escrowed kitty', async () => {
      const kittyId = 1;
      const { logs } = await contract.withdrawKitty(kittyId, { from: someone });

      checkWithdrawEvent(logs[0], kittyId, someone);
    });

    it('Should FAIL TO WITHDRAW an escrowed kitty from another wallet', async () => {
      const kittyId = 1;

      await contract.depositKitty(kittyId, { from: someone });
      await assertRevert(
        contract.withdrawKitty(kittyId, { from: anotherone })
      );
    });
  });

  describe('Amulates', function () {
    it('Should FORGE new amulet', async () => {
      // We have a kitty deposited, now we add 
      // 10 more kitties in escrow from kittyId 2 to kittyId 11.
      for (let kittyId = 2; kittyId < 12; kittyId++) {
        await contract.depositKitty(kittyId, { from: someone });
      }

      const { logs } = await contract.forgeAmulet({ from: someone });

      // logs[0] == Transfer envent. 
      checkForgeEvent(logs[1], someone);
    });

    it('Should check correct escrowed kitties', async () => {
      const escrowedIds = await contract.getEscrowedIds(someone);

      // There should be just one kitty unforged (kittyId = 1)
      escrowedIds.should.have.lengthOf(1);
      escrowedIds[0].should.be.bignumber.equal(1);
    });

    it('Should check correct forged kitties', async () => {
      const amuletId = 0;
      const forgedArray = await contract.getForgetForAmulet(amuletId);
      
      forgedArray.should.have.lengthOf(10);
    });

    it('Should FAIL TO WITHDRAW an already forged kitty', async () => {
      const kittyId = 11;
      await assertRevert(
        contract.withdrawKitty(kittyId, { from: someone })
      );
    });

    it('Should UNFORGE amulet', async () => {
      //checkUnForgeEvent(logs[0], someone);
    });
  });
  
});