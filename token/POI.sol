// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./ERC721.sol";
import "../access/AccessController.sol";
import "../lib/Strings.sol";
/**
 * @title POI
 */
contract POI is ERC721,AccessController {

    string private _name = "Proof of interest";
    string private _symbol = "POI";
    Warrant[] private _warrants;

    struct Warrant {
        address token;
        uint256 level;
        uint256 endBlock;
        uint256 effectBlock;
        bool activation;
    }

    mapping(uint256 => Warrant) private _tokenWarrant;

    constructor (address config) public ERC721(_name,_symbol) AccessController(config) {}

    //创建通证
    function create(address to,address token, uint256 level, uint256 effectBlock) public onlyPOIStore returns(uint256) {
        // 生成一个权证，内存中
        Warrant memory warrant = Warrant(token,level,0,effectBlock,false);
        // 放入区块链（_warrants）中，返回新生成的warrantsID
        uint256 newWarrantId = _warrants.length;
        _warrants.push(warrant);
        // 判断，newWarrantId不能大于2^32
        require(newWarrantId == uint256(uint32(newWarrantId)));
        //发行权证id
        _mint(to,newWarrantId);
        //添加元数据
        _setTokenURI(newWarrantId,_convertWarrantToString(warrant));
        return newWarrantId;
    }

    //激活通证
    function activate(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "POI: activate of token that is not own");
        Warrant storage warrant = _warrants[tokenId];
        warrant.endBlock = block.number.add(warrant.effectBlock);
        warrant.activation = true;
        //添加元数据
        _setTokenURI(tokenId,_convertWarrantToString(warrant));
    }

    //查询通证信息
    function getWarrant(uint256 tokenId) public view returns (address token,uint256 level, uint256 endBlock,bool activation){
        require(_exists(tokenId),"POI: not exist of token");
        return (_warrants[tokenId].token,_warrants[tokenId].level,_warrants[tokenId].endBlock,_warrants[tokenId].activation);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function burn(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "POI: burn of token that is not own");
        _burn(tokenId);
    }

    function _convertWarrantToString(Warrant memory warrant) private pure returns (string memory){
        string memory result;
        result = Strings.concat(result, "POI :{token:");
        result = Strings.concat(result, Strings.parseAddress(warrant.token));
        result = Strings.concat(result, ",");
        result = Strings.concat(result, "level:");
        result = Strings.concat(result, Strings.parseInt(warrant.level));
        result = Strings.concat(result, ",");
        result = Strings.concat(result, "activation:");
        result = Strings.concat(result, Strings.parseBoolean(warrant.activation));
        if(warrant.activation){
            result = Strings.concat(result, ",");
            result = Strings.concat(result, "Block valid until:");
            result = Strings.concat(result, Strings.parseInt(warrant.endBlock));
        }
        result = Strings.concat(result, "}");
        return result;
    }

}
