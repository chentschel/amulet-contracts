const should = require('chai').should();
const shouldBehaveLikeAmulateToken = require('./AmulateToken.behavior.js');

const { decodeLogs, Logger, App, AppDeployer, Contracts } = require('zos-lib');

const AmulateToken = Contracts.getFromLocal('AmulateToken');
const ImplementationDirectory = Contracts.getFromNodeModules('zos-lib', 'ImplementationDirectory');

contract('App', ([_, owner, aWallet, someone, anotherone]) => {
  
  const initialVersion = '0.0.1';
  const contractName = "AmulateToken";
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

      describe('when queried for the updated version', function() {

        it('doesnt claim to have it', async function() {
          (await this.app.package.hasVersion(updatedVersion)).should.be.false;
        });
      });

    });
  });

  describe('version 0.0.1', function() {
  
    beforeEach(async function() {
      this.app = await App.deploy(initialVersion, txParams);
      await this.app.setImplementation(AmulateToken, contractName);
      this.amulateToken = await this.app.createProxy(AmulateToken, contractName, 'initialize', [owner]);
    });

    describe('directory', function() {

      describe('when queried for the implementation', function() {

        it('returns a valid address', async function() {
          validateAddress(await this.app.directories[initialVersion].getImplementation(contractName)).should.be.true;
        });
      });

    });

    describe('implementation', function() {
      shouldBehaveLikeAmulateToken(owner, aWallet, someone, anotherone);
    });

  });
  
});