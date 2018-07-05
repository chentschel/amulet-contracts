pragma solidity 0.4.24;

import "./KittyCoreI.sol";
import "../node_modules/openzeppelin-zos/contracts/token/ERC721/ERC721Token.sol";

contract AmuletToken is ERC721Token, Ownable {

    using SafeMath for uint256;

    /* EVENTS */
    event LogKittieDeposited(uint256 indexed assetId, address indexed depositor);
    event LogKittieWithdrawed(uint256 indexed assetId, address indexed withdrawer);

    event LogAmuletForged(uint256 indexed assetId, address indexed owner);
    event LogAmuletUnForged(uint256 indexed assetId, address indexed owner);

    KittyCoreI public kittyCore;

    // Amulet Power for a given tokenId
    struct AmuletInfo {
        uint32 amuletPower;
        uint256[] forgedKitties;
    }

    // Mapping of forged amulets. 
    // It keeps tracking of amulet value and forged kitties.
    mapping(uint256 => AmuletInfo) amuletsMap;

    // Used to store masks info
    struct MaskInfo {
        uint32 maskIndex;
        uint32 maskValue;
        uint256 maskResult;
    }

    // Gene mask mappings
    mapping(uint256 => MaskInfo) maskInfoMap;

    // Array of configured masks
    uint256[] masksArray;

    // Max Masks add value. This is used to scale new amulates values. 
    uint32 maxMaskValue;

    // Scale fot amulate power value => (0 - AMULATE_POWER_SCALE)
    uint256 constant AMULATE_POWER_SCALE = 10;

    // Arr of ERC721 held in escrow by user
    mapping(address => uint256[]) escrowedMap;

    // escrowed kitties mappings
    mapping(address => mapping(uint256 => uint256)) escrowedIndexMap;


    /**
     * Constructor
     */
    constructor(address _kittyCore) public {
        kittyCore = KittyCoreI(_kittyCore);
    }


    /**
     * Adds or updates a gene mask
     * @param _mask value to add or update to gene masks mapping.
     * @param _result value after mask applied to a kittie gene.
     * @param _value value used to calculate final amulate power value. 
     */
    function updateMask(uint256 _mask, uint256 _result, uint32 _value) public onlyOwner {            
        if (maskInfoMap[_mask].maskValue == 0) {
            maskInfoMap[_mask].maskIndex = masksArray.length;
            
            // Add to array
            masksArray.push(_mask);

            // Update max mask values;
            maxMaskValue += _value;
        }
        maskInfoMap[_mask].maskValue = _value;
        maskInfoMap[_mask].maskResult = _result;
    }

    /**
     * Remove genes mask from mappings
     * @param _mask value to remove from mapping.
     */
    function removeMask(uint256 _mask) public onlyOwner {
        if (maskInfoMap[_mask].maskValue != 0) {
            
            // Reorg masks array
            uint256 maskIndex = maskInfoMap[_mask].maskIndex;
            uint256 lastMaskIndex = masksArray.length.sub(1);

            // Override element bucket with last array item
            // and delete last bucket.
            masksArray[maskIndex] = masksArray[lastMaskIndex];
            masksArray[lastMaskIndex] = 0;
            
            masksArray.length -= 1;
            
            // Update max mask values
            maxMaskValue -= maskInfoMap[_mask].maskValue;

            // remove mask from mapping
            delete maskInfoMap[_mask];
        }
    }

    /**
     * Deposit kitty. Transfer ownership of the kittie to this contract.
     */
    function depositKitty(uint256 _kittyId) public {
        // Transfer this asset ownership
        nfRegistry.transferFrom(msg.sender, address(this), _kittyId);

        // Add kittie to escrowed
        uint256 lastIndex = escrowedMap[msg.sender].length;

        escrowedIndexMap[msg.sender][_kittyId] = lastIndex;
        escrowedMap[msg.sender].push(_kittyId);

        emit LogKittieDeposited(_kittyId, msg.sender);
    }

    /**
     * Withdraw kitty. Returns ownership to original depositor. 
     */
    function withdrawKitty(uint256 _kittyId) public {
        uint256 index = escrowedIndexMap[msg.sender][_kittieId];
        uint256 lastIndex = escrowedMap[msg.sender].length.sub(1);

        // Check if kitty is on escrow list
        require(escrowedMap[msg.sender][index] > 0, "kitty not on escrow list");

        // Transfer ownership back to msg.sender
        nfRegistry.transferFrom(address(this), msg.sender, _kittyId);
        
        // Reorg escrowed array. 
        escrowedMap[msg.sender][index] = escrowedMap[msg.sender][lastIndex];
        escrowedMap[msg.sender][lastIndex] = 0;
        escrowedMap[msg.sender].length -= 1;

        delete escrowedIndexMap[msg.sender][_kittieId];

        emit LogKittieWithdrawed(_kittyId, msg.sender);
    }

    /**
     * Forge deposited kitties into a new Amulet granted to the msg.sender.
     */
    function forgeAmulet() public {
        uint256 escrowedLen = escrowedMap[msg.sender].length;
        
        requires(escrowedLen > 0, "theres no deposited kitties to forge an amulet");

        uint32 amuletPower = 0;
        uint256 storage forgedKitties = [];

        for (uint i = 0; i < escrowedLen; i++) {
            uint256 kittyId = escrowedMap[msg.sender][i];

            // Adds up all kitties' scores based on cattributes.
            amuletPower += getKittyScore(kittyId);

            // Push to forged and remove from mappinig. 
            // We'll remove it from the escrowed array later. 
            forgedKitties.push(kittyId);
            delete escrowedIndexMap[msg.sender][kittyId];
        }

        // One we get powerValue calculated from 
        // all escrowed kitties, let's forge a new amulet token

        // Use ERC721 tokenIndex as amuletId. 
        uint256 amuletId = allTokens.length;
       
        // Calculate scaled amulate power
        uint32 scaledAmulatePower = AMULATE_POWER_SCALE.mul(amuletPower.div(maxMaskValue));

        // Mint amulet
        _mint(msg.sender, amuletId);
        
        // Keep tokens
        amuletsMap[amuletId] = AmuletInfo({
            amuletPower: scaledAmulatePower,
            forgedKitties: forgedKitties
        });

        // Clear array for future deposited kitties
        // that will eventuually forge a new amulet.
        delete escrowedMap[msg.sender];

        emit LogAmuletForged(amuletId, msg.sender);
    }

    /**
     * Unforge an amulete, leave all forged kitties available 
     * to re-forge or withdraw.
     */
    function unforgeAmulet(uint256 _tokenId) public onlyOwnerOf {
        uint256 escrowedLen = amuletsMap[amuletId].forgedKitties.length;

        // Move unforged kitties to escrowed list
        for (uint i = 0; i < escrowedLen; i++) {     
            uint256 kitty = amuletsMap[amuletId].forgedKitties[i];

            escrowedMap[msg.sender].push(kitty);
            escrowedIndexMap[msg.sender][escrowedLen + i] = kitty;
        }
        
        delete amuletsMap[amuletId];
        
        _burn(msg.sender, _tokenId);

        emit LogAmuletUnForged(amuletId, msg.sender);
    }

    /**
     * Gets the kittie genes from KittiesCore contract and returns a 
     * value based on genes' masks configured values
     */
    function getKittyScore(uint256 _kittyId) private view returns (uint8) {
        
        uint32 kittieScore = 0;
        uint256 kittieGenes;

        // Get kitty genes           
        ( , , , , , , , , , kittieGenes) = kittyCore.getKitty(_kittyId);

        for (uint i = 0; i < masksArray.length; i++) {
            uint256 _mask = masksArray[i];

            if (kittieGenes & _mask == maskArray[_mask].maskResult) {
                kittieScore += maskArray[_mask].maskValue;
            }
        }
        return amuletScore;
    }
}