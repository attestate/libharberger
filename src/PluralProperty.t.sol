// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {DSTest} from "ds-test/test.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {PluralProperty, Assessment} from "./PluralProperty.sol";
import {Perwei} from "./Harberger.sol";

contract HarbergerProperty is PluralProperty {
  constructor() PluralProperty("Name", "Symbol") {}
}

contract Buyer {
  function proxyBuy(address propAddr, uint256 tokenId) payable public {
    HarbergerProperty prop = HarbergerProperty(propAddr);
    prop.buy{value: msg.value}(tokenId);
  }

  function proxyTopup(address propAddr, uint256 tokenId) payable public {
    HarbergerProperty prop = HarbergerProperty(propAddr);
    prop.topup{value: msg.value}(tokenId);
  }

  function proxyWithdraw(
    address propAddr,
    uint256 tokenId,
    uint256 amount
  ) payable public {
    HarbergerProperty prop = HarbergerProperty(propAddr);
    prop.withdraw(tokenId, amount);
  }

  function proxySetTaxRate(
    address propAddr,
    uint256 tokenId,
    Perwei memory nextTaxRate
  ) public {
    HarbergerProperty prop = HarbergerProperty(propAddr);
    prop.setTaxRate(tokenId, nextTaxRate);
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
      Perwei(0, 0, address(this)),
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
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    uint256 tokenId = prop.mint{value: collateral}(
      taxRate,
      "https://example.com/metadata.json"
    );
    assertEq(prop.ownerOf(tokenId), address(this));

    assertEq(beneficiary.balance, 0);
    assertEq(startBlock, block.number);
    vm.roll(block.number+10);
    assertEq(startBlock+10, block.number);

    (uint256 nextPrice, uint256 taxes) = prop.getPrice(tokenId);
    assertEq(nextPrice, 0.9 ether);
    assertEq(taxes, 0.1 ether);

    uint256 originalBalance = address(this).balance - 1 ether;
    Buyer buyer = new Buyer();
    buyer.proxyBuy{value: 1 ether}(address(prop), tokenId);
    assertEq(prop.ownerOf(tokenId), address(buyer));
    assertEq(beneficiary.balance, 0.1 ether);
    assertEq(address(this).balance - originalBalance, 0.9 ether);

    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId);
    assertEq(nextPrice1, 1 ether);
    assertEq(taxes1, 0);

    //uint256 secondBalance = address(this).balance;
    //uint256 endBlock = block.number;
    //assertEq(endBlock-startBlock, 0);
    //assertEq(firstBalance-secondBalance, 0.1 ether);
    //assertEq(address(prop).balance, 1.1 ether);
  }

  function testFailMintWithUndefinedBenificiary() public {
    Perwei memory taxRate = Perwei(1, 100, address(0));
    prop.mint{value: 1 ether}(
      taxRate,
      "https://example.com/metadata.json"
    );
  }

  function testFailBuyWithFalsePrice() public {
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100, address(this));
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
    Perwei memory taxRate = Perwei(1, 100, address(this));
    string memory uri = "https://example.com/metadata.json";
    prop.mint{value: 0}(
      taxRate,
      uri
    );
  }

  function testFailMintWithoutValue() public {
    prop.mint(Perwei(0, 0, address(this)), "https://example.com/metadata.json");
  }

  function testFailToppingUpAsNonOwner() public {
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    Buyer buyer = new Buyer();
    buyer.proxyTopup{value: 1.1 ether}(address(prop), tokenId0);
  }

  function testFailWithdrawingAsNonOwner() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    Buyer buyer = new Buyer();
    buyer.proxyWithdraw(address(prop), tokenId0, 0.01 ether);
  }

  function testFailWithdrawingTooMuch() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    assertEq(block.number, startBlock);
    vm.roll(block.number + 50);
    assertEq(block.number, startBlock + 50);

    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, 0.5 ether);
    assertEq(taxes0, 0.5 ether);
    assertEq(beneficiary.balance, 0);
    uint256 balanceBeforeWithdraw = address(this).balance;
    // collateral is: + 1 ether
    //                - 0.5 ether taxes
    //                ------------------
    //                = 0.5 ether
    uint256 amount = 0.51 ether;
    prop.withdraw(tokenId0, amount);
    // new            + 0.5 ether (after taxes)
    //                - 0.51 ether from withdraw
    //                --------------------------
    //                = - 0.01 ether
    //                should fail...
  }

  function testWithdrawingAll() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    assertEq(block.number, startBlock);
    vm.roll(block.number + 50);
    assertEq(block.number, startBlock + 50);

    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, 0.5 ether);
    assertEq(taxes0, 0.5 ether);
    assertEq(beneficiary.balance, 0);
    uint256 balanceBeforeWithdraw = address(this).balance;
    // collateral is: + 1 ether
    //                - 0.5 ether taxes
    //                ------------------
    //                = 0.5 ether
    uint256 amount = 0.5 ether;
    prop.withdraw(tokenId0, amount);
    // new            + 0.5 ether (after taxes)
    //                - 0.5 ether from withdraw
    //                --------------------------
    //                = 0 ether
    assertEq(beneficiary.balance, 0.5 ether);
    assertEq(address(prop).balance, 0);
    assertEq(balanceBeforeWithdraw + amount, address(this).balance);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 0);
    assertEq(taxes1, 0);
  }

  function testWithdrawingFromProperty() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    assertEq(block.number, startBlock);
    vm.roll(block.number + 50);
    assertEq(block.number, startBlock + 50);

    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, 0.5 ether);
    assertEq(taxes0, 0.5 ether);
    assertEq(beneficiary.balance, 0);
    uint256 balanceBeforeWithdraw = address(this).balance;
    // collateral is: + 1 ether
    //                - 0.5 ether taxes
    //                ------------------
    //                = 0.5 ether
    uint256 amount = 0.4 ether;
    prop.withdraw(tokenId0, amount);
    // new            + 0.5 ether (after taxes)
    //                - 0.4 ether from withdraw
    //                --------------------------
    //                = 0.1 ether
    assertEq(beneficiary.balance, 0.5 ether);
    assertEq(balanceBeforeWithdraw + amount, address(this).balance);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 0.1 ether);
    assertEq(taxes1, 0);
  }

  function testToppingUpProperty() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    assertEq(block.number, startBlock);
    vm.roll(block.number + 50);
    assertEq(block.number, startBlock + 50);

    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, 0.5 ether);
    assertEq(taxes0, 0.5 ether);
    assertEq(beneficiary.balance, 0);
    // collateral is: + 1 ether
    //                - 0.5 ether taxes
    //                ------------------
    //                = 0.5 ether
    prop.topup{value: 0.51 ether}(tokenId0);
    // new            + 0.5 ether (after taxes)
    //                + 0.51 ether from topup
    //                --------------------------
    //                = 1.01 ether
    assertEq(beneficiary.balance, 0.5 ether);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 1.01 ether);
    assertEq(taxes1, 0);
  }

  function testToppingUpProperty2() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    address beneficiary = address(1337);
    Perwei memory taxRate = Perwei(1, 100, beneficiary);
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );
    assertEq(tokenId0, 0);

    assertEq(block.number, startBlock);
    vm.roll(block.number + 50);
    assertEq(block.number, startBlock + 50);

    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, 0.5 ether);
    assertEq(taxes0, 0.5 ether);

    assertEq(beneficiary.balance, 0);
    prop.topup{value: 2 ether}(tokenId0);

    assertEq(beneficiary.balance, 0.5 ether);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 2.5 ether);
    assertEq(taxes1, 0);
  }

  function testMintProperty() public {
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100, address(this));
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

  function testSettingTaxRate() public {
    uint256 collateral = 1 ether;
    Buyer buyer = new Buyer();
    Perwei memory taxRate = Perwei(1, 100, address(buyer));
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    Perwei memory nextTaxRate = Perwei(2, 100, address(buyer));
    buyer.proxySetTaxRate(address(prop), tokenId0, nextTaxRate);
    Assessment memory assessment = prop.getAssessment(tokenId0);
    assertEq(assessment.taxRate.numerator, 2);
    assertEq(assessment.taxRate.denominator, 100);
    assertEq(assessment.taxRate.beneficiary, address(buyer));
  }

  function testFailSettingTaxRateToZeroAddress() public {
    uint256 collateral = 1 ether;
    Buyer buyer = new Buyer();
    Perwei memory taxRate = Perwei(1, 100, address(buyer));
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    Perwei memory nextTaxRate = Perwei(2, 100, address(0));
    buyer.proxySetTaxRate(address(prop), tokenId0, nextTaxRate);
  }

  function testFailSettingTaxRateAsNonBeneficiary() public {
    uint256 collateral = 1 ether;
    Buyer buyer = new Buyer();
    Perwei memory taxRate = Perwei(1, 100, address(this));
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    Perwei memory nextTaxRate = Perwei(2, 100, address(buyer));
    buyer.proxySetTaxRate(address(prop), tokenId0, nextTaxRate);
  }

  function testGettingAssessment() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100, address(this));
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
    Perwei memory taxRate = Perwei(1, 100, address(this));
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    assertEq(startBlock, block.number);
    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, collateral);
    assertEq(taxes0, 0);

    vm.roll(block.number+1);
    assertEq(startBlock+1, block.number);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 0.99 ether);
    assertEq(taxes1, 0.01 ether);

    vm.roll(block.number+1);
    assertEq(startBlock+2, block.number);
    (uint256 nextPrice2, uint256 taxes2) = prop.getPrice(tokenId0);
    assertEq(nextPrice2, 0.98 ether);
    assertEq(taxes2, 0.02 ether);
  }

  function testGivingAwayOldProperty() public {
    uint256 startBlock = block.number;
    uint256 collateral = 1 ether;
    Perwei memory taxRate = Perwei(1, 100, address(this));
    string memory uri = "https://example.com/metadata.json";
    uint256 tokenId0 = prop.mint{value: collateral}(
      taxRate,
      uri
    );

    assertEq(startBlock, block.number);
    (uint256 nextPrice0, uint256 taxes0) = prop.getPrice(tokenId0);
    assertEq(nextPrice0, collateral);
    assertEq(taxes0, 0);

    vm.roll(block.number+99);
    assertEq(startBlock+99, block.number);
    (uint256 nextPrice1, uint256 taxes1) = prop.getPrice(tokenId0);
    assertEq(nextPrice1, 0.01 ether);
    assertEq(taxes1, 0.99 ether);

    vm.roll(block.number+1);
    assertEq(startBlock+100, block.number);
    (uint256 nextPrice2, uint256 taxes2) = prop.getPrice(tokenId0);
    assertEq(nextPrice2, 0);
    assertEq(taxes2, collateral);

    vm.roll(block.number+1);
    assertEq(startBlock+101, block.number);
    (uint256 nextPrice3, uint256 taxes3) = prop.getPrice(tokenId0);
    assertEq(nextPrice3, 0);
    assertEq(taxes3, collateral);
  }
}

