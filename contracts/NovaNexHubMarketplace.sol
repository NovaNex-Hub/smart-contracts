//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC4907} from "./ERC4907.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error NovaNexHub__PriceZero();
error NovaNexHub__ValueLessThanListingFee();
error NovaNexHub__DurationTooLow();
error NovaNexHub__TokenUserStillValid();
error NovaNexHub__NovaNexHubNotApproved();
error NovaNextHub__OnlySellerCanExecuteThisFunction();
error NovaNexHub__ItemAlreadyCreated();
error NovaNexHub__ItemAlreadySold();
error NovaNexHub__InsufficientValueForPriceAndMarketFee();
error NovaNexHub__TransferPaymentFailed();
error NovaNextHub__AlreadyOwnItem();

contract NovaNexHubMarketplace is ReentrancyGuard {
    enum State {
        buy,
        rent
    }

    struct Item {
        address seller;
        uint256 itemId;
        State state;
        address owner;
        address user;
        uint256 price;
        uint64 duration;
        uint256 expire;
        address nft;
        uint256 tokenId;
        bool sold;
    }

    address payable private immutable i_feeAccount;
    uint256 private immutable i_feePercentage;

    uint256 private constant LISTING_FEE = 0.01 ether;
    uint64 private constant MINIMUM_RENT_PERIOD = 1 hours;

    address[] public creators;
    mapping(address seller => Item[] items) public sellerToItems;

    event ItemCreated(
        address indexed seller,
        uint256 indexed itemId,
        uint256 indexed price,
        uint64 duration,
        address nftAddress,
        uint256 tokenId
    );

    event ItemPurchased(
        address indexed buyer,
        address indexed seller,
        uint256 indexed itemId,
        State state,
        uint256 price,
        address nftAddress,
        uint256 tokenId
    );

    event ItemRemoved(
        address indexed seller, uint256 indexed itemId, State state, uint256 price, address nftAddress, uint256 tokenId
    );

    constructor(address _feeAccount, uint256 _feePercentage) {
        i_feeAccount = payable(_feeAccount);
        i_feePercentage = _feePercentage;
    }

    /////////////////////////////////////// Public Functions ///////////////////////////////////////////

    function createItem(address _nft, uint256 _tokenId, uint256 _price, State _state, uint64 _duration)
        public
        payable
        nonReentrant
    {
        _beforeCreatingItem(_price, _tokenId, _nft);

        //If the item is for rent
        ERC4907 nftContract = ERC4907(_nft);
        if (_state == State.rent) {
            //duration not too short
            if (_duration < MINIMUM_RENT_PERIOD) {
                revert NovaNexHub__DurationTooLow();
            }
            //User not valid
            if (nftContract.userOf(_tokenId) != address(0)) {
                revert NovaNexHub__TokenUserStillValid();
            }
        }
        //If its for sell
        else if (_state == State.buy) {
            nftContract.transferFrom(msg.sender, address(this), _tokenId);
        }

        //transfer fee
        (bool success,) = (i_feeAccount).call{value: LISTING_FEE}("");
        if (!success) {
            revert NovaNexHub__TransferPaymentFailed();
        }

        //adding new Item
        uint256 _currentLength = sellerToItems[msg.sender].length;
        sellerToItems[msg.sender][_currentLength] = Item({
            seller: msg.sender,
            itemId: _currentLength + 1,
            owner: _state == State.buy ? address(this) : msg.sender,
            user: nftContract.userOf(_tokenId),
            duration: _duration,
            expire: nftContract.userExpires(_tokenId),
            price: _price,
            state: _state,
            nft: _nft,
            tokenId: _tokenId,
            sold: false
        });

        if (_currentLength == 0) {
            creators[creators.length] == msg.sender;
        }

        //emit event
        emit ItemCreated(msg.sender, _currentLength + 1, _price, _duration, _nft, _tokenId);
    }

    function removeItem(uint256 _itemId) public nonReentrant {
        Item memory item = sellerToItems[msg.sender][_itemId - 1];

        if (item.seller != msg.sender) {
            revert NovaNextHub__OnlySellerCanExecuteThisFunction();
        }
        if (item.sold) {
            revert NovaNexHub__ItemAlreadySold();
        }

        //delete item
        delete sellerToItems[msg.sender][_itemId - 1 ];
        //eliminate creator if length becomes 0
        //emit
        emit ItemRemoved(item.seller, _itemId, item.state, item.price, item.nft, item.tokenId);
    }

    function purchaseItem(address _seller, uint256 _itemId) public payable nonReentrant {
        Item memory item = sellerToItems[_seller][_itemId - 1];
        uint256 totalPrice = getTotalPrice(item.price);
        ERC4907 nftContract = ERC4907(item.nft);

        _beforePurchasingItem(totalPrice, item.sold, _seller);

        if (item.state == State.buy) {
            //transfer token
            nftContract.transferFrom(address(this), msg.sender, item.tokenId);
            item.owner = msg.sender;
        } else if (item.state == State.rent) {
            //set user and expire date
            uint64 expire = uint64(block.timestamp) + item.duration;
            nftContract.setUser(item.tokenId, msg.sender, expire);

            item.expire = expire;
            item.user = msg.sender;
        }

        //update item to sold
        item.sold = true;
        sellerToItems[_seller][_itemId - 1] = item;

        //transfer money
        (bool feeSuccess,) = i_feeAccount.call{value: totalPrice - item.price}("");
        (bool priceSuccess,) = payable(item.seller).call{value: item.price}("");
        if (!feeSuccess || !priceSuccess) {
            revert NovaNexHub__TransferPaymentFailed();
        }

        //eliminate creator if length becomes 0

        //emit
        emit ItemPurchased(msg.sender, item.seller, item.itemId, item.state, item.price, item.nft, item.tokenId);
    }

    /////////////////////////////////////// Private Functions ///////////////////////////////////////////

    function _beforeCreatingItem(uint256 _price, uint256 _tokenId, address _nft) private {
        //Price Zero
        if (_price <= 0) {
            revert NovaNexHub__PriceZero();
        }
        //Listing fee
        if (msg.value < LISTING_FEE) {
            revert NovaNexHub__ValueLessThanListingFee();
        }
        //Already listed
        Item[] memory itemsOfSeller = sellerToItems[msg.sender];
        for (uint256 i = 0; i < itemsOfSeller.length; i++) {
            Item memory item = itemsOfSeller[i];

            if (item.nft == _nft && item.tokenId == _tokenId && !item.sold) {
                revert NovaNexHub__ItemAlreadyCreated();
            }
        }
        //Marketplace Approval
        if (ERC4907(_nft).getApproved(_tokenId) != address(this)) {
            revert NovaNexHub__NovaNexHubNotApproved();
        }
    }

    function _beforePurchasingItem(uint256 _totalPrice, bool _sold, address _seller) private {
        //check
        if (msg.value < _totalPrice) {
            revert NovaNexHub__InsufficientValueForPriceAndMarketFee();
        }
        if (_sold) {
            revert NovaNexHub__ItemAlreadySold();
        }
        if (_seller == msg.sender) {
            revert NovaNextHub__AlreadyOwnItem();
        }
    }
    ///////////////////////////////// External & Public View & Pure functions /////////////////////////////////////////

    function getTotalPrice(uint256 _price) public view returns (uint256) {
        return _price + ((_price / 100) * i_feePercentage);
    }

    function getItem(address _seller, uint256 _itemId) external view returns (Item memory) {
        return sellerToItems[_seller][_itemId - 1];
    }

    function getItems(uint256 _length) external view returns (Item[] memory) {
        Item[] memory items;
        uint256 length = _length == 0 || _length > creators.length ? creators.length : _length;

        for (uint256 i = 0; i < length; i++) {
            Item[] memory creatorItems = sellerToItems[creators[i]];
            for (uint256 o = 0; o < creatorItems.length; o++) {
                items[items.length] = creatorItems[o];
            }
        }

        return items;
    }

    function getListingFee() external pure returns (uint256) {
        return LISTING_FEE;
    }

    function getMinimumRentPeriod() external pure returns (uint256) {
        return MINIMUM_RENT_PERIOD;
    }

    function getFeeingInformation() external view returns (address, uint256) {
        return (i_feeAccount, i_feePercentage);
    }
}
