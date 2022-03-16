// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract VLXNFT is ERC721URIStorage,  AccessControl, Ownable {
    bytes32 public constant UPDATE_TOKEN_URI_ROLE = keccak256("UPDATE_TOKEN_URI_ROLE");
    bytes32 public constant PAUSED_ROLE = keccak256("PAUSED_ROLE");
    mapping(uint256 => address) public _tokenCreators;

    struct NFTVoucher {
        uint256 tokenId;
        string uri;
        string message;
        bytes signature;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _setupRole(PAUSED_ROLE, _msgSender());
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
        string memory _message,
        bytes memory signature
    ) public pure returns (address) {
        bytes32 messageHash = getMessageHash(_message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        
        return recoverSigner(ethSignedMessageHash, signature) ;

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

    function mint(NFTVoucher calldata voucher) public returns (uint) {
        address signer = verify(voucher.message , voucher.signature);
        _setupRole(UPDATE_TOKEN_URI_ROLE, signer);
        _mint(signer, voucher.tokenId);
        setTokenURI(voucher.tokenId, voucher.uri);
        _tokenCreators[voucher.tokenId] = signer;
        
        return voucher.tokenId;
    }

    function getCreator(uint256 tokenId) public view returns (address) {
        return _tokenCreators[tokenId];
    }

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     * openzeppelin/contracts/token/ERC721/ERC721Burnable.sol
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "caller is not owner nor approved");
        _burn(tokenId);
    }

    function _baseURI() internal override pure returns (string memory) {
        return "";
    }

    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public override(ERC721, AccessControl) view returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }


    function setTokenURI(uint256 tokenId, string memory tokenURI) public {
        require(hasRole(UPDATE_TOKEN_URI_ROLE, _msgSender()), "Must have update token uri role");
        _setTokenURI(tokenId, tokenURI);
    }

    function approveBulk(address to, uint256[] memory tokenIds) public {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            approve(to, tokenIds[i]);
        }
    }

    function getApprovedBulk(uint256[] memory tokenIds) public view returns (address[] memory) {
        address[] memory tokenApprovals = new address[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            tokenApprovals[i] = getApproved(tokenIds[i]);
        }
        return tokenApprovals;
    }
    
}
