// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./chainlink.sol";
import "./Verifier.sol";

interface IVerifier {
    function verify(
        address user
    )
        external
        view
        returns (
            //bytes32 documentHash
            bool
        );
}

contract LanSeller is ERC721URIStorage, ReentrancyGuard {
    uint256 private fee;
    IERC20 public lstToken;
    //uint256 public  listNewProperty;
    AggregatorV3Interface internal priceFeed;
    uint256 public tokenIdCounter;
    uint256 public constant PRICE_PRECISION = 100 * 10 ** 18;
    uint256 public listingFee = 1 * 10 ** 18;
    uint256 public constant KYC_VALIDITY_PERIOD = 365 days;

    IVerifier public verifier;

    struct Property {
        uint256 tokenId;
        address seller;
        uint256 price;
        address buyer;
        bool forSale;
        string ipfsHash;
    }

    event PropertySold(
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price
    );
    event KYCVerified(address indexed user);
    event Withdrawal(address indexed to, uint256 amount);
    event ListingFeeUpdated(uint256 newFee);
    event PropertyBought(
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price
    );
    event PropertyListingCanceled(
        address indexed seller,
        uint256 indexed tokenId
    );
    // Modified PropertyListed event
    event PropertyListed(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price,
        bool forSale,
        string ipfsHash
    );

    mapping(address => bool) private kycVerified;
    mapping(uint256 => Property) public properties;
    mapping(address => uint256) public funds;
    mapping(address => string) public userBasenames;
    mapping(address => bool) private _hasListed;
    mapping(uint256 => bool) public compromisedNFTs;
    mapping(uint256 => bytes32) public documentHashes;
    mapping(uint256 => string) public propertyBasenames;
    mapping(address => bool) public isSmartWalletConnected;

    modifier isKYCVerified() {
        require(kycVerified[msg.sender], "KYC not verified");
        _;
    }

    // Modifier to check if a property is listed for sale
    modifier isListed(uint256 tokenId) {
        require(properties[tokenId].forSale, "Item not listed for sale");
        _;
    }

    modifier onlyOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        _;
    }

    // Check if a User Has Listed Property
    function hasUserListed(address user) external view returns (bool) {
        return _hasListed[user];
    }

    constructor(
        address _lstToken,
        address _verifier
    ) ERC721("LanStellar Property Token", "LSPT") {
        priceFeed = AggregatorV3Interface(
            0x3ec8593F930EA45ea58c968260e6e9FF53FC934f
        ); // Sepolia price feed
        lstToken = IERC20(_lstToken); // Token contract
        verifier = IVerifier(_verifier);
    }

    // 1. Verify KYC
    function verifyKYC(address _user) external nonReentrant {
        kycVerified[_user] = true;
    }

    // 2. Create a new token and list it
    function createToken( string memory tokenURI, uint256 price,string memory ipfsHash
    ) external isKYCVerified {
        tokenIdCounter++;
        uint256 newTokenId = tokenIdCounter;

        _mint(msg.sender, newTokenId); // Mint the new token
        _setTokenURI(newTokenId, tokenURI); // Set token URI

        listNewProperty(newTokenId, price, ipfsHash); // List the property immediately
        _hasListed[msg.sender] = true;
    }

    function invalidateAndUpgradeNFT(
        uint256 tokenId,
        string memory newTokenURI
    ) external onlyOwner(tokenId) {
        compromisedNFTs[tokenId] = true; // Mark NFT as compromised
        uint256 newTokenId = tokenIdCounter++;
        _mint(msg.sender, newTokenId); // Mint new NFT
        _setTokenURI(newTokenId, newTokenURI); // Assign new token URI
    }

    // function uploadDocument(uint256 tokenId,bytes32 documentHash,bytes memory zkProof) external isKYCVerified {
    //     // Verify the document using zk-SNARK proof
    //     require(verifier.verify(user), "Invalid document proof");
    //     documentHashes[tokenId] = documentHash; // Store document hash on-chain
    // }

    function invalidateCompromisedNFT(uint256 tokenId) external {
        require(compromisedNFTs[tokenId], "NFT is not compromised");
        _burn(tokenId); // Burn the compromised NFT
    }
   
    //List a newly created property (internal function)

    function listNewProperty(
        uint256 tokenId,
        uint256 price,
        string memory ipfsHash
    ) public isKYCVerified {
        Property storage property  = properties[tokenId];

            property.tokenId= tokenId;
            property.seller= msg.sender;
            property.price= price;
            property.forSale= true;
            property.ipfsHash=ipfsHash
        ;

        // In the listNewProperty function, emit with the Basename
        emit PropertyListed(
            msg.sender,
            tokenId,
            price,
            true,
            ipfsHash
        );
    }
    // Approve the contract to transfer the tokenId on behalf of the current owner
