// SPDX-License-Identifier: NONE
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // security for non-reentrant
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IERC2981Royalties {
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _value - the sale price of the NFT asset specified by _tokenId
    /// @return _receiver - address of who should be sent the royalty payment
    /// @return _royaltyAmount - the royalty payment amount for value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

//withdraw function
contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item
    Counters.Counter private _itemsSold; // Number of items sold
     Counters.Counter private _itemsDeleted;
  IERC20 private supaToken = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    address payable withdrawalAddress; 
    // Currency is in Matic (lower price than ethereum)
    address payable contractOwner; // The owner of the NFTMarket contract (transfer and send function availabe to payable addresses)
    uint256 listingPrice = 0.01 ether; // This is made for owner of the file to be comissioned
        mapping(address => bool) public whitelistedContract;

    constructor() {
        contractOwner = payable(msg.sender);
        withdrawalAddress= payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
       
        uint256 price;
        bool isSold;
        bool isDeleted;
        uint timestamp;
    }
    bool public isPaused=false;
    mapping(uint256 => MarketItem) private idToMarketItem;

    // Event is an inhertable contract that can be used to emit events
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool isSold,
          bool isDeleted,
          uint timestamp
    );
      event MarketItemDeleted (
            uint indexed itemId
        );
        event ProductListed( 
            uint indexed itemId
        );
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }
        modifier onlyContractOwner() {
        require(
            contractOwner == msg.sender,
            "Only contract owner has permission"
        );
        _;
  }
    function whitelistContract(address nftContract, bool toWhitelist) public onlyContractOwner {
            whitelistedContract[nftContract] = toWhitelist;

    }

         modifier onlyWhitelistedContract(address nftContract) {
        require(
            whitelistedContract[nftContract] == true,
            "Only whitelisted NFT Contracts allowed"
        );
        _;
  }
    function setListingPrice(uint256 updatedListingPrice) public onlyContractOwner {
          
        listingPrice=updatedListingPrice;
        
    }
    function setPause(bool toPause) public onlyContractOwner {
            isPaused = toPause;

    }
     function getBalance() onlyContractOwner external view returns(uint,uint){
           return (supaToken.balanceOf(address(this)),address(this).balance);
        }
    function getApprovedAmount() external view returns(uint){
        return supaToken.allowance(msg.sender,address(this));
    }
        function withdraw() onlyContractOwner public payable returns(bool) {
        payable(withdrawalAddress).transfer(address(this).balance);
         supaToken.transferFrom(address(this), withdrawalAddress, supaToken.balanceOf(address(this)));
        return true;
        }
        function approveWithdraw() onlyContractOwner public {

            supaToken.approve(withdrawalAddress,supaToken.balanceOf(address(this)));
            
        }
        function setWithdrawalAddress(address newWithdrawalAddress) onlyContractOwner public {

            withdrawalAddress=payable(newWithdrawalAddress);
           
        }
