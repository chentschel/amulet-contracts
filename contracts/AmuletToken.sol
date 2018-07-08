pragma solidity 0.4.24;

import "./KittyCoreI.sol";
import "../node_modules/openzeppelin-zos/contracts/math/Math.sol";
import "../node_modules/openzeppelin-zos/contracts/ownership/Ownable.sol";
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
    uint256 constant AMULATE_POWER_SCALE = 100;
    
    // Kitties limits in a forge operation 
    uint16 constant MIN_REQUIRED_KITTIES = 2;
    uint16 constant MAX_KITTIES_IN_FORGE = 10;

    // Arr of ERC721 held in escrow by user
    mapping(address => uint256[]) escrowedMap;

    // escrowed kitties mappings
    mapping(address => mapping(uint256 => uint256)) escrowedIndexMap;


    /**
     * Constructor
     */
    function initialize(address _sender, address _kittyCore) isInitializer("AmuletToken", "0.1.0") public {
        Ownable.initialize(_sender);
        kittyCore = KittyCoreI(_kittyCore);
    }

    /**
     * Adds or updates a gene mask
     * @param _mask value to add or update to gene masks mapping.
     * @param _result value after mask applied to a kittie gene.
     * @param _value value used to calculate final amulate power value. 
     */
    function updateMask(uint256 _mask, uint256 _result, uint32 _value) public onlyOwner {            
        // Check if we add a new mask
        if (maskInfoMap[_mask].maskValue == 0) {
            maskInfoMap[_mask].maskIndex = uint32(masksArray.length);
            
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
        kittyCore.transferFrom(msg.sender, address(this), _kittyId);

        // Add kittie to the end of escrowed array 
        // and save array index in escrowedIndexMap. 
        escrowedMap[msg.sender].push(_kittyId);
        escrowedIndexMap[msg.sender][_kittyId] = escrowedMap[msg.sender].length.sub(1);

        emit LogKittieDeposited(_kittyId, msg.sender);
    }

    /**
     * Withdraw kitty. Returns ownership to original depositor. 
     */
    function withdrawKitty(uint256 _kittyId) public {
        uint256 index = escrowedIndexMap[msg.sender][_kittyId];
        uint256 lastIndex = escrowedMap[msg.sender].length.sub(1);

        // Check if kitty is on escrow list
        // This check wont work with kittie 0, but kittie 0 does not exists. 
        require(escrowedMap[msg.sender][index] > 0, "kitty not on escrow list");

        // Transfer ownership back to msg.sender
        kittyCore.transferFrom(address(this), msg.sender, _kittyId);
        
        // Reorg escrowed array. 
        escrowedMap[msg.sender][index] = escrowedMap[msg.sender][lastIndex];
        escrowedMap[msg.sender][lastIndex] = 0;
        escrowedMap[msg.sender].length -= 1;

        delete escrowedIndexMap[msg.sender][_kittyId];

        emit LogKittieWithdrawed(_kittyId, msg.sender);
    }

    /**
     * Forge deposited kitties into a new Amulet granted to the msg.sender.
     */
    function forgeAmulet() public {
        uint256 escrowedLen = Math.max256(escrowedMap[msg.sender].length, MAX_KITTIES_IN_FORGE);
        
        require(escrowedLen >= MIN_REQUIRED_KITTIES, "sender does not has MIN_REQUIRED_KITTIES on escrow");

        uint256 amuletPower = 0;
        uint256[] memory forgedKitties = new uint256[](escrowedLen);

        for (uint i = 0; i < escrowedLen; i++) {
            uint256 kittyId = escrowedMap[msg.sender][i];

            // Adds up all kitties' scores based on cattributes.
            amuletPower += _getKittyScore(kittyId);

            // Push to forged and remove from mappinig. 
            // We'll remove it from the escrowed array later. 
            forgedKitties[i] = kittyId;
            
            // Reorg escrowed Array
            uint256 index = escrowedIndexMap[msg.sender][kittyId];
            uint256 lastIndex = escrowedMap[msg.sender].length.sub(1);

            escrowedMap[msg.sender][index] = escrowedMap[msg.sender][lastIndex];
            escrowedMap[msg.sender][lastIndex] = 0;
            escrowedMap[msg.sender].length -= 1;

            delete escrowedIndexMap[msg.sender][kittyId];
        }

        // One we get powerValue calculated from 
        // all escrowed kitties, let's forge a new amulet token

        // Use ERC721 tokenIndex as amuletId. 
        uint256 amuletId = allTokens.length;
       
        // Calculate scaled amulate power
        uint32 scaledAmulatePower = uint32(
            AMULATE_POWER_SCALE.mul(
                amuletPower.div(maxMaskValue)
            )
        );

        // Mint amulet
        _mint(msg.sender, amuletId);
        
        // Keep tokens
        amuletsMap[amuletId] = AmuletInfo({
            amuletPower: scaledAmulatePower,
            forgedKitties: forgedKitties
        });

        emit LogAmuletForged(amuletId, msg.sender);
    }

    /**
     * Unforge an amulete, leave all forged kitties available 
     * to re-forge or withdraw.
     * Can only be called by the owner of the amulate token.
     */
    function unforgeAmulet(uint256 _amuletId) public onlyOwnerOf(_amuletId) {
        uint256 escrowedLen = amuletsMap[_amuletId].forgedKitties.length;

        // Move unforged kitties to escrowed list
        for (uint i = 0; i < escrowedLen; i++) {     
            uint256 kittyId = amuletsMap[_amuletId].forgedKitties[i];

            // Push into escrowedArray forged kitties. 
            escrowedMap[msg.sender].push(kittyId);
            escrowedIndexMap[msg.sender][escrowedLen + i] = kittyId;
        }
        
        delete amuletsMap[_amuletId];
        
        _burn(msg.sender, _amuletId);

        emit LogAmuletUnForged(_amuletId, msg.sender);
    }

    /**
     * Gets the kittie genes from KittiesCore contract and returns a 
     * value based on genes' masks configured values
     */
    function _getKittyScore(uint256 _kittyId) private view returns (uint32) {
        
        uint32 kittieScore = 0;
        uint256 kittieGenes;

        // Get kitty genes           
        ( , , , , , , , , , kittieGenes) = kittyCore.getKitty(_kittyId);

        for (uint i = 0; i < masksArray.length; i++) {
            uint256 _mask = masksArray[i];

            if (kittieGenes & _mask == maskInfoMap[_mask].maskResult) {
                kittieScore += maskInfoMap[_mask].maskValue;
            }
        }
        return kittieScore;
    }
}