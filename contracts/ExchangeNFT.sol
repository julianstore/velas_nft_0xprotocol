// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "hardhat/console.sol";
import "./VLXNFT.sol";

contract ExchangeNFT is ERC721Holder, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    struct Order {
        address seller;
        address buyer;
        address maker;
        address collection;
        uint256 tokenId;
        uint256 price;
        uint256 royalty;
        uint256 expiry;
        uint256 nonce;
    }
    
    IERC20 public wvlxToken;
       
    uint256 public feeMultipler = 10 ** 4;
    uint256 public marketingFee = 275;

    address public feeAddress1;
    address public feeAddress2;
    address public nftAddress;
    address[] public collectionList;

    event Buy(address indexed seller, address indexed buyer, Order order);
        event Transfer(address indexed sender, address indexed receiver, address indexed collection, uint256 tokenId);
    event Sell(address indexed seller, address indexed buyer, Order order);
    event CancelOrder(address indexed caller, Order order);


    constructor(address _wvlxAddress, address _feeAddress1, address _feeAddress2, address _nftAddress) {
        wvlxToken = IERC20(_wvlxAddress);
        feeAddress1 = _feeAddress1;
        feeAddress2 = _feeAddress2;
        nftAddress = _nftAddress;
    }

    /*
     * @notice addCollection: Add Collection Address to collection list of marketplace
     * @param _collection: collection Address to add
     */
    function addCollection(address _collection) external {
        collectionList.push(_collection);
    }

    /*
     * @notice getCollectionList: get collection address list of marketplace
    */
    function getCollectionList() external view returns (address[] memory) {
        return collectionList;
    }

    /*
     * @notice setFeeAddress: set address to store service fee
     * @param _feeAddress1: 1st account address to store fee (buyback and burning WAG Token)
              _feeAddress2: 2nd account address to store fee
     */
    function setFeeAddress(address _feeAddress1, address _feeAddress2) external  {
        feeAddress1 = _feeAddress1;
        feeAddress2 = _feeAddress2;
    }

    /*
     * @notice setMarketingFee: set marketing fee 
     * @param _marketingFee: fee amount 
     */
    function  setMarketingFee(uint256 _marketingFee) external onlyOwner {
        marketingFee = _marketingFee;
    }

    /*
     * @notice isCollectionExist: check if collection is in list
     * @param _collection: address of collection to check
     */
    function isCollectionExist(address _collection) internal view returns (bool) {
        bool isCollection = false;
        for (uint256 i=0; i < collectionList.length;i++)
            if (collectionList[i] == _collection)
            {
                isCollection = true;
                break;
            }
        return isCollection;    
    }


    function getMessageHash(
        string memory _message
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_message));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
      
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function verify(
        address _signer,
        string memory _message,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        
        return recoverSigner(ethSignedMessageHash, signature) == _signer;

    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        //  return (r, s, v);
    }

    function compareStringsbyBytes(string memory s1, string memory s2) public pure returns(bool){
       return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }

       
    /*
     * @notice transferToken: Transfer NFT 
     * @param _collection: collection address
              _to : receiver address
              _tokenId: token ID
     */
    function transferToken(address _collection, address _to , uint256 _tokenId) external  {
        require(msg.sender != address(0) && msg.sender != _to , "Wrong msg sender");
        require(_to != address(0) && _to != address(this) , "Wrong receiver");
        require(msg.sender == VLXNFT(_collection).ownerOf(_tokenId), "Only Token Owner can transfer token");
        if (!isCollectionExist(_collection)) {
            revert("Collection doesn't exist");
        }
        VLXNFT(_collection).safeTransferFrom(msg.sender, _to, _tokenId);
        emit Transfer(msg.sender, _to, _collection, _tokenId);
    }

    /*
     * @notice buyToken: Buy Token
     * @param _order : Exchange Order
              _singature :  Signature
              _message : Message for sign
     */
      function buyToken(Order memory _order , bytes memory _signature, string memory _message) external payable  {
        if ( verify(msg.sender, _message, _signature) == false) 
        {
            revert("Failed Verification");
        }
        require(msg.sender != address(0) && msg.sender != address(this), "Wrong msg sender");
        require(_order.seller != _order.buyer, "Seller can not buy");
        require(msg.sender == _order.buyer, "Wrong Buyer");
        require(msg.sender == _order.maker, "Wrong Maker");
        require(_order.price > 0 && msg.value >= _order.price , "Price must be greater than 0");
        require(_order.seller == VLXNFT(_order.collection).ownerOf(_order.tokenId), "Only Token Owner can sell token");
        require(_order.expiry < block.timestamp, "Expired Order");
        if (!isCollectionExist(_order.collection)) {
            revert("Collection doesn't exist");
        }
        
        uint256 _marketValue = _order.price.div(feeMultipler).mul(marketingFee); // market service fee 
        uint256 _creatorValue = _order.price.div(feeMultipler).mul(_order.royalty); // nft creator royalty
        uint256 _sellerValue = _order.price.sub(_marketValue.add(_creatorValue)); // seller income
        
        payable(VLXNFT(_order.collection).getCreator(_order.tokenId)).transfer(_creatorValue); // send royalty to nft creator

        payable(_order.seller).transfer(_sellerValue); // send value to seller
        payable(feeAddress1).transfer(_marketValue / 2); // send service 50% of fee to wallet1
        payable(feeAddress2).transfer(_marketValue / 2); // send service 50% of fee to wallet2

        if (msg.value > _order.price) 
            payable(msg.sender).transfer(msg.value.sub(_order.price));

        VLXNFT(_order.collection).safeTransferFrom(_order.seller, msg.sender, _order.tokenId);

        emit Buy(_order.seller, msg.sender, _order);
    }

    
    /*
     * @notice sellToken: Sell Token
     * @param _order : Exchange Order
              _singature :  Signature
              _message : Message for sign
     */
    function sellToken(Order memory _order , bytes memory _signature, string memory _message) external {
        if ( verify(msg.sender,  _message, _signature) == false ) 
        {
            revert("Failed Verification ");
        }
        require(msg.sender != address(0) && msg.sender != address(this), "Wrong msg sender");
        require(_order.seller != _order.buyer, "Wrong Seller");
        require(msg.sender == _order.seller, "Wrong Seller");
        require(msg.sender == _order.maker, "Wrong Maker");
        require(msg.sender == VLXNFT(_order.collection).ownerOf(_order.tokenId), "Only Token Owner can sell token");
        require(_order.price > 0 , "Price must be greater than 0");
        require(_order.expiry < block.timestamp, "Expired Order");

        if (!isCollectionExist(_order.collection)) {
            revert("Collection doesn't exist");
        }

        uint256 _marketValue = _order.price.div(feeMultipler).mul(marketingFee); // market service fee 
        uint256 _creatorValue = _order.price.div(feeMultipler).mul(_order.royalty); // nft creator royalty
        uint256 _sellerValue = _order.price.sub(_marketValue.add(_creatorValue)); // seller income
                
        wvlxToken.safeTransferFrom(_order.buyer, VLXNFT(_order.collection).getCreator(_order.tokenId), _creatorValue); // send royalty to nft creator
        wvlxToken.safeTransferFrom(_order.buyer, msg.sender, _sellerValue); // send value to seller
        wvlxToken.safeTransferFrom(_order.buyer, feeAddress1, _marketValue / 2); // send service 50% of fee to wallet1
        wvlxToken.safeTransferFrom(_order.buyer, feeAddress2, _marketValue / 2); // send service 50% of fee to wallet2

        VLXNFT(_order.collection).safeTransferFrom(msg.sender, _order.buyer, _order.tokenId);
        
        emit Sell(msg.sender, _order.buyer, _order);
    }

     /*
     * @notice cancelOrder: cancel order
     * @param _order : Exchange Order
              _singature :  Signature
              _message : Message for sign
     */
    function cancelOrder(Order memory _order , bytes memory _signature, string memory _message) external  {
        if ( verify(msg.sender,  _message, _signature) == false ) 
        {
            revert("Failed Verification ");
        }
        require(msg.sender != address(0) && msg.sender != address(this), "Wrong msg sender");
        require(msg.sender == _order.maker, "Wrong Maker");
        require(_order.expiry < block.timestamp, "Expired Order");
        
        emit CancelOrder(msg.sender, _order);
        
    }

    receive() external payable {}

}
