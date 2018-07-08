const { assertRevert } = require('zos-lib');

module.exports = function(owner, aWallet, someone, anotherone) {

  describe('Test genes masks management', function () {
 
    // Format => [ MASK, MASK_RESULT, MASK_VALUE ] 
    const masksArr = [
      [ '0x0000000000000000000000000000000000000000001f00000000000000000000', '0x0000000000000000000000000000000000000000000500000000000000000000', 2 ], // mauveover (D) - colorprimary
      [ '0x000000000000000000000000000000000000000003e000000000000000000000', '0x000000000000000000000000000000000000000000a000000000000000000000', 1 ] // mauveover (R1) - colorprimary
    ];
    
    it('Should ADD genes mask', async () => {
      for (let item of masksArr) {
        await this.contract.updateMask(item[0], item[1], item[2], { from: owner });
      }
    });

    it('Should REMOVE genes mask', async () => {
      for (let item of masksArr) {
        await this.contract.removeMask(item[0], { from: owner });
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

}