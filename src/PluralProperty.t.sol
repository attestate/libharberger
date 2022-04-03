// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {DSTest} from "ds-test/test.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {PluralProperty, Assessment} from "./PluralProperty.sol";
import {Perwei} from "./Harberger.sol";

contract HarbergerProperty is PluralProperty {
  constructor() PluralProperty("Name", "Symbol") {}
}

contract Buyer {
  function proxyBuy(address propAddr,uint256 tokenId) payable public {
    HarbergerProperty prop = HarbergerProperty(propAddr);
    prop.buy{value: msg.value}(tokenId);
  }
}

interface Vm {
  function roll(uint x) external;
}

contract PluralPropertyTest is DSTest {
  HarbergerProperty prop;
  Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

  function setUp() public {
    prop = new HarbergerProperty();
  }
  receive() external payable {}

  function testInterfaceCompatability() public {
    assertTrue(prop.supportsInterface(type(IERC165).interfaceId));
    assertTrue(prop.supportsInterface(type(IERC721Metadata).interfaceId));
  }

  function testCheckMetadata() public {
    assertEq(prop.name(), "Name");
    assertEq(prop.symbol(), "Symbol");

    string memory tokenURI = "https://example.com/metadata.json";
    uint256 tokenId = prop.mint{value: 1}(
      Perwei(0, 0),
      tokenURI
    );
    assertEq(prop.tokenURI(tokenId), tokenURI);
  }

  function testFailRequestingNonExistentTokenURI() public view {
    prop.tokenURI(1337);
  }

  function testFailGetOwnerOfNonExistentTokenId() public view {
    prop.ownerOf(1337);
  }

  function testBuyAndChangingOwner() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    uint256 tokenId = prop.mint{value: collateral}(
      taxRate,
      "https://example.com/metadata.json"
    );
    assertEq(prop.ownerOf(tokenId), address(this));

    uint256 firstBalance = address(this).balance;

    Buyer buyer = new Buyer();
    buyer.proxyBuy{value: 1.1 ether}(address(prop), tokenId);
    assertEq(prop.ownerOf(tokenId), address(buyer));

    uint256 secondBalance = address(this).balance;
    uint256 endBlock = block.number;
    assertEq(endBlock-startBlock, 0);
    assertEq(firstBalance-secondBalance, 0.1 ether);
    assertEq(address(prop).balance, 1.1 ether);
  }

  function testFailBuyWithFalsePrice() public {
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      "https://example.com/metadata.json"
    );

    Buyer buyer = new Buyer();
    assertEq(prop.ownerOf(tokenId0), address(this));
    buyer.proxyBuy{value: 0.1 ether}(address(prop), tokenId0);
    assertEq(prop.ownerOf(tokenId0), address(this));
  }

  function testFailBuyOnNonExistentProperty() public {
    prop.buy{value: 1 ether}(1337);
  }

  function testFailBuyNonExistentTokenId() public {
    prop.buy{value: 1 ether}(1337);
  }

  function testFailMintPropertyWithoutValue() public {
    Perwei memory taxRate = Perwei(1, 100);
    string memory uri = "https://example.com/metadata.json";
    prop.mint{value: 0}(
      taxRate,
      uri
    );
  }

  function testFailMintWithoutValue() public {
    prop.mint(Perwei(0, 0), "https://example.com/metadata.json");
  }

  function testMintProperty() public {
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    uint256 tokenId1 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId1, 1);
  }

  function testGettingAssessment() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    Assessment memory assessment = prop.getAssessment(tokenId0);
    assertEq(assessment.seller, address(this));
    assertEq(assessment.startBlock, startBlock);
    assertEq(assessment.collateral, collateral);
    assertEq(assessment.taxRate.numerator, taxRate.numerator);
    assertEq(assessment.taxRate.denominator, taxRate.denominator);
  }

  function testMintAndCheckPrice() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    assertEq(startBlock, block.number);
    assertEq(prop.getPrice(tokenId0), collateral);

    vm.roll(block.number+1);
    assertEq(startBlock+1, block.number);
    assertEq(prop.getPrice(tokenId0), 0.99 ether);

    vm.roll(block.number+1);
    assertEq(startBlock+2, block.number);
    assertEq(prop.getPrice(tokenId0), 0.98 ether);
  }

  function testGivingAwayOldProperty() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    assertEq(startBlock, block.number);
    assertEq(prop.getPrice(tokenId0), collateral);

    vm.roll(block.number+99);
    assertEq(startBlock+99, block.number);
    assertEq(prop.getPrice(tokenId0), 0.01 ether);

    vm.roll(block.number+1);
    assertEq(startBlock+100, block.number);
    assertEq(prop.getPrice(tokenId0), 0);

    vm.roll(block.number+1);
    assertEq(startBlock+101, block.number);
    assertEq(prop.getPrice(tokenId0), 0);
  }
}

