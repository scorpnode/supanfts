                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          


// File: lib/IERC2981Royalties.sol


pragma solidity ^0.8.0;

/// @title IERC2981Royalties
/// @dev Interface for the ERC2981 - Token Royalty standard
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
// File: lib/ERC2981Base.sol


pragma solidity ^0.8.0;



/// @dev This is a contract used to add ERC2981 support to ERC721 and 1155
abstract contract ERC2981Base is ERC165, IERC2981Royalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }

    /// @inheritdoc	ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC2981Royalties).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
// File: lib/ERC2981ContractWideRoyalties.sol


pragma solidity ^0.8.0;



/// @dev This is a contract used to add ERC2981 support to ERC721 and 1155
/// @dev This implementation has the same royalties for each and every tokens
abstract contract ERC2981ContractWideRoyalties is ERC2981Base {
    RoyaltyInfo private _royalties;

    /// @dev Sets token royalties
    /// @param recipient recipient of the royalties
    /// @param value percentage (using 2 decimals - 10000 = 100, 0 = 0)
    function _setRoyalties(address recipient, uint256 value) internal {
        require(value <= 10000, 'ERC2981Royalties: Too high');
        _royalties = RoyaltyInfo(recipient, uint24(value));
    }

    /// @inheritdoc	IERC2981Royalties
    function royaltyInfo(uint256, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalties = _royalties;
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.amount) / 10000;
    }
}

