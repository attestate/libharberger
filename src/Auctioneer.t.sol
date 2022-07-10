// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Auctioneer} from "./Auctioneer.sol";
import {ERC4907} from "ERC4907/ERC4907.sol";

contract NFT is ERC721 {
  constructor(
    string memory name,
    string memory symbol
  ) ERC721(name, symbol) {}
  function mint(address to, uint256 tokenId) external {
    _mint(to, tokenId);
  }
}

contract RNFT is ERC4907 {
  constructor(
    string memory name,
    string memory symbol
  ) ERC4907(name, symbol) {}
  function mint(address to, uint256 tokenId) external {
    _mint(to, tokenId);
  }
}

contract AuctioneerTest is Test {
  Auctioneer a;
  NFT token;
  RNFT rnft;

  function setUp() public {
    a = new Auctioneer();
    token = new NFT("name", "symbol");
    rnft = new RNFT("rnft", "rnft");
  }

  function testIngestingERC721Token() public {
    uint256 tokenId = 0;
    token.mint(address(this), tokenId);

    address collection = address(token);
    vm.expectRevert(bytes("ingest: must be ERC4907 compatible"));
    a.ingest(collection, tokenId);
  }

  function testIngestingERC4907Token() public {
    uint256 tokenId = 0;
    rnft.mint(address(this), tokenId);

    address collection = address(rnft);
    a.ingest(collection, tokenId);
  }
}
