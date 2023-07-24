// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Gotchiswap is Initializable {

    address public ghstAddress;
    address public aavegotchiAddress;
    address public wearablesAddress;
    address public adminAddress;

    IERC721 aavegotchi;
    IERC20 GHST;

    struct GotchiSale {
        uint256 id;
        uint256 gotchi;
        uint256 price;
        address buyer;
    }

    struct SaleRef {
        address seller;
        uint256 id;
    }

    mapping(address => GotchiSale[]) sellers;
    mapping(address => SaleRef[]) buyers;

    uint256 saleId;

    //  state events
    event newSale(address indexed seller, uint256 indexed gotchi);
    event concludeSale(address indexed buyer, uint256 indexed gotchi);
    event abortSale(address indexed seller, uint256 indexed gotchi);

    modifier onlyAdmin {
        require(msg.sender == adminAddress);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _ghst,
        address _gotchis,
        address _wearables,
        address _admin
    ) initializer external {
        ghstAddress = _ghst;
        aavegotchiAddress = _gotchis;
        wearablesAddress = _wearables;
        adminAddress = _admin;

        aavegotchi = IERC721(aavegotchiAddress);
        GHST = IERC20(ghstAddress);
    }

    function changeAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Cannot change admin: Invalid Address");
        adminAddress = _admin;
    }

    function removeAdmin() external onlyAdmin {
        adminAddress = address(0);
    }

    function withdrawERC721(uint256 _tokenId) external onlyAdmin {
        aavegotchi.safeTransferFrom(address(this), adminAddress, _tokenId, "");
    }

    function withdrawGHST() external onlyAdmin {
        SafeERC20.safeTransferFrom(
            GHST,
            address(this),
            adminAddress,
            GHST.balanceOf(address(this))
        );
    }

    function getOffer(address _buyer, uint256 _index) external view returns (
        address,
        uint256
    ) {
        require(isBuyer(_buyer), "Cannot get offer: No offers found");

        SaleRef memory offer = buyers[_buyer][_index];

        return(offer.seller, offer.id);
    }

    function getSale(address _seller, uint256 _index) external view returns (
        uint256,
        uint256,
        uint256,
        address
    ) {
        require(isSeller(_seller), "Cannot get sale: No sales found");

        GotchiSale memory sale = sellers[_seller][_index];

        return(sale.id, sale.gotchi, sale.price, sale.buyer);
    }

    function getBuyerSalesCount(address _buyer) external view returns (uint256) {
        require(isBuyer(_buyer), "No sales found");
        return buyers[_buyer].length;
    }

    function getSellerSalesCount(address _seller) external view returns (uint256) {
        require(isSeller(_seller), "No sales found");
        return sellers[_seller].length;
    }

    function sellGotchi(
        uint256 _gotchi,
        uint256 _price,
        address _buyer
    ) external
    {
        require(
            _price > 0,
            "Cannot add sale: Price must be greater than 0"
        );
        // transfer gotchi to contract
        aavegotchi.safeTransferFrom(msg.sender, address(this), _gotchi, "");
        addSale(msg.sender, _gotchi, _price, _buyer);
        emit newSale(msg.sender, _gotchi);
    }

    function abortGotchiSale(uint256 _index) external {
        require(isSeller(msg.sender), "Cannot abort: No sales found");
        uint256 gotchi = sellers[msg.sender][_index].gotchi;
        removeSale(msg.sender, _index);
        aavegotchi.safeTransferFrom(address(this), msg.sender, gotchi, "");
        emit abortSale(msg.sender, gotchi);
    }

    function buyGotchi(uint256 _index) external {
        require(isBuyer(msg.sender), "Cannot buy: No offers found");

        address seller = buyers[msg.sender][_index].seller;
        uint256 id = buyers[msg.sender][_index].id;
        uint256 sale_index = getSaleIndex(seller, id);
        GotchiSale memory sale = sellers[seller][sale_index];

        uint256 gotchi = sale.gotchi;
        uint256 price = sale.price;

        removeSale(seller, sale_index);

        // deposit amount to contract
        SafeERC20.safeTransferFrom(GHST, msg.sender, address(this), price);
        // transfer gotchi to buyer
        aavegotchi.safeTransferFrom(address(this), msg.sender, gotchi, "");
        // send amount to seller
        SafeERC20.safeTransferFrom(GHST, address(this), seller, price);
        emit concludeSale(msg.sender, gotchi);
    }

    function onERC721Received(
        address, /* _operator */
        address, /*  _from */
        uint256, /*  _tokenId */
        bytes calldata /* _data */
    )
        external
        pure
        returns (bytes4)
    {
        return bytes4(
            keccak256("onERC721Received(address,address,uint256,bytes)")
        );
    }

    function getSaleId() private returns (uint) {
      return saleId++;
    }

    function getSaleIndex(address _seller, uint256 _id) private view returns (uint256 index) {
        for (uint i = 0; i < sellers[_seller].length; i++) {
	        if (sellers[_seller][i].id == _id) {
                return i;
            }
        }
        revert("Cannot get index: Sale not found");
    }

    function addSale(
        address _seller,
        uint256 _gotchi,
        uint256 _price,
        address _buyer
    ) private
    {
        // add sale to seller
        uint256 id = getSaleId();
        sellers[_seller].push(GotchiSale(id, _gotchi, _price, _buyer));
        // add reference to buyer
        buyers[_buyer].push(SaleRef(_seller, id));
    }

    function isSeller(address _seller) private view returns (bool) {
        if (sellers[_seller].length > 0) {
          return true;
        }
        return false;
    }

    function removeSale(address _seller, uint256 _index ) private {
        require(isSeller(_seller), "Cannot remove sale: No sales found");

        // the buyer for that sale
        address buyer = sellers[_seller][_index].buyer;
        // the gotchi for that sale
        uint256 id = sellers[_seller][_index].id;
        // number of sales for that buyer
        uint256 buyer_sales = buyers[buyer].length;

        // for each sales of the buyer
        for (uint i=0; i < buyer_sales; i++) {
            // if from that seller
            if (buyers[buyer][i].seller == _seller) {
                // check if it is for that sale
                if (buyers[buyer][i].id == id) {
                    // if so remove offer
                    for (uint j=i; j < buyer_sales -1; j++) {
                        buyers[buyer][j] = buyers[buyer][j+1];
                    }
                    // remove last offer
                    buyers[buyer].pop();
                    break;
                }
            }
        }

        // update seller's sales
        uint256 length = sellers[_seller].length;
        // remove sale (preserve order)
        for (uint i = _index; i < length - 1; i++) {
	        sellers[_seller][i] = sellers[_seller][i+1];
        }
        sellers[_seller].pop();
    }

    function isBuyer(address _buyer) private view returns (bool) {
        // default is false
        if (buyers[_buyer].length > 0) {
            return true;
        }
        return false;
    }
}
