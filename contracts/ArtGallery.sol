// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ArtFactory.sol";

contract ArtGallery {
    using SafeMath for uint256;
    // mapping to save the symbol to Gallery Address
    mapping(string => address) symbolToGalleryAddress;
    //mapping to save all the gallery addresses of an owner
    mapping(address => address[]) userToGalleries;

    address lastaddress;
    string lastUri;
    address public feeAccount = address(0x0000000000000000000000);
    address public _owner = address(0x0000000000000000000000);

    // ERC20 cifiTokenContract = ERC20(0xe56aB536c90E5A8f06524EA639bE9cB3589B8146);
    ERC20 cifiTokenContract = ERC20(0x89F2a5463eF4e4176E57EEf2b2fDD256Bf4bC2bD);

    uint8 cifiDecimals = cifiTokenContract.decimals();
    uint256 FEE = 100;
    uint256 public feeAmount = FEE.mul(10**cifiDecimals).div(100);

    event GalleryCreated(
        string name,
        string symbol,
        string description,
        address caller,
        address galleryAddress
    );

    constructor() {
        feeAccount = msg.sender;
        _owner = msg.sender;
    }

    function createGallery(
        string memory name,
        string memory symbol,
        string memory description
    ) public returns (address) {
        require(msg.sender != address(0), "Invalid address");
        require(bytes(name).length != 0, "name can't be empty");
        require(bytes(symbol).length != 0, "symbol can't be empty");
        uniqueSymbol(symbol);
        cifiTokenContract.transferFrom(msg.sender, feeAccount, feeAmount);
        ArtFactory gallery =
            new ArtFactory(name, symbol, description, msg.sender);

        // adding the gallery address to the symbolToGalleryAddress
        symbolToGalleryAddress[symbol] = address(gallery);

        // saving the last gallery address
        lastaddress = address(gallery);

        // adding the gallery address to the uriToGalleryAddress

        // adding the address to address array for userToGalleries
        userToGalleries[msg.sender].push(address(gallery));

        emit GalleryCreated(
            name,
            symbol,
            description,
            msg.sender,
            address(gallery)
        );

        return address(gallery);
    }

    function uniqueSymbol(string memory symbol) public view returns (bool) {
        require(
            symbolToGalleryAddress[symbol] == address(0),
            "symbol already used"
        );
        return true;
    }

    function getlastAddress() public view returns (address) {
        return lastaddress;
    }

    function getGalleries(address _user)
        public
        view
        returns (address[] memory)
    {
        return userToGalleries[_user];
    }

    function getGallery(string memory _symbol) public view returns (address) {
        return symbolToGalleryAddress[_symbol];
    }

    /**
     * this function allows you to change the address that is going to receive the fee amount
     */
    function ChangeFeeAccount(address newFeeAccount) public returns (bool) {
        require(msg.sender == _owner);
        feeAccount = newFeeAccount;
        return true;
    }

    function ChangeFeeAmount(uint256 newFeeAmount) public returns (bool) {
        require(msg.sender == _owner);
        FEE = newFeeAmount;
        return true;
    }
}