function approveContractForTransfer(uint256 tokenId) external {
    approve(address(this), tokenId); // Approving the contract to transfer tokenId
}


    function buyProperty(
        uint256 tokenId,
        uint256 _amount
    ) external isListed(tokenId) nonReentrant {
        Property memory property = properties[tokenId];

        uint256 transactionFee = property.price / 100;
        require( _amount >= (property.price + transactionFee),
            "Price plus fee not met"
        );
        require(
            lstToken.balanceOf(msg.sender) >= property.price + transactionFee,
            "insufficient fund"
        );
        uint256 tokenAmount = _amount;
        // Transfer tokens from the sender to this contract
        require(
            lstToken.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );

        funds[property.seller] += property.price; // Payment to seller
        funds[address(this)] += transactionFee; // 1% fee to marketplace

        properties[tokenId].forSale = false;
        safeTransferFrom(property.seller, msg.sender, tokenId);

        properties[tokenId].seller = msg.sender;
        emit PropertySold(msg.sender, tokenId, property.price);
    }

    //  Update the price of a listed property
    function updatePropertyPrice(
        uint256 tokenId,
        uint256 newPrice,
        string memory ipfsHash
    ) external onlyOwner(tokenId) {
        require(newPrice > 0, "Price must be above zero");
        properties[tokenId].price = newPrice;
        // In the listNewProperty function, emit with the Basename
        emit PropertyListed(
            msg.sender,
            tokenId,
            newPrice,
            true,
            ipfsHash
             );
    }

    // FUNDS MANAGEMENT
function withdrawFunds() external nonReentrant {
    uint256 proceeds = funds[msg.sender];
    require(proceeds > 0, "No proceeds to withdraw");
    funds[msg.sender] = 0;

    // Use transfer instead of transferFrom, since the contract holds the tokens
    require(
        lstToken.transfer(msg.sender, proceeds),
        "Token transfer failed"
    );
    emit Withdrawal(msg.sender, proceeds);
}

    

    // 1.1 Get Property Details
    function getProperty(
        uint256 tokenId
    ) external view returns (Property memory) {
        return properties[tokenId];
    }

    // Get Token URI (for fetching token metadata)
    function getTokenURI(
        uint256 tokenId
    ) external view returns (string memory) {
        return tokenURI(tokenId);
    }

    // 1.3 Get KYC Status of a User
    function getKYCStatus(
        address user
    ) external view returns (bool isVerified) {
        return (kycVerified[user]);
    }

    // Get Funds Available for Withdrawal for a Seller
    function getSellerFunds(address seller) external view returns (uint256) {
        return funds[seller];
    }

    // Get Token Counter (For fetching current token count)
    function getTokenCounter() external view returns (uint256) {
        return tokenIdCounter;
    }

    // Get Listing Fee
    function getListingFee() external view returns (uint256) {
        return listingFee;
    }

    // check contract secure
    receive() external payable {
        revert("This contract does not accept Ether");
    }

    fallback() external payable {
        revert("This contract does not accept Ether");
    }

    // Update the listing fee
    function updateListingFee(uint256 _listingFee) public {
        listingFee = _listingFee;
        emit ListingFeeUpdated(_listingFee);
    }
    // Function to get all properties currently listed for sale
    function getListedProperties() external view returns (Property[] memory) {
        uint256 totalProperties = tokenIdCounter;
        uint256 listedCount = 0;

        // First, count how many properties are listed for sale
        for (uint256 i = 1; i <= totalProperties; i++) {
            if (properties[i].forSale) {
                listedCount++;
            }
        }

        // Create a new array to hold all listed properties
        Property[] memory listedProperties = new Property[](listedCount);
        uint256 index = 0;

        // Populate the array with listed properties
        for (uint256 i = 1; i <= totalProperties; i++) {
            if (properties[i].forSale) {
                listedProperties[index] = properties[i];
                index++;
            }
        }

        return listedProperties;
    }

    // Set the token URI for the NFT
    function _setTokenURI(
        uint256 tokenId,
        string memory tokenURI
    ) internal override {
        super._setTokenURI(tokenId, tokenURI);
    }
}
