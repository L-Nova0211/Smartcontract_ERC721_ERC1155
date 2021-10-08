// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.4;
import "@openzeppelin/contracts/introspection/ERC165.sol";

contract RoyaltyFactory is ERC165 {
    mapping(uint256 => address) _originalCreators;
    mapping(uint256 => uint256) _royaltyFees; // 100% = 1000000, 1% = 10000
    /*
     *     bytes4(keccak256('setRoyaltyFee(uint256, uint256)')) == 0x4e30ff2d
     *     bytes4(keccak256('setOriginalCreator(uint256, uint256)')) == 0x1db8209f
     *     bytes4(keccak256('getRoyaltyFee(uint256)')) == 0x9e4c0141
     *     bytes4(keccak256('getOriginalCreator(uint256)')) == 0xcaa47fbf
     *
     *     => 0x4e30ff2d ^ 0x1db8209f ^ 0x9e4c0141 ^ 0xcaa47fbf == 0x0760a14c
     */
    bytes4 private constant _INTERFACE_ID_ROYALTY = 0x0760a14c;

    constructor() {
        _registerInterface(_INTERFACE_ID_ROYALTY);
    }

    function setRoyaltyFee(uint256 tokenID, uint256 fee) internal {
        _royaltyFees[tokenID] = fee;
    }

    function setOriginalCreator(uint256 tokenID, address creator) internal {
        _originalCreators[tokenID] = creator;
    }

    function getRoyaltyFee(uint256 tokenID)
        public
        view
        virtual
        returns (uint256)
    {
        return _royaltyFees[tokenID];
    }

    function getOriginalCreator(uint256 tokenID)
        public
        view
        virtual
        returns (address)
    {
        return _originalCreators[tokenID];
    }
}
