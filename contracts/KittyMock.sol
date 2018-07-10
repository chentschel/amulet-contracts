pragma solidity 0.4.24;

import "./KittyCoreI.sol";

contract KittyMock {

    mapping(uint256 => address) kittiesMap;
    mapping(uint256 => uint256) genesMap;

    function getKitty(uint _id) external view returns (
        bool isGestating,
        bool isReady,
        uint256 cooldownIndex,
        uint256 nextActionAt,
        uint256 siringWithId,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        uint256 genes) 
    {
        isGestating = false;
        isReady = false;
        cooldownIndex = 0;
        nextActionAt = 0;
        siringWithId = 0;
        birthTime = 0;
        matronId = 0;
        sireId = 0;
        generation = 0;
        genes = genesMap[_id];
    }

    function createKitty(uint256 _tokenId, uint256 _genes) public {
        kittiesMap[_tokenId] = msg.sender;
        genesMap[_tokenId] = _genes;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        require(kittiesMap[_tokenId] == _from);
        kittiesMap[_tokenId] = _to;
    }
}