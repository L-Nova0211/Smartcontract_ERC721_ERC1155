// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interface/RoyaltyFactorySecondary.sol";
import "./INft_Marketplace.sol";
import "./FeeManager.sol";

contract Fixed_Marketplace is INft_Marketplace, FeeManager, IERC721Receiver {
    using SafeMath for uint256;
    string internal cifi_Symbol = "CIFI";
    string bnb_Symbol = "BNB";

    // From ERC721 registry assetId to Order (to avoid asset collision)
    mapping(address => mapping(uint256 => Order)) orderByAssetId;

    mapping(string => address) acceptedTokens;

    // array that saves all the symbols of accepted tokens
    string[] public acceptedTokensSymbols;

    constructor() {}

    // 721 Interfaces
    bytes4 public constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ROYALTY = 0x0760a14c;

    /**
     * Creates a new order
     *  _nftAddress - Non fungible contract address
     *  _assetId - ID of the published NFT
     *  _priceInAnyOfTheSupportedCurrencies - price In Any Of The Supported Currencies
     *  _expiresAt - Duration of the order (in hours)
     */

    function createOrder(
        address _nftAddress,
        uint256 _assetId,
        string memory _tokenSymbol,
        uint256 _price,
        uint256 _expiresAt
    ) public returns (bytes32) {
        return
            _createOrder(
                _nftAddress,
                _assetId,
                _tokenSymbol,
                _price,
                _expiresAt
            );
    }

    /**
     *  Cancel an already published order
     *  can only be canceled by seller or the contract owner
     *  nftAddress - Address of the NFT registry
     *  assetId - ID of the published NFT
     */
    function cancelOrder(address _nftAddress, uint256 _assetId) public {
        Order memory order = orderByAssetId[_nftAddress][_assetId];

        require(order.seller == msg.sender, "Marketplace: unauthorized sender");

        _cancelOrder(order.id, _nftAddress, _assetId, msg.sender);
    }

    /**
     * Executes the sale for a published NFT
     *  nftAddress - Address of the NFT registry
     *  assetId - ID of the published NFT
     *  priceInAnyOfTheFourCurrencies - Order price
     */

    function safeExecuteOrder(address _nftAddress, uint256 _assetId)
        public
        payable
    {
        // Get the current valid order for the asset or fail
        Order memory order = _getValidOrder(_nftAddress, _assetId);

        /// Check the execution price matches the order price
        require(order.seller != msg.sender, "Marketplace: unauthorized sender");

        if (compareStrings(order.tokenSymbol, bnb_Symbol)) {
            require(order.price == msg.value, "Marketplace: invalid price");
        }
        // market fee to cut
        uint256 saleShareAmount = 0;
        address tokenAddress = acceptedTokens[order.tokenSymbol];
        ERC20 acceptedToken = ERC20(tokenAddress);
        uint256 royaltyFeeAmount = 0;
        if (IERC165(_nftAddress).supportsInterface(_INTERFACE_ID_ROYALTY)) {
            address orignalCreater =
                RoyaltyFactory(_nftAddress).getOriginalCreator(_assetId);
            uint256 royaltyFee =
                RoyaltyFactory(_nftAddress).getRoyaltyFee(_assetId);
            royaltyFeeAmount = order.price.mul(royaltyFee).div(1e6);
            if (compareStrings(order.tokenSymbol, bnb_Symbol)) {
                // Transfer share amount for marketplace Owner
                payable(orignalCreater).transfer(royaltyFeeAmount);
            } else {
                acceptedToken.transferFrom(
                    msg.sender, //buyer
                    orignalCreater,
                    royaltyFeeAmount
                );
            }
        }

        // Send market fees to owner
        if (FeeManager.cutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = order.price.mul(FeeManager.cutPerMillion).div(
                1e6
            );

            if (compareStrings(order.tokenSymbol, cifi_Symbol)) {
                // Transfer half of share amount for marketplace Owner
                acceptedToken.transferFrom(
                    msg.sender, //buyer
                    owner(),
                    saleShareAmount.div(3)
                );
            } else if (compareStrings(order.tokenSymbol, bnb_Symbol)) {
                // Transfer share amount for marketplace Owner
                payable(owner()).transfer(saleShareAmount);
            } else {
                acceptedToken.transferFrom(
                    msg.sender, //buyer
                    owner(),
                    saleShareAmount
                );
            }
        }

        if (compareStrings(order.tokenSymbol, cifi_Symbol)) {
            // Transfer accepted token amount minus market fee to seller
            uint256 amount =
                order.price.sub(saleShareAmount.div(3).mul(2)).sub(
                    royaltyFeeAmount
                );
            acceptedToken.transferFrom(
                msg.sender, // buyer
                order.seller, // seller
                amount
            );
        } else if (compareStrings(order.tokenSymbol, bnb_Symbol)) {
            // Transfer share amount for marketplace Owner
            payable(order.seller).transfer(
                order.price.sub(saleShareAmount).sub(royaltyFeeAmount)
            );
        } else {
            // Transfer accepted token amount minus market fee to seller
            acceptedToken.transferFrom(
                msg.sender, // buyer
                order.seller, // seller
                order.price.sub(saleShareAmount).sub(royaltyFeeAmount)
            );
        }

        _executeOrder(
            order.id,
            msg.sender, // buyer
            _nftAddress,
            _assetId,
            order.tokenSymbol,
            order.price
        );
    }

    /**
     * Internal function gets Order by nftRegistry and assetId. Checks for the order validity
     * nftAddress - Address of the NFT registry
     * assetId - ID of the published NFT
     */
    function _getValidOrder(address _nftAddress, uint256 _assetId)
        internal
        view
        returns (Order memory order)
    {
        order = orderByAssetId[_nftAddress][_assetId];

        require(order.id != 0, "Marketplace: asset not published");
        require(
            order.expiresAt >= block.timestamp,
            "Marketplace: order expired"
        );
    }

    /**
     * Executes the sale for a published NFT
     *  orderId - Order Id to execute
     *  buyer - address
     *  nftAddress - Address of the NFT registry
     *  assetId - NFT id
     *  price - Order price
     */
    function _executeOrder(
        bytes32 _orderId,
        address _buyer,
        address _nftAddress,
        uint256 _assetId,
        string memory _tokenSymbol,
        uint256 _price
    ) internal {
        // remove order
        Order memory order = orderByAssetId[_nftAddress][_assetId];
        // Transfer NFT asset
        IERC721(_nftAddress).safeTransferFrom(address(this), _buyer, _assetId);

        delete orderByAssetId[_nftAddress][_assetId];
        // Notify ..
        emit OrderSuccessful(
            order.id,
            order.seller,
            _buyer,
            order.nftAddress,
            order.nftId,
            order.tokenSymbol,
            _price,
            block.timestamp
        );
    }

    /**
     * Creates a new order
     *  nftAddress - Non fungible contract address
     *  assetId - ID of the published NFT
     *  priceInAnyOfTheSupportedCurrencies - price In Any Of The Supported Currencies
     *  expiresAt - Expiration time for the order
     */
    function _createOrder(
        address _nftAddress,
        uint256 _assetId,
        string memory _tokenSymbol,
        uint256 _price,
        uint256 _expiresAt
    ) internal returns (bytes32) {
        // Check nft registry
        IERC721 nftRegistry = _requireERC721(_nftAddress);

        // Check order creator is the asset owner
        address assetOwner = nftRegistry.ownerOf(_assetId);

        require(
            assetOwner == msg.sender,
            "Marketplace: Only the asset owner can create orders"
        );

        require(_price > 0, "Marketplace: Price should be bigger than 0");

        require(
            _expiresAt > block.timestamp.add(1 minutes),
            "Marketplace: Publication should be more than 1 minute in the future"
        );

        // get NFT asset from seller
        nftRegistry.safeTransferFrom(assetOwner, address(this), _assetId);

        // create the orderId
        bytes32 orderId =
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    assetOwner,
                    _nftAddress,
                    _assetId,
                    _tokenSymbol,
                    _price
                )
            );

        // save order
        orderByAssetId[_nftAddress][_assetId] = Order({
            id: orderId,
            seller: assetOwner,
            nftAddress: _nftAddress,
            nftId: _assetId,
            tokenSymbol: _tokenSymbol,
            price: _price,
            expiresAt: _expiresAt
        });

        emit OrderCreated(
            orderId,
            assetOwner,
            _nftAddress,
            _tokenSymbol,
            _assetId,
            _price,
            _expiresAt
        );
        return orderId;
    }

    /**
     * Cancel an already published order
     *  can only be canceled by seller or the contract owner
     * orderId - Bid identifier
     * nftAddress - Address of the NFT registry
     * assetId - ID of the published NFT
     * seller - Address
     */
    function _cancelOrder(
        bytes32 _orderId,
        address _nftAddress,
        uint256 _assetId,
        address _seller
    ) internal {
        delete orderByAssetId[_nftAddress][_assetId];
        /// send asset back to seller
        IERC721(_nftAddress).safeTransferFrom(address(this), _seller, _assetId);
        emit OrderCancelled(_orderId);
    }

    function _requireERC721(address _nftAddress)
        internal
        view
        returns (IERC721)
    {
        require(
            IERC165(_nftAddress).supportsInterface(_INTERFACE_ID_ERC721),
            "The NFT contract has an invalid ERC721 implementation"
        );
        return IERC721(_nftAddress);
    }

    function addAcceptedToken(
        address acceptedTokenAddress,
        string memory acceptedTokenSymbol
    ) public onlyOwner returns (bool) {
        acceptedTokens[acceptedTokenSymbol] = acceptedTokenAddress;
        acceptedTokensSymbols.push(acceptedTokenSymbol);
        return true;
    }

    function getTokenSymbols() public view returns (string[] memory) {
        return acceptedTokensSymbols;
    }

    function getTokenAddress(string memory tokenSymbol)
        public
        view
        returns (address)
    {
        return acceptedTokens[tokenSymbol];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
