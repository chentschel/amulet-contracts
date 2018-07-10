pragma solidity 0.4.24;

import "./KittyCoreI.sol";
import "../node_modules/openzeppelin-zos/contracts/math/Math.sol";
import "../node_modules/openzeppelin-zos/contracts/ownership/Ownable.sol";
import "../node_modules/openzeppelin-zos/contracts/token/ERC721/ERC721Token.sol";

contract AmuletToken is Ownable, ERC721Token {

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
    mapping(uint256 => MaskInfo) public maskInfoMap;

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

    // Struct we use to keep track of indexed kitties
    struct KittyIndex {
        bool isIndexed;
        uint256 arrayIndex;
    }

    // escrowed kitties mappings
    mapping(address => mapping(uint256 => KittyIndex)) escrowedIndexMap;


    /**
     * Constructor
     */
    function initialize(address _sender, address _kittyCore) isInitializer("AmuletToken", "0.1.0") public {
        Ownable.initialize(_sender);
        ERC721Token.initialize("Cryptokitties PowerAmulet Token", "CKPAT");

        kittyCore = KittyCoreI(_kittyCore);
    }

    /**
     * Adds or updates a gene mask
     * @param _mask value to add or update to gene masks mapping.
     * @param _result value after mask applied to a kittie gene.
     * @param _value value used to calculate final amulate power value. 
     */
    function updateMask(uint256 _mask, uint256 _result, uint32 _value) public onlyOwner {
        require(_value > 0, "Mask value should be > 0");
                 
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
            uint32 maskIndex = maskInfoMap[_mask].maskIndex;
            uint256 lastMaskIndex = masksArray.length.sub(1);

            // Override element bucket with last array item
            // and delete last bucket.
            masksArray[maskIndex] = masksArray[lastMaskIndex];

            // We moved the last array item to removed item index in array. 
            // Now we have to uudate maskIndex of that item to reflect 
            // its new position.
            uint256 lastMask = masksArray[maskIndex];
            maskInfoMap[lastMask].maskIndex = maskIndex;

            // remove last item, shorten array 
            masksArray[lastMaskIndex] = 0;
            masksArray.length--;
            
            // Update max mask values
            maxMaskValue -= maskInfoMap[_mask].maskValue;

            // remove mask from mapping
            delete maskInfoMap[_mask];
        }
    }

    /**
     * Returns total amount of configured gene masks
     */
    function getTotalMasks() public view returns (uint256) {
        return masksArray.length;
    }

    /**
     * Deposit kitty. Transfer ownership of the kittie to this contract.
     * @param _kittyId to deposit
     */
    function depositKitty(uint256 _kittyId) public {
        // Transfer this asset ownership
        kittyCore.transferFrom(msg.sender, address(this), _kittyId);

        // Add kittie to the end of escrowed array 
        // and save array index in escrowedIndexMap. 
        escrowedMap[msg.sender].push(_kittyId);
        
        escrowedIndexMap[msg.sender][_kittyId].isIndexed = true;
        escrowedIndexMap[msg.sender][_kittyId].arrayIndex = escrowedMap[msg.sender].length.sub(1);

        emit LogKittieDeposited(_kittyId, msg.sender);
    }

    /**
     * Withdraw kitty. Returns ownership to original depositor. 
     * @param _kittyId to withdraw
     */
    function withdrawKitty(uint256 _kittyId) public {
        require(escrowedMap[msg.sender].length > 0, "sender has no escrowed kitties");
        require(escrowedIndexMap[msg.sender][_kittyId].isIndexed, "kitty not on escrow list");
        
        uint256 index = escrowedIndexMap[msg.sender][_kittyId].arrayIndex;
        uint256 lastIndex = escrowedMap[msg.sender].length.sub(1);

        // Transfer ownership back to msg.sender
        kittyCore.transferFrom(address(this), msg.sender, _kittyId);
        
        // Reorg escrowed array. 
        escrowedMap[msg.sender][index] = escrowedMap[msg.sender][lastIndex];

        // We moved the last array item to removed item index in array. 
        // Now we have to uudate escrowedIndexMap of that item to reflect 
        // its new position.        
        uint256 lastKittyId = escrowedMap[msg.sender][index];
        escrowedIndexMap[msg.sender][lastKittyId].arrayIndex = index;

        // shorten array, delete last item
        escrowedMap[msg.sender][lastIndex] = 0;
        escrowedMap[msg.sender].length--;

        delete escrowedIndexMap[msg.sender][_kittyId];

        emit LogKittieWithdrawed(_kittyId, msg.sender);
    }

    /**
     * Returns total amount of escrowed kitties
     * @param _owner address to query against.
     */
    function getTotalEscrowed(address _owner) public view returns (uint256) {
        return escrowedMap[_owner].length;
    }

    /**
     * Returns escrowed kitties' ids.
     * @param _owner address to query against.
     */
    function getEscrowedIds(address _owner) public view returns (uint256[]) {
        return escrowedMap[_owner];
    }

    /**
     * Forge deposited kitties into a new Amulet granted to the msg.sender.
     */
    function forgeAmulet() public {
        uint256 forgableKitties = Math.min256(escrowedMap[msg.sender].length, MAX_KITTIES_IN_FORGE);

        require(forgableKitties >= MIN_REQUIRED_KITTIES, "sender does not has MIN_REQUIRED_KITTIES on escrow");

        uint256 amuletPower = 0;
        uint256[] memory forgedKitties = new uint256[](forgableKitties);

        // We know escrowed at least >= 2 here. 
        uint256 lastEscrowedKitty = escrowedMap[msg.sender].length - 1; 

        for (uint i = 0; i < forgableKitties; i++) {
            // We get escrowed Kitties from the end of the array to save 
            // gas costs from the needed reorg of items in array if inverse. 
            uint256 kittyId = escrowedMap[msg.sender][lastEscrowedKitty - i];

            // Adds up all kitties' scores based on cattributes.
            amuletPower += _getKittyScore(kittyId);

            // Push to forged and remove from mappinig. 
            // We'll remove it from the escrowed array later. 
            forgedKitties[i] = kittyId;
            
            // Remove last item from escrowed kitties array
            uint256 lastIndex = escrowedMap[msg.sender].length.sub(1);

            escrowedMap[msg.sender][lastIndex] = 0;
            escrowedMap[msg.sender].length--;

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
     * @param _amuletId to unuforge
     */
    function unforgeAmulet(uint256 _amuletId) public onlyOwnerOf(_amuletId) {
        uint256 forgedLen = amuletsMap[_amuletId].forgedKitties.length;
        uint256 escrowedLen = escrowedMap[msg.sender].length;

        // Move forged kitties to escrowed list
        for (uint i = 0; i < forgedLen; i++) {
            uint256 kittyId = amuletsMap[_amuletId].forgedKitties[i];

            // Push into escrowedArray forged kitties. 
            escrowedMap[msg.sender].push(kittyId);

            escrowedIndexMap[msg.sender][kittyId].isIndexed = true;
            escrowedIndexMap[msg.sender][kittyId].arrayIndex = escrowedLen + i;
        }
        // Burn amulet
        _burn(msg.sender, _amuletId);
        
        // Remove info map
        delete amuletsMap[_amuletId];

        emit LogAmuletUnForged(_amuletId, msg.sender);
    }

    /**
     * Gets forged kitties' ids in a given amulet
     * @param _amuletId to query
     */
    function getForgetForAmulet(uint256 _amuletId) public view returns (uint256[]) {
        return amuletsMap[_amuletId].forgedKitties;
    }

    /**
     * Gets power value for a a given amulet
     * @param _amuletId to query
     */
    function getAmuletPower(uint256 _amuletId) public view returns (uint32) {
        return amuletsMap[_amuletId].amuletPower;
    }

    /**
     * Gets the kittie genes from KittiesCore contract and returns a 
     * value based on genes' masks configured values
     * @param _kittyId to query
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