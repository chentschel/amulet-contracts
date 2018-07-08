const validateAddress = require('./helpers/validateAddress.js');
const shouldBehaveLikeAmuletToken = require('./AmuletToken.behavior.js');

const should = require('chai').should();

const { decodeLogs, Logger, App, AppDeployer, Contracts } = require('zos-lib');

const AmuletToken = Contracts.getFromLocal('AmuletToken');
const ImplementationDirectory = Contracts.getFromNodeModules('zos-lib', 'ImplementationDirectory');

contract('App', ([_, owner, aWallet, someone, anotherone]) => {
  
  const initialVersion = '0.1.0';
  const contractName = "AmuletToken";
  const txParams = {
    from: owner
  };
  
  describe('setup', function() {
  
    beforeEach(async function() {
      this.app = await App.deploy(initialVersion, txParams);
    });

    describe('package', function() {

      describe('when queried for the initial version', function() {

        it('claims to have it', async function() {
          (await this.app.package.hasVersion(initialVersion)).should.be.true;
        });
      });

    });
  });

  describe('version 0.1.0', function() {
  
    beforeEach(async function() {
      this.app = await App.deploy(initialVersion, txParams);
      await this.app.setImplementation(AmuletToken, contractName);
      
      this.contract = await this.app.createProxy(
        AmuletToken, contractName, 'initialize', [owner, '0x0']
      );
    });

    describe('directory', function() {

      describe('when queried for the implementation', function() {
        
        it('returns a valid address', async function() {
          validateAddress(await this.app.directories[initialVersion].getImplementation(contractName)).should.be.true;
        });
      });
    });

    describe('implementation', function() {
      console.log("=====>", this.contract);
      shouldBehaveLikeAmuletToken(owner, aWallet, someone, anotherone);
    });

  });
  
});