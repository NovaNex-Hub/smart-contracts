// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NovaNexHub is ERC721Enumerable {
  address public marketplace;
  address public owner;

  struct Item {
    address creator;
    string uri; //metadata url
  }

  mapping(uint256 => Item) public Items; //id => Item
  uint256 private _tokenId = 1;

  constructor() ERC721("NovaNexHub", "NNH") {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Not the owner");
    _;
  }

  function mint(string memory uri) public returns (uint256) {
    uint256 newItemId = _tokenId;
    _safeMint(msg.sender, newItemId);
    approve(marketplace, newItemId);

    Items[newItemId] = Item({
      creator: msg.sender,
      uri: uri
    });

    _tokenId++;

    return newItemId;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return Items[tokenId].uri;
  }

  function setMarketplace(address market) public onlyOwner {
    marketplace = market;
  }
}
