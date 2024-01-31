// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * @title NovaNexHub
 * @dev ERC721 contract representing a decentralized hub for digital items with associated metadata.
 */
contract NovaNexHub is ERC721Enumerable {
  address public marketplace;
  address public owner;

  // Struct to represent an item with associated creator and metadata URI
  struct Item {
    address creator;
    string uri; // metadata url
  }

  // Mapping to store items with their corresponding token IDs
  mapping(uint256 => Item) public Items; // id => Item

  // Variable to keep track of the next available token ID
  uint256 private _tokenId = 1;

  // Constructor to initialize the contract with a name and symbol
  constructor() ERC721("NovaNexHub", "NNH") {
    owner = msg.sender;
  }

  // Modifier to restrict access to the owner of the contract
  modifier onlyOwner() {
    require(msg.sender == owner, "Not the owner");
    _;
  }

  /**
   * @dev Mint a new token with the provided metadata URI.
   * @param uri The metadata URI associated with the minted token.
   * @return The ID of the newly minted token.
   */
  function mint(string memory uri) public returns (uint256) {
    // Get the next available token ID
    uint256 newItemId = _tokenId;

    // Mint the new token and assign it to the sender
    _safeMint(msg.sender, newItemId);

    // Approve the marketplace to transfer the token
    approve(marketplace, newItemId);

    // Store the item information in the mapping
    Items[newItemId] = Item({
      creator: msg.sender,
      uri: uri
    });

    // Increment the token ID for the next mint
    _tokenId++;

    // Return the ID of the newly minted token
    return newItemId;
  }

  /**
   * @dev Get the metadata URI associated with a given token ID.
   * @param tokenId The ID of the token to retrieve metadata URI for.
   * @return The metadata URI of the specified token.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return Items[tokenId].uri;
  }

  /**
   * @dev Set the marketplace address. Only callable by the contract owner.
   * @param market The address of the marketplace contract.
   */
  function setMarketplace(address market) public onlyOwner {
    marketplace = market;
  }
}

//0x69E6B6202C01010a81E325B72cA45a4b467Cc0b6