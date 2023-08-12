// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Gotchiswap
 * @dev A decentralized escrow contract for trading Aavegotchi assets OTC style.
 */
contract Gotchiswap is
    Initializable,
    ERC1155Holder,
    ERC721Holder
{
    address public adminAddress;

    // test
    address aavegotchiAddress = 0x86935F11C86623deC8a25696E1C19a8659CbF95d;
    address GHSTAddress = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;

    enum AssetClass {
        ERC20,
        ERC1155,
        ERC721
    }

    /**
     * @dev Struct representing a trade.
     */
    struct Sale {
        uint256 id;
        Asset[] assets;
        Asset[] prices;
        address buyer;
    }

    /**
     * @dev Struct representing an asset to trade for or against.
     */
    struct Asset {
        AssetClass class;
        address addr;
        uint256 id;
        uint256 qty;
    }

    /**
     * @dev Struct representing a reference to a sale made by a seller for a buyer.
     */
    struct SaleRef {
        address seller;
        uint256 id;
    }

    struct Items {
        AssetClass[] classes;
        address[] contracts;
        uint256[] ids;
        uint256[] amounts;
    }

    /**
     * @dev Map sales to sellers and offers to buyers.
     */
    mapping(address => Sale[]) sellers;
    mapping(address => SaleRef[]) buyers;

    /**
     * @dev Global sale ID that gets incremented with each sale.
     */
    uint256 private saleId;

    //  Events
    event CreateSale(address indexed seller, Asset[] assets, Asset[] prices, address indexed _buyer);
    event ConcludeSale(address indexed buyer, Sale sale);
    event AbortSale(address indexed seller, Sale sale);

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
     * @dev Initializes the contract with the admin address.
     * @param _admin Address of the admin who can perform certain actions.
     */
    function initialize(
        address _admin
    ) initializer external {
        adminAddress = _admin;
    }

    /**
     * @dev Allows the admin to transfer admin rights to another address.
     * @param _admin The new admin address.
     */
    function changeAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Gotchiswap: Cannot change admin to an invalid address");
        require(_admin != adminAddress, "Gotchiswap: Address already set as admin");
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
     * @dev Allows the admin to withdraw an ERC721 token from the contract.
     * @param _tokenId The ID of the ERC721 token to be withdrawn.
     */
    function withdrawERC721(address _contract, uint256 _tokenId) external onlyAdmin {

        ERC721(_contract).safeTransferFrom(address(this), adminAddress, _tokenId);
    }

    /**
     * @dev Allows the admin to withdraw ERC20 tokens from the contract.
     */
    function withdrawERC20(address _contract) external onlyAdmin {
        SafeERC20.safeTransfer(
            IERC20(_contract),
            adminAddress,
            IERC20(_contract).balanceOf(address(this))
        );
    }

    /**
     * @dev Allows a seller to create a trade for their Aavegotchi with a buyer.
     * @param _assetContracts tbc
     * @param _assetIds tbc
     * @param _assetAmounts tbc
     * @param _assetClasses tbc
     * @param _priceContracts tbc
     * @param _priceIds tbc
     * @param _priceAmounts tbc
     * @param _priceClasses tbc
     * @param _buyer The address of the buyer who can purchase the Aavegotchi token.
     */
    function createSale(
        AssetClass[] memory _assetClasses,
        address[] memory _assetContracts,
        uint256[] memory _assetIds,
        uint256[] memory _assetAmounts,
        AssetClass[] memory _priceClasses,
        address[] memory _priceContracts,
        uint256[] memory _priceIds,
        uint256[] memory _priceAmounts,
        address _buyer
    ) external {

        // Verify for valid input

        Asset[] memory assets = new Asset[](_assetClasses.length);
        Asset[] memory prices = new Asset[](_priceClasses.length);

        Asset memory asset;
        Asset memory price;

        for (uint256 i = 0; i < _assetClasses.length; i++) {
           asset.class = _assetClasses[i];
           asset.addr = _assetContracts[i];
           asset.id = _assetIds[i];
           asset.qty = _assetAmounts[i];

           assets[i] = asset;
        }

        for (uint256 i = 0; i < _priceClasses.length; i++) {
           price.class = _priceClasses[i];
           price.addr = _priceContracts[i];
           price.id = _priceIds[i];
           price.qty = _priceAmounts[i];

           prices[i] = price;
        }

        // Add the sale to the seller's sales list and the buyer's offers list
        //addSale(msg.sender, assets, prices, _buyer);
        addSale(
            msg.sender,
            assets,
            prices,
            _buyer
        );

        // Transfer the seller's assets to the contract
        transferAssets(msg.sender, address(this), assets);

        emit CreateSale(msg.sender, assets, prices, _buyer);
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

    function getSale(address _seller, uint256 _index)
    external
    view
    returns (
        uint256,
        AssetClass[] memory,
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        AssetClass[] memory,
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        address
    ) {
        require(isSeller(_seller), "Gotchiswap: No sales found for the seller");

        Sale memory sale = sellers[_seller][_index];

        Items memory assets;
        Items memory prices;

        for (uint256 i = 0; i < sale.assets.length; i++) {
           assets.classes[i] = sale.assets[i].class;
           assets.contracts[i] = sale.assets[i].addr;
           assets.ids[i] = sale.assets[i].id;
           assets.amounts[i] = sale.assets[i].qty;
        }

        for (uint256 i = 0; i < sale.prices.length; i++) {
           prices.classes[i] = sale.prices[i].class;
           prices.contracts[i] = sale.prices[i].addr;
           prices.ids[i] = sale.prices[i].id;
           prices.amounts[i] = sale.prices[i].qty;
        }

        return(
            sale.id,
            assets.classes,
            assets.contracts,
            assets.ids,
            assets.amounts,
            prices.classes,
            prices.contracts,
            prices.ids,
            prices.amounts,
            sale.buyer
        );
    }

    /**
     * @dev Gets the number of offers made to a specific buyer.
     * @param _buyer The address of the buyer.
     * @return The number of sales made by the buyer.
     */
    function getBuyerOffersCount(address _buyer) external view returns (uint256) {
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
     * @dev Allows a seller to abort their Aavegotchi sale.
     * @param _index The index of the sale to be aborted.
     */
    function abortSale(uint256 _index) external {
        require(isSeller(msg.sender), "Gotchiswap: No sales found for the seller");
        // Get the sale to be aborted
        Sale memory sale = sellers[msg.sender][_index];

        // Remove the sale from the seller's sales list
        removeSale(msg.sender, _index);

        // Transfer back assets to seller
        transferAssets(address(this), msg.sender, sale.assets);

        emit AbortSale(msg.sender, sale);
    }

    /**
     * @dev Allows a buyer to purchase an Aavegotchi from his offers.
     * @param _index The index of the offer to be accepted.
     */
    function concludeSale(uint256 _index) external {
        require(isBuyer(msg.sender), "Gotchiswap: No offers found for the buyer");

        // Get the details of the offer to be accepted
        address seller = buyers[msg.sender][_index].seller;
        uint256 id = buyers[msg.sender][_index].id;
        uint256 sale_index = getSaleIndex(seller, id);

        // Retrieve the offer
        Sale memory sale = sellers[seller][sale_index];

        // Remove the offer from the buyer's offers list
        removeSale(seller, sale_index);

        // Transfer the buyer assets to the seller
        transferAssets(msg.sender, seller, sale.prices);

        // Transfer the seller's assets to the buyer
        transferAssets(address(this), msg.sender, sale.assets);

        emit ConcludeSale(msg.sender, sale);
    }

    function transferAssets(address _from, address _to, Asset[] memory _assets) private {
        // transfer assets to contract
        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].class == AssetClass.ERC721) {
                transferERC721(
                    _from,
                    _to,
                    _assets[i].addr,
                    _assets[i].id
                );
            } else if (_assets[i].class == AssetClass.ERC1155) {
                transferERC1155(
                    _from,
                    _to,
                    _assets[i].addr,
                    _assets[i].id,
                    _assets[i].qty
                );
            } else if (_assets[i].class == AssetClass.ERC20) {
                transferERC20(
                    _from,
                    _to,
                    _assets[i].addr,
                    _assets[i].qty
                );
            }
        }
    }

    function transferERC721(
        address from,
        address to,
        address tokenAddress,
        uint256 tokenId
    ) private {
        ERC721(tokenAddress).safeTransferFrom(from, to, tokenId, "");
    }

    function transferERC1155(
        address from,
        address to,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) private {
        ERC1155(tokenAddress).safeTransferFrom(
            from,
            to,
            tokenId,
            amount,
            "0x01"
        );
    }

    function transferERC20(
        address from,
        address to,
        address tokenAddress,
        uint256 amount
    ) private {
        SafeERC20.safeTransferFrom(IERC20(tokenAddress), from, to, amount);
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
     * @param _seller The address of the seller who created the trade.
     * @param _assets tbc
     * @param _prices tbc
     * @param _buyer The address of the buyer who can purchase the assets.
     */
    function addSale(
        address _seller,
        Asset[] memory _assets,
        Asset[] memory _prices,
        address _buyer
    ) private {

        // Add the sale to the seller's sales list
        uint256 id = getSaleId();

        // Create an empty space in the sellers mapping
        Sale storage sale = sellers[_seller].push();

        // Fill in the values
        sale.id = id;
        for (uint256 i = 0; i < _assets.length; i++) {
           sale.assets.push(_assets[i]);
        }
        for (uint256 i = 0; i < _prices.length; i++) {
           sale.prices.push(_prices[i]);
        }
        sale.buyer = _buyer;

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
