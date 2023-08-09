// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title Gotchiswap
 * @dev A decentralized escrow contract for trading Aavegotchi assets OTC style.
 */
contract Gotchiswap is Initializable {

    address public ghstAddress;
    address public aavegotchiAddress;
    address public wearablesAddress;
    address public adminAddress;

    IERC721 aavegotchi;
    IERC20 GHST;

    /**
     * @dev Struct representing a Gotchi/Portal trade.
     */
    struct GotchiSale {
        uint256 id;
        uint256 gotchi;
        uint256 price;
        address buyer;
    }

    /**
     * @dev Struct representing a reference to a sale made by a seller for a buyer.
     */
    struct SaleRef {
        address seller;
        uint256 id;
    }

    mapping(address => GotchiSale[]) sellers;
    mapping(address => SaleRef[]) buyers;

    uint256 saleId;

    //  Events
    event newSale(address indexed seller, uint256 indexed gotchi);
    event concludeSale(address indexed buyer, uint256 indexed gotchi);
    event abortSale(address indexed seller, uint256 indexed gotchi);

    /**
     * @dev Modifier that only allows the admin to perform certain functions.
     */
    modifier onlyAdmin {
        require(msg.sender == adminAddress, "Gotchiswap: Only the admin can perform this action");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the necessary addresses.
     * @param _ghst Address of the GHST ERC20 token.
     * @param _gotchis Address of the Aavegotchi ERC721 token.
     * @param _wearables Address of the wearables contract (not used in this version).
     * @param _admin Address of the admin who can perform certain actions.
     */
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

    /**
     * @dev Allows the admin to transfer admin rights to another address.
     * @param _admin The new admin address.
     */
    function changeAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Gotchiswap: Cannot change admin to an invalid address");
        adminAddress = _admin;
    }

    /**
     * @dev Allows the admin to remove the admin privilege completely.
     *      This makes it impossible to use admin functions anymore. Should be used
     *      in tandem with the renounceOwnership of the ProxyAdmin contract to make it
     *      completely trustless and immutable
     */
    function removeAdmin() external onlyAdmin {
        adminAddress = address(0);
    }

    /**
     * @dev Allows the admin to withdraw an Aavegotchi ERC721 token from the contract.
     * @param _tokenId The ID of the ERC721 token to be withdrawn.
     */
    function withdrawERC721(uint256 _tokenId) external onlyAdmin {
        aavegotchi.safeTransferFrom(address(this), adminAddress, _tokenId, "");
    }

    /**
     * @dev Allows the admin to withdraw GHST ERC20 tokens from the contract.
     */
    function withdrawGHST() external onlyAdmin {
        SafeERC20.safeTransfer(
            GHST,
            adminAddress,
            GHST.balanceOf(address(this))
        );
    }

    /**
     * @dev Gets the offer made for a buyer at a specific index.
     * @param _buyer The address of the buyer.
     * @param _index The index of the offer.
     * @return seller The address of the seller who made the offer.
     * @return id The ID of the offer.
     */
    function getOffer(address _buyer, uint256 _index) external view returns (
        address,
        uint256
    ) {
        require(isBuyer(_buyer), "Gotchiswap: No offers found for the buyer");

        SaleRef memory offer = buyers[_buyer][_index];

        return(offer.seller, offer.id);
    }

    /**
     * @dev Gets the sale made by a seller at a specific index.
     * @param _seller The address of the seller.
     * @param _index The index of the sale.
     * @return id The ID of the sale.
     * @return gotchi The ID of the Aavegotchi token being sold.
     * @return price The price of the Aavegotchi token in GHST tokens.
     * @return buyer The address of the buyer who can purchase the Aavegotchi token.
     */
    function getSale(address _seller, uint256 _index) external view returns (
        uint256,
        uint256,
        uint256,
        address
    ) {
        require(isSeller(_seller), "Gotchiswap: No sales found for the seller");

        GotchiSale memory sale = sellers[_seller][_index];

        return(sale.id, sale.gotchi, sale.price, sale.buyer);
    }

    /**
     * @dev Gets the number of offers made to a specific buyer.
     * @param _buyer The address of the buyer.
     * @return The number of sales made by the buyer.
     */
    function getBuyerSalesCount(address _buyer) external view returns (uint256) {
        require(isBuyer(_buyer), "Gotchiswap: No sales found for the buyer");
        return buyers[_buyer].length;
    }

    /**
     * @dev Gets the number of offers made by a specific seller.
     * @param _seller The address of the seller.
     * @return The number of sales made by the seller.
     */
    function getSellerSalesCount(address _seller) external view returns (uint256) {
        require(isSeller(_seller), "Gotchiswap: No sales found for the seller");
        return sellers[_seller].length;
    }

    /**
     * @dev Allows a seller to create a trade for their Aavegotchi with a buyer.
     * @param _gotchi The ID of the Aavegotchi token to be sold.
     * @param _price The price of the Aavegotchi token in GHST tokens.
     * @param _buyer The address of the buyer who can purchase the Aavegotchi token.
     */
    function sellGotchi(
        uint256 _gotchi,
        uint256 _price,
        address _buyer
    ) external {
        require(
            _price > 0,
            "Gotchiswap: Price must be greater than 0"
        );
        // Add the sale to the seller's sales list and the buyer's offers list
        addSale(msg.sender, _gotchi, _price, _buyer);
        // Transfer the Aavegotchi token to the contract
        aavegotchi.safeTransferFrom(msg.sender, address(this), _gotchi, "");
        emit newSale(msg.sender, _gotchi);
    }

    /**
     * @dev Allows a seller to abort their Aavegotchi sale.
     * @param _index The index of the sale to be aborted.
     */
    function abortGotchiSale(uint256 _index) external {
        require(isSeller(msg.sender), "Gotchiswap: No sales found for the seller");
        // Get the Aavegotchi ID for the sale to be aborted
        uint256 gotchi = sellers[msg.sender][_index].gotchi;
        // Remove the sale from the seller's sales list
        removeSale(msg.sender, _index);
        // Transfer the Aavegotchi token back to the seller
        aavegotchi.safeTransferFrom(address(this), msg.sender, gotchi, "");
        emit abortSale(msg.sender, gotchi);
    }

    /**
     * @dev Allows a buyer to purchase an Aavegotchi from his offers.
     * @param _index The index of the offer to be accepted.
     */
    function buyGotchi(uint256 _index) external {
        require(isBuyer(msg.sender), "Gotchiswap: No offers found for the buyer");

        // Get the details of the offer to be accepted
        address seller = buyers[msg.sender][_index].seller;
        uint256 id = buyers[msg.sender][_index].id;
        uint256 sale_index = getSaleIndex(seller, id);
        GotchiSale memory sale = sellers[seller][sale_index];

        uint256 gotchi = sale.gotchi;
        uint256 price = sale.price;

        // Remove the offer from the buyer's offers list
        removeSale(seller, sale_index);

        // Deposit the GHST amount to the contract
        SafeERC20.safeTransferFrom(GHST, msg.sender, address(this), price);
        // Transfer the Aavegotchi token to the buyer
        aavegotchi.safeTransferFrom(address(this), msg.sender, gotchi, "");
        // Send the GHST amount to the seller
        SafeERC20.safeTransfer(GHST, seller, price);
        emit concludeSale(msg.sender, gotchi);
    }

    /**
     * @dev The ERC721 receiver callback function (for compatibility).
     */
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

    /**
     * @dev Private function to get a unique ID for each sale.
     * @return A unique sale ID.
     */
    function getSaleId() private returns (uint) {
        return saleId++;
    }

    /**
     * @dev Private function to get the index of a sale in the seller's sales list.
     * @param _seller The address of the seller.
     * @param _id The ID of the sale.
     * @return index The index of the sale in the seller's sales list.
     */
    function getSaleIndex(address _seller, uint256 _id) private view returns (uint256 index) {
        for (uint i = 0; i < sellers[_seller].length; i++) {
            if (sellers[_seller][i].id == _id) {
                return i;
            }
        }
        revert("Gotchiswap: Sale not found");
    }

    /**
     * @dev Private function to add a sale to the seller's sales list and the buyer's offers list.
     * @param _seller The address of the seller.
     * @param _gotchi The ID of the Aavegotchi token to be sold.
     * @param _price The price of the Aavegotchi token in GHST tokens.
     * @param _buyer The address of the buyer who can purchase the Aavegotchi token.
     */
    function addSale(
        address _seller,
        uint256 _gotchi,
        uint256 _price,
        address _buyer
    ) private {
        // Add the sale to the seller's sales list
        uint256 id = getSaleId();
        sellers[_seller].push(GotchiSale(id, _gotchi, _price, _buyer));
        // Add a reference to the sale in the buyer's offers list
        buyers[_buyer].push(SaleRef(_seller, id));
    }

    /**
     * @dev Private function to check if an address has any active sales.
     * @param _seller The address to check.
     * @return True if the address has active sales, otherwise false.
     */
    function isSeller(address _seller) private view returns (bool) {
        if (sellers[_seller].length > 0) {
            return true;
        }
        return false;
    }

    /**
     * @dev Private function to remove a sale from the seller's sales list and the buyer's offers list.
     * @param _seller The address of the seller.
     * @param _index The index of the sale to be removed.
     */
    function removeSale(address _seller, uint256 _index ) private {
        require(isSeller(_seller), "Gotchiswap: No sales found for the seller");

        // Get the buyer and Aavegotchi ID for the sale to be removed
        address buyer = sellers[_seller][_index].buyer;
        uint256 id = sellers[_seller][_index].id;
        // Get the number of offers for that buyer
        uint256 buyer_sales = buyers[buyer].length;

        // Loop through each sale made by the buyer
        for (uint i = 0; i < buyer_sales; i++) {
            // Check if the sale is from that seller
            if (buyers[buyer][i].seller == _seller) {
                // Check if the sale ID matches the one to be removed
                if (buyers[buyer][i].id == id) {
                    // If so, remove the offer from the stack
                    for (uint j = i; j < buyer_sales - 1; j++) {
                        buyers[buyer][j] = buyers[buyer][j + 1];
                    }
                    // And remove the duplicate on top
                    buyers[buyer].pop();
                    break;
                }
            }
        }

        // Update the seller's list of sales
        uint256 length = sellers[_seller].length;
        // Remove the sale (preserve order)
        for (uint i = _index; i < length - 1; i++) {
            sellers[_seller][i] = sellers[_seller][i + 1];
        }
        sellers[_seller].pop();
    }

    /**
     * @dev Private function to check if an address has any active offers.
     * @param _buyer The address to check.
     * @return True if the address has active offers, otherwise false.
     */
    function isBuyer(address _buyer) private view returns (bool) {
        // Default is false
        if (buyers[_buyer].length > 0) {
            return true;
        }
        return false;
    }
}
