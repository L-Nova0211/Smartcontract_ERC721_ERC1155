// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenizedArtFactory is ERC721 {
    using SafeMath for uint256;

    ERC20 cifiTokenContractTest =
        ERC20(0xe56aB536c90E5A8f06524EA639bE9cB3589B8146);
    uint256 FEE = 100;
    uint8 cifiDecimals = cifiTokenContractTest.decimals();
    uint256 public feeAmount = FEE.mul(10**cifiDecimals).div(100);

    address feeWallet = address(0x000000000000000000000000);

    string public Artname;
    string public Artsymbol;
    string public Artdescription;

    address public Artcreator;

    mapping(uint256 => string) tokenID_symbol;
    mapping(uint256 => uint256) tokenID_amount;

    mapping(string => address) acceptedTokens;

    string[] public acceptedTokenSymbols;

    event Mint(string url, uint256 tokenId, string symbol, uint256 amount);

    /**
     * a registry function that iis been called by the NFT registry smart contract
     */

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _description,
        address _caller
    ) ERC721(_name, _symbol) {
        Artname = _name;
        Artsymbol = _symbol;
        Artdescription = _description;
        Artcreator = _caller;
    }

    /**
     * this function helps with queries to Fetch the metadata for a givine token id
     */
    function setURIPrefix(string memory baseURI) public {
        require(msg.sender == Artcreator);
        _setBaseURI(baseURI);
    }

    function assignDataToToken(uint256 id, string memory uri) public {
        require(_msgSender() == ownerOf(id), "invalid token owner");
        _setTokenURI(id, uri);
    }

    /**
     * this function helps with queries to Fetch all the tokens that the address owns by givine address
     */
    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        require(owner != address(0), "invalid owner");
        uint256 length = balanceOf(owner);
        uint256[] memory tokens = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokens;
    }

    /**
     * this function allows to approve more than one token id at once
     */
    function approveMany(address _to, uint256[] memory _tokenIds) public {
        /* Allows bulk-approval of many tokens. This function is useful for
      exchanges where users can make a single tx to enable the call of
      transferFrom for those tokens by an exchange contract. */
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // approve handles the check for if one who is approving is the owner.
            approve(_to, _tokenIds[i]);
        }
    }

    /**
     * this function allows to approve all the tokens the address owns at once
     */
    function approveAll(address _to) public {
        uint256[] memory tokens = tokensOfOwner(msg.sender);
        for (uint256 t = 0; t < tokens.length; t++) {
            approve(_to, tokens[t]);
        }
    }

    /**
     * this function allows to mint more of your Art
     */
    function mint(
        string memory url,
        string memory tokenSymbol,
        uint256 amount
    ) public {
        require(msg.sender == Artcreator);
        uint256 currentTokenCount = totalSupply().add(1);
        // The index of the newest token is at the # totalTokens.
        _mint(msg.sender, currentTokenCount);
        _setTokenURI(currentTokenCount, url);

        ERC20 acceptedToken = ERC20(acceptedTokens[tokenSymbol]);
        if (acceptedToken != cifiTokenContractTest) {
            cifiTokenContractTest.transferFrom(
                msg.sender,
                feeWallet,
                feeAmount
            );
        }
        acceptedToken.transferFrom(msg.sender, address(this), amount);
        tokenID_symbol[currentTokenCount] = tokenSymbol;
        tokenID_amount[currentTokenCount] = amount;

        emit Mint(url, currentTokenCount, tokenSymbol, amount);
    }

    function burn(uint256 _id) public returns (bool) {
        require(
            _isApprovedOrOwner(_msgSender(), _id),
            "caller is not owner nor approved"
        );
        address owner = ownerOf(_id);
        string memory tokenSymbol = tokenID_symbol[_id];
        uint256 amount = tokenID_amount[_id];
        ERC20 acceptedToken = ERC20(acceptedTokens[tokenSymbol]);
        acceptedToken.transferFrom(address(this), owner, amount);
        _burn(_id);
        return true;
    }

    function addAcceptedToken(
        address acceptedTokenAddress,
        string memory acceptedTokenSymbol
    ) public returns (bool) {
        require(msg.sender == Artcreator);
        acceptedTokens[acceptedTokenSymbol] = acceptedTokenAddress;
        acceptedTokenSymbols.push(acceptedTokenSymbol);
        return true;
    }
}
