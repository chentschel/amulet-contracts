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

    // Arr of ERC721 held in escrow by user
    mapping(address => uint256[]) depositedKittiesMap;

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
            uint32 idx = maskInfoMap[_mask].maskIndex;
            
            // Override element bucket with last array item
            // and delete last bucket.
            masksArray[idx] = masksArray[masksArray.length - 1];
            
            delete masksArray[masksArray.length - 1];
            delete maskInfoMap[_mask];
        }
    }

    /**
     * Deposit kitty. Transfer ownership of the kittie to this contract.
     */
    function depositKitty(uint256 _kittyId) public {
        // Transfer this asset on escrow and approve old owner 
        // for a future withdrawal
        nfRegistry.transferFrom(msg.sender, address(this), _kittyId);
        nfRegistry.approve(msg.sender, _kittyId);

        emit LogKittieDeposited(_kittyId, msg.sender);

        escrowedKittiesMap[msg.sender].push(_kittyId);
    }

    /**
     * Withdraw kitty. Returns ownership to original depositor. 
     */
    function withdrawKitty(uint256 _kittyId) public {
        require(escrowedKittiesMap[msg.sender][_kittieId], "msg.sender is not allowed to withdraw");

        nfRegistry.transferFrom(address(this), msg.sender, _kittyId);
        
        emit LogKittieWithdrawed(_kittyId, msg.sender);
    }

    /**
     * Forge deposited kitties into a new Amulet granted to the msg.sender.
     */
    function forgeAmulet() public {
        uint32 kittiesLen = escrowedKittiesMap[msg.sender].length;
        requires(kittiesLen > 0, "theres no deposited kitties to forge an amulet");

        uint32 amuletPower = 0;

        for (uint i = 0; i < kittiesLen; i++) {
            uint256 kittie = escrowedKittiesMap[msg.sender][i];

            // Adds up all kitties' scores based on cattributes.
            amuletPower += getKittyScore(kittie);
        }

        // Use tokenIndex as amuletId. 
        uint256 amuletId = allTokens.length;

        // Mint amulet
        _mint(msg.sender, amuletId);
        
        // Keep tokens
        amuletsMap[amuletId] = AmuletInfo({
            amuletPower: amuletPower,
            forgedKitties: escrowedKittiesMap[msg.sender]
        });

        // Clear array for future deposited kitties
        // that will eventuually forge a new amulet.
        escrowedKittiesMap[msg.sender] = [];

        emit LogAmuletForged(amuletId, msg.sender);
    }

    /**
     * Unforge an amulete, leave all forged kitties available 
     * to re-forge or withdraw.
     */
    function unforgeAmulet(uint256 _tokenId) public onlyOwnerOf {
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