//creates a listing
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price

    ) public payable nonReentrant onlyWhitelistedContract(nftContract){
        require(price > 0, "You cannot list your NFT's price for 0 SUPA.");
        require(
             supaToken.allowance(msg.sender,address(this)) >= listingPrice,
            "0.01 SUPA is required for listing."
        );
         supaToken.transferFrom(msg.sender, address(this), listingPrice);
               require(IERC721(nftContract).ownerOf(tokenId)==msg.sender,"Not owner of NFT");
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)), // No owner for the item
          
            price,
            false,
            false,
            block.timestamp
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
        
            price,
            false,
            false,
            block.timestamp
        );
    }
    function checkRoyalties(address _contract) internal view returns (bool) {
    (bool success) = IERC165(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
    return success;
 }
//completes the sale
    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
        onlyWhitelistedContract(nftContract)
    {

       
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
       
  require(
           isPaused==false ,
            "Listing is Paused."
        );

        require(
           supaToken.allowance(msg.sender,address(this)) >= price ,
            "Please make sure you have approved SUPA Token to purchase NFT"
        );
         require(
           price>0 ,
            "Item not for sale"
        );

        require(
            idToMarketItem[itemId].isSold == false,
            "This listing is sold"
        );

     
       
         if (checkRoyalties(nftContract)==true) {
        IERC2981Royalties royaltyChecker = IERC2981Royalties(nftContract);
        (address receiver, uint256 royalties)=royaltyChecker.royaltyInfo(tokenId,price);
        if(receiver!=0x0000000000000000000000000000000000000000){
                    supaToken.transferFrom(msg.sender, receiver, royalties);

        }
        supaToken.transferFrom(msg.sender, idToMarketItem[itemId].seller, price-royalties);

        } else {
          supaToken.transferFrom(msg.sender, idToMarketItem[itemId].seller, price);

        }

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].timestamp=block.timestamp;
        _itemsSold.increment();
    }
    
      modifier onlyItemSeller(uint256 id) {
        require(
            idToMarketItem[id].seller == msg.sender,
            "Only seller can do this operation"
        );
          require(
            idToMarketItem[id].isSold == false,
            "Item sold"
        );
        _;
    }
     function getSeller(uint256 id) public view returns (address) {
        return idToMarketItem[id].seller ;
    }
    modifier onlyProductOrMarketPlaceOwner(uint256 id) {
        require(
            idToMarketItem[id].owner == address(this),
            "Only product or market owner can do this operation"
        );
        _;
  }
   

    function deleteMarketItem(uint256 itemId)
        public
        payable
        onlyItemSeller(itemId) 
        nonReentrant
    {

      
   IERC721(idToMarketItem[itemId].nftContract).transferFrom(address(this), msg.sender, idToMarketItem[itemId].tokenId);
    // delete idToMarketItem[itemId];
        _itemsDeleted.increment();
         idToMarketItem[itemId].seller = payable(address(0));
         idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].price=0;
         idToMarketItem[itemId].isDeleted=true;
       idToMarketItem[itemId].isSold=false;
       idToMarketItem[itemId].timestamp=block.timestamp;

        emit MarketItemDeleted(itemId);
    
    }

    function getItemsByContract(address nftContract, uint returnCount, uint offset)public view returns (MarketItem[] memory) {
         uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = 0;
        uint256 currentIndex = 0;
     for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0) && idToMarketItem[i + 1].nftContract==nftContract) {
                unsoldItemCount += 1;
            }
        }
        unsoldItemCount=unsoldItemCount-offset;
        if(returnCount<unsoldItemCount){
            unsoldItemCount=returnCount;
        }
        MarketItem[] memory marketItems = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount && currentIndex< unsoldItemCount; i++) {
            if (idToMarketItem[i + 1 + offset].owner == address(0) && idToMarketItem[i + 1 +offset].nftContract==nftContract) {
                uint256 currentId = idToMarketItem[i + 1 + offset].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }
  function getLatestItemsByContract(address nftContract, uint returnCount, uint offset)public view returns (MarketItem[] memory) {
         uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = 0;
        uint256 currentIndex = 0;
     for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0) && idToMarketItem[i + 1].nftContract==nftContract) {
                unsoldItemCount += 1;
            }
        }
        unsoldItemCount=unsoldItemCount-offset;
        if(returnCount<unsoldItemCount){
            unsoldItemCount=returnCount;
        }
        MarketItem[] memory marketItems = new MarketItem[](unsoldItemCount);
        for (uint256 i = itemCount; i > 0 && currentIndex< unsoldItemCount; i--) {
            if (idToMarketItem[i  - offset].owner == address(0) && idToMarketItem[i  -offset].nftContract==nftContract) {
                uint256 currentId = idToMarketItem[i  - offset].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }
//fetches item history
    function getItemHistory(uint256 tokenId, address nftContract) public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
       // uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;
        uint256 specificItemCount=0;
      for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].tokenId == tokenId && idToMarketItem[i + 1].nftContract==nftContract) {
                specificItemCount += 1;
            }
        }
        MarketItem[] memory marketItems = new MarketItem[](specificItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].tokenId == tokenId && idToMarketItem[i + 1].nftContract==nftContract) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }
//fetches all listed items

function getMarketItems(uint returnCount, uint offset) public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current()-_itemsDeleted.current()-offset;
        uint256 currentIndex = 0;
        if(unsoldItemCount>returnCount){
            unsoldItemCount=returnCount;
        }
        MarketItem[] memory marketItems = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount && currentIndex< unsoldItemCount; i++) {
            if (idToMarketItem[i + 1+offset].owner == address(0)) {
                uint256 currentId = idToMarketItem[i + 1+ offset].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }

function getLatestMarketItems(uint returnCount, uint offset) public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current()-_itemsDeleted.current()-offset;
        uint256 currentIndex = 0;
        if(unsoldItemCount>returnCount){
            unsoldItemCount=returnCount;
        }
        MarketItem[] memory marketItems = new MarketItem[](unsoldItemCount);
        for (uint256 i = itemCount; i > 0 && currentIndex< unsoldItemCount; i--) {
            if (idToMarketItem[i -offset].owner == address(0)) {
                uint256 currentId = idToMarketItem[i - offset].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }


//fetches on purchased ones
//fix purchased if user buys the item and resells, same item will have new item id and if new purchaser buys the item, it should not show up on their puchase list since new owner


///fetches listed items by user
    function fetchCreateNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1; // No dynamic length. Predefined length has to be made
            }
        }

        MarketItem[] memory marketItems = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                marketItems[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return marketItems;
    }


}