pragma solidity ^0.8.2;
interface mintOrganism { 
function mint(  address receiver) external returns (bool success);
}
// SPDX-License-Identifier: NONE
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";                         
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SUPAOrganism is ERC721, ERC721URIStorage, ERC721Enumerable, Pausable, AccessControl, ERC2981ContractWideRoyalties,ReentrancyGuard {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SIGN_ROLE = keccak256("SIGN_ROLE");

    uint256 private mintSize = 10000;
    IERC721 private OGNFT = IERC721(0xd8b934580fcE35a11B58C6D73aDeE468a2833fa8); //can use standard openzeppelin erc721 contract to test
    mintOrganism SUPAVirus= mintOrganism(0xe2a9b15E283456894246499Fb912CCe717f83319); //clone of SUPACell.sol
    mintOrganism SUPACell= mintOrganism(0xe2a9b15E283456894246499Fb912CCe717f83319); //SUPACell.sol
    IERC20 private supaToken = IERC20(0x0fC5025C764cE34df352757e82f7B5c4Df39A836); //can use standard openzeppelin erc20 contract to test
    string private base = "https://gateway.pinata.cloud/ipfs/QmZ6GdhiBGQHC2NktskFUAbhUibLJMFK62pWarh5Zrudta/";
    mapping(string => Counters.Counter) public seenNoncesDiscord; 
      mapping(uint => Counters.Counter) public seenNoncesOG;
       mapping(uint => bool) public seenNoncesTokenId;
    Counters.Counter private _tokenIdCounter;
    uint public preRelease;
    uint public publicRelease;
     uint public identityRelease;
    event mintSuccessful(uint256 tokenId);  
      address payable contractOwner; 
     address payable withdrawalAddress;                     
    constructor() ERC721("SUPA Organism", "SUPAORGANISM") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(SIGN_ROLE, 0x59D3445a426C3CB6CeBC3033073F5d8ED5BE9fDd);
       preRelease=block.timestamp+86400;
        publicRelease=block.timestamp+259200;
        identityRelease=block.timestamp+518400;
        contractOwner = payable(msg.sender);
        withdrawalAddress= payable(msg.sender);
    }
    function setReleaseTimes(uint updatedPreRelease, uint updatedPublicRelease, uint updatedIdentityRelease)  public onlyRole(DEFAULT_ADMIN_ROLE){
       preRelease=updatedPreRelease;
        publicRelease=updatedPublicRelease;
        identityRelease=updatedIdentityRelease;
    }
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    function verifyOGUser(uint OGTokenID, uint price, uint timestamp,uint qty,bytes memory sig) internal virtual returns (bool) {
       return hasRole(SIGN_ROLE, keccak256(bytes(abi.encodePacked(uint2str(OGTokenID),uint2str(price),uint2str(timestamp),uint2str(qty))))
        .toEthSignedMessageHash()
        .recover(sig));
    }
    function verifyDiscordUser(string memory discordUser, uint price,uint timestamp,uint qty,bytes memory sig) internal virtual returns (bool) {
       return hasRole(SIGN_ROLE, keccak256(bytes(abi.encodePacked(discordUser,uint2str(price),uint2str(timestamp),uint2str(qty))))
        .toEthSignedMessageHash()
        .recover(sig));
    }
        function verifyMint(uint price, uint timestamp, uint qty, bytes memory sig) internal virtual returns (bool) {
       return hasRole(SIGN_ROLE, keccak256(bytes(abi.encodePacked(uint2str(price),uint2str(timestamp),uint2str(qty))))
        .toEthSignedMessageHash()
        .recover(sig));
    }
        function getBalance() onlyRole(DEFAULT_ADMIN_ROLE) external view returns(uint,uint){
           return (supaToken.balanceOf(address(this)),address(this).balance);
        }
        function withdraw() onlyRole(DEFAULT_ADMIN_ROLE) public payable returns(bool) {
        payable(withdrawalAddress).transfer(address(this).balance);
         supaToken.transferFrom(address(this), withdrawalAddress, supaToken.balanceOf(address(this)));
        return true;
        }
        function approveWithdraw() onlyRole(DEFAULT_ADMIN_ROLE) public {

            supaToken.approve(withdrawalAddress,supaToken.balanceOf(address(this)));
            
        }
        function setWithdrawalAddress(address newWithdrawalAddress) onlyRole(DEFAULT_ADMIN_ROLE) public {

            withdrawalAddress=payable(newWithdrawalAddress);
           
        }
        
    
  
    function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
    function mintWithGenesis(string memory discordUser,  uint price, uint timestamp, uint qty, bytes memory sig) public payable  nonReentrant {
        require(_tokenIdCounter.current() + qty <= mintSize, "Mint limit reached");
         require(verifyDiscordUser(discordUser,price, timestamp,qty,sig),"Invalid signature provided");
        require(seenNoncesDiscord[discordUser].current()<2,"Limit of 2 mints per Genesis Crew Role");
       
        require(block.timestamp>preRelease,"Not released yet");
        require(
           supaToken.allowance(msg.sender,address(this)) >= price,
            "Please make sure you have approved SUPA Token to purchase NFT"
        );
         supaToken.transferFrom(msg.sender, address(this), price);
           seenNoncesDiscord[discordUser].increment(); 
          for (uint256 i = 0; i < qty; i++) {
         _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(Strings.toString(_tokenIdCounter.current()), '.json')));
         emit mintSuccessful(_tokenIdCounter.current());
         }

    }
     function mintWithOGNFT(uint OGTokenID, uint price,uint timestamp, uint qty, bytes memory sig) public payable  nonReentrant {
        require(_tokenIdCounter.current() + qty <= mintSize, "Mint limit reached");
        require(verifyOGUser(OGTokenID,price,timestamp,qty,sig),"Invalid signature provided");
        require(seenNoncesOG[OGTokenID].current()<2,"Limit of 2 mints per OG NFT");
        require(OGNFT.ownerOf(OGTokenID)==msg.sender,"Not owner of NFT");
        require(
           supaToken.allowance(msg.sender,address(this)) >= price,
            "Please make sure you have approved SUPA Token to purchase NFT"
        );
         

         supaToken.transferFrom(msg.sender, address(this), price);
          seenNoncesOG[OGTokenID].increment(); 
         for (uint256 i = 0; i < qty; i++) {
         _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(Strings.toString(_tokenIdCounter.current()), '.json')));
         emit mintSuccessful(_tokenIdCounter.current());
         }
    }
     function mint(uint price, uint timestamp,uint qty,bytes memory sig) public payable  nonReentrant {
          require(block.timestamp>publicRelease,"Not released yet");
           require(verifyMint(price, timestamp,qty,sig),"Invalid signature provided");
        require(_tokenIdCounter.current() + 1 <= mintSize, "Mint limit reached");
        require(
           supaToken.allowance(msg.sender,address(this)) >= price,
            "Please make sure you have approved SUPA Token to purchase NFT"
        );
         supaToken.transferFrom(msg.sender, address(this), price);
           for (uint256 i = 0; i < qty; i++) {
         _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(Strings.toString(_tokenIdCounter.current()), '.json')));
         emit mintSuccessful(_tokenIdCounter.current());
           }
    }
     function internalmint(uint qty) public  onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(_tokenIdCounter.current() + qty <= mintSize, "Mint limit reached");
         for (uint256 i = 0; i < qty; i++) {
         _tokenIdCounter.increment();
        _safeMint(msg.sender, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), string(abi.encodePacked(Strings.toString(_tokenIdCounter.current()), '.json')));
         emit mintSuccessful(_tokenIdCounter.current());
         }
    }

    
    function identifyOrganism(uint tokenId) public nonReentrant {
    require(block.timestamp>identityRelease,"Not released yet");
    require(seenNoncesTokenId[tokenId]==false,"NFT already identified");
    require(super.ownerOf(tokenId)==msg.sender,"Not owner of NFT");

    bool success=false;
    uint organism = randomNum(tokenId,msg.sender);
    if(organism==0){
    //SUPAVirus
    success =SUPAVirus.mint(msg.sender);
    } else{
    //SUPACell
    success=  SUPACell.mint(msg.sender);
    }
    if(success==true){
    _burn(tokenId);
    seenNoncesTokenId[tokenId]=true;
    }
    //Mint
    //burn

    }
 

  function randomNum(uint256 tokenId, address sender) public view returns(uint256) {
      uint256 num = uint(keccak256(abi.encodePacked(block.timestamp, sender, blockhash(block.number-1), block.difficulty,tokenId))) % 2;
      return num;
  }
    function _baseURI() internal view override returns (string memory) {
    return base;
  }
  function setBaseURI(string memory _base) public onlyRole(MINTER_ROLE) {
     
    base = _base;
   
  }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
       override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl, ERC2981Base,ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
   function remainingSupply() external view returns (uint256) {
    return mintSize-_tokenIdCounter.current();
  }
    function totalMinted() external view returns (uint256) {
    return _tokenIdCounter.current();
  }
  function userMintedWithGenesis(string memory discordUser) external view returns (uint) {
    return  seenNoncesDiscord[discordUser].current();
  }
  function userMintedWithOG(uint OGTokenID) external view returns (uint) {
    return  seenNoncesOG[OGTokenID].current();
  }
    function setRoyalties(address recipient, uint256 value) public onlyRole(MINTER_ROLE){
        _setRoyalties(recipient, value);
    }

function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

}
