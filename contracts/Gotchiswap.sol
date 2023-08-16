// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Importing debugging utilities (optional)
// import "hardhat/console.sol";

/**
 * @title Gotchiswap
 * @dev A decentralized escrow contract for trading Aavegotchi assets OTC style.
 */
contract Gotchiswap is
    Initializable,
    ERC1155Holder,
    ERC721Holder
{
    // Admin address (For testing on mainnet, can be disabled)
    address public adminAddress;

    // Token types
    enum AssetClass {
        ERC20,
        ERC1155,
        ERC721
    }

    // Struct representing a trade.
    struct Sale {
        uint256 id;
        Asset[] assets;
        Asset[] prices;
        address buyer;
    }

    // Struct representing an asset to trade for or against.
    struct Asset {
        AssetClass class;
        address addr;
        uint256 id;
        uint256 qty;
    }

    // Struct representing a reference to a sale made by a seller for a buyer.
    struct SaleRef {
        address seller;
        uint256 id;
    }

    // Struct representing a bundle of assets
    struct Items {
        AssetClass[] classes;
        address[] contracts;
        uint256[] ids;
        uint256[] amounts;
    }

    // Map sales to sellers and offers to buyers.
    mapping(address => Sale[]) sellers;
    mapping(address => SaleRef[]) buyers;

    // Global sale ID that gets incremented with each sale.
    uint256 saleId;

    // Events
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
     * @param _contract The address of the contract for the ERC721 tokens to withdraw.
     * @param _tokenId The ID of the ERC721 token to be withdrawn.
     */
    function withdrawERC721(address _contract, uint256 _tokenId) external onlyAdmin {
        transferERC721(address(this), adminAddress, _contract, _tokenId);
    }

    /**
     * @dev Allows the admin to withdraw ERC1155 tokens from the contract.
     * @param _contract The address of the contract for the ERC1155 tokens to withdraw.
     * @param _tokenId The ID of the ERC1155 tokens to be withdrawn.
     * @param _amount The amount of tokens to be withdrawn.
     */
    function withdrawERC1155(address _contract, uint256 _tokenId, uint256 _amount) external onlyAdmin {
        transferERC1155(address(this), adminAddress, _contract, _tokenId, _amount);
    }

    /**
     * @dev Allows the admin to withdraw ERC20 tokens from the contract.
     * @param _contract The address of the ERC20 contract.
     * @param _amount The amount of tokens to be withdrawn.
     */
    function withdrawERC20(address _contract, uint256 _amount) external onlyAdmin {
        transferERC20(address(this), adminAddress, _contract, _amount);
    }

    /**
     * @dev Allows a seller to create a trade with a buyer.
     *      The trade is a bundle of ERC721, ERC1155 or ERC20 tokens (assets)
     *      against a bundle of ERC721, ERC1155 or ERC20 tokens (prices).
     *      Token type/class can be specified as:
     *      - 0: ERC20
     *      - 1: ERC1155
     *      - 2: ERC721
     *      The 4 arrays for each side need to be of the same length.
     *      ERC721 amount must be 1.
     *      ERC20 id must be 0.
     * @param _assetClasses Classes of the assets being traded.
     * @param _assetContracts Addresses of the asset contracts.
     * @param _assetIds IDs of the asset tokens.
     * @param _assetAmounts Amounts of the asset tokens.
     * @param _priceClasses Classes of the prices being asked.
     * @param _priceContracts Addresses of the price contracts.
     * @param _priceIds IDs of the price tokens.
     * @param _priceAmounts Amounts of the price tokens.
     * @param _buyer The address of the buyer.
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
        require(_buyer != address(0), "Gotchiswap: Invalid buyer address");
        require(_assetClasses.length > 0, "Gotchiswap: Assets list cannot be empty");
        require(_priceClasses.length > 0, "Gotchiswap: Prices list cannot be empty");
        require(_assetClasses.length == _assetContracts.length &&
            _assetClasses.length == _assetIds.length &&
            _assetClasses.length == _assetAmounts.length,
            "Gotchiswap: Assets parameters length should all be the same"
        );
        require(_priceClasses.length == _priceContracts.length &&
            _priceClasses.length == _priceIds.length &&
            _priceClasses.length == _priceAmounts.length,
            "Gotchiswap: Prices parameters length should all be the same"
        );

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
        addSale(msg.sender, assets, prices, _buyer);

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
        address seller,
        uint256 id
    ) {
        require(isBuyer(_buyer), "Gotchiswap: No offers found for the buyer");
        SaleRef memory offer = buyers[_buyer][_index];
        return (offer.seller, offer.id);
    }

    /**
     * @dev Gets the details of a sale made by a seller.
     * @param _seller The address of the seller.
     * @param _index The index of the sale.
     * @return id The ID of the sale.
     * @return assetClasses Classes of the assets being traded.
     * @return assetContracts Addresses of the asset contracts.
     * @return assetIds IDs of the asset tokens.
     * @return assetAmounts Amounts of the asset tokens.
     * @return priceClasses Classes of the prices being asked.
     * @return priceContracts Addresses of the price contracts.
     * @return priceIds IDs of the price tokens.
     * @return priceAmounts Amounts of the price toekns.
     * @return buyer The address of the buyer.
     */
    function getSale(address _seller, uint256 _index) external view returns (
        uint256 id,
        AssetClass[] memory assetClasses,
        address[] memory assetContracts,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        AssetClass[] memory priceClasses,
        address[] memory priceContracts,
        uint256[] memory priceIds,
        uint256[] memory priceAmounts,
        address buyer
    ) {
        require(isSeller(_seller), "Gotchiswap: No sales found for the seller");
        Sale memory sale = sellers[_seller][_index];

        Items memory assets;
        Items memory prices;

        assets.classes = new AssetClass[](sale.assets.length);
        assets.contracts = new address[](sale.assets.length);
        assets.ids = new uint256[](sale.assets.length);
        assets.amounts = new uint256[](sale.assets.length);

        prices.classes = new AssetClass[](sale.prices.length);
        prices.contracts = new address[](sale.prices.length);
        prices.ids = new uint256[](sale.prices.length);
        prices.amounts = new uint256[](sale.prices.length);

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

        return (
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
     * @return The number of active offers available to a buyer.
     */
    function getBuyerOffersCount(address _buyer) external view returns (uint256) {
        require(isBuyer(_buyer), "Gotchiswap: No offers found for the buyer");
        return buyers[_buyer].length;
    }

    /**
     * @dev Gets the number of offers made by a specific seller.
     * @param _seller The address of the seller.
     * @return The number of active sales made by the seller.
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
     * @dev Allows a buyer to accept a specific offer made by a seller.
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

    /**
     * @dev Private function to transfer a list of assets from one address to another.
     * @param _from The address from which the assets will be transferred.
     * @param _to The address to which the assets will be transferred.
     * @param _assets The list of assets to be transferred.
     */
    function transferAssets(address _from, address _to, Asset[] memory _assets) private {

        require(_to != address(0), "Gotchiswap: Invalid destination address");

        for (uint256 i = 0; i < _assets.length; i++) {

            require(_assets[i].addr != address(0), "Gotchiswap: Invalid contract address");

            if (_assets[i].class == AssetClass.ERC721) {
                require(_assets[i].qty == 1, "Gotchiswap: Amount for ERC721 token must be 1");
                transferERC721(_from, _to, _assets[i].addr, _assets[i].id);
            } else if (_assets[i].class == AssetClass.ERC1155) {
                transferERC1155(_from, _to, _assets[i].addr, _assets[i].id, _assets[i].qty);
            } else if (_assets[i].class == AssetClass.ERC20) {
                require(_assets[i].id == 0, "Gotchiswap: Id for ERC20 must be set to 0");
                transferERC20(_from, _to, _assets[i].addr, _assets[i].qty);
            }
        }
    }

    /**
     * @dev Transfers an ERC721 token from one address to another.
     * @param _from The address from which the token is being transferred.
     * @param _to The address to which the token will be transferred.
     * @param _tokenAddress The address of the ERC721 token contract.
     * @param _tokenId The ID of the ERC721 token being transferred.
     */
    function transferERC721(
        address _from,
        address _to,
        address _tokenAddress,
        uint256 _tokenId
    ) private {
        ERC721(_tokenAddress).safeTransferFrom(
            _from,
            _to,
            _tokenId,
            ""
        );
    }

    /**
     * @dev Transfers ERC1155 tokens from one address to another.
     * @param _from The address from which the tokens are being transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _tokenAddress The address of the ERC1155 token contract.
     * @param _tokenId The ID of the ERC1155 token being transferred.
     * @param _amount The amount of ERC1155 tokens being transferred.
     */
    function transferERC1155(
        address _from,
        address _to,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount
    ) private {
        ERC1155(_tokenAddress).safeTransferFrom(
            _from,
            _to,
            _tokenId,
            _amount,
            ""
        );
    }

    /**
     * @dev Transfers ERC20 tokens from one address to another.
     * @param _from The address from which the tokens are being transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _tokenAddress The address of the ERC20 token contract.
     * @param _amount The amount of ERC20 tokens being transferred.
     */
    function transferERC20(
        address _from,
        address _to,
        address _tokenAddress,
        uint256 _amount
    ) private {
        SafeERC20.safeTransferFrom(
            IERC20(_tokenAddress),
            _from,
            _to,
            _amount
        );
    }

    /**
     * @dev Private function to get a unique ID for each sale.
     * @return A unique sale ID.
     */
    function getSaleId() private returns (uint256) {
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
     * @dev Private function to check if an address has any active sales as a seller.
     * @param _seller The address to check.
     * @return True if the address has active sales as a seller, false otherwise.
     */
    function isSeller(address _seller) private view returns (bool) {
        return sellers[_seller].length > 0;
    }

    /**
     * @dev Private function to check if an address has any offers as a buyer.
     * @param _buyer The address to check.
     * @return True if the address has active offers as a buyer, false otherwise.
     */
    function isBuyer(address _buyer) private view returns (bool) {
        return buyers[_buyer].length > 0;
    }
}
