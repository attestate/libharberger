// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {DSTest} from "ds-test/test.sol";

import {Harberger, Period, Perwei} from "./Harberger.sol";

contract PropertyMock {
  function pay(
    Perwei memory perwei,
    Period memory period,
    uint256 prevPrice
  ) external payable returns (uint256 nextPrice, uint256 taxes) {
    return Harberger.pay(perwei, period, prevPrice);
  }
}

contract HarbergerTest is DSTest {
  PropertyMock p;

  function setUp() public {
    p = new PropertyMock();
  }

  function testFailSendingTooLittleEther() public {
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    Period memory period1 = Period(0, 1);
    uint256 prevPrice = 1 ether;
    p.pay{value: 0.98 ether}(
      perwei1,
      period1,
      prevPrice
    );
  }

  function testFailSendingNoEther() public {
    Perwei memory perwei1 = Perwei(100, 100, address(this));
    Period memory period1 = Period(0, 50);
    uint256 prevPrice = 0;
    p.pay(
      perwei1,
      period1,
      prevPrice
    );
  }

  function testPayingNothing() public {
    Perwei memory perwei1 = Perwei(100, 100, address(this));
    Period memory period1 = Period(0, 50);
    uint256 prevPrice = 0;
    (uint256 nextPrice, uint256 taxes) = p.pay{value: 1}(
      perwei1,
      period1,
      prevPrice
    );
    assertEq(nextPrice, 0);
    assertEq(taxes, 0);
  }

  function testPaying() public {
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    Period memory period1 = Period(0, 1);
    uint256 prevPrice = 1 ether;
    (uint256 nextPrice, uint256 taxes) = p.pay{value: 0.991 ether}(
      perwei1,
      period1,
      prevPrice
    );

    assertEq(nextPrice, 0.99 ether);
    assertEq(taxes, 0.01 ether);
  }

  function testPriceZero() public {
    Period memory period1 = Period(0, 50);
    Perwei memory perwei1 = Perwei(100, 100, address(this));

    uint256 price = 0;
    (uint256 nextPrice, uint256 taxes) = Harberger.getNextPrice(
      perwei1,
      period1,
      price
    );
    assertEq(nextPrice, 0);
    assertEq(taxes, 0);
  }

  function testUsedBuffer() public {
    Period memory period1 = Period(0, 50);
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    uint256 price = 1 ether;

    (uint256 nextPrice, uint256 taxes) = Harberger.getNextPrice(
      perwei1,
      period1,
      price
    );
    assertEq(nextPrice, 0.5 ether);
    assertEq(taxes, 0.5 ether);
  }

  function testLowerPrice() public {
    Period memory period1 = Period(0, 51);
    Perwei memory perwei1= Perwei(1, 100, address(this));
    uint256 price = 1 ether;

    (uint256 nextPrice, uint256 taxes) = Harberger.getNextPrice(
      perwei1,
      period1,
      price
    );
    assertEq(nextPrice, 0.49 ether);
    assertEq(taxes, 0.51 ether);
  }

  function testConsumingTotalPrice() public {
    Period memory period1 = Period(0, 150);
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    uint256 price = 1 ether;

    (uint256 nextPrice, uint256 taxes) = Harberger.getNextPrice(
      perwei1,
      period1,
      price
    );
    assertEq(nextPrice, 0);
    assertEq(taxes, 1 ether);
  }

  function testGettingNextPrice() public {
    Period memory period1 = Period(0, 1);
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    uint256 price = 1 ether;

    (uint256 nextPrice, uint256 taxes) = Harberger.getNextPrice(
      perwei1,
      period1,
      price
    );
    assertEq(nextPrice, 0.99 ether);
    assertEq(taxes, 0.01 ether);
  }

  function testBlockTax() public {
    Period memory period1 = Period(0, 1);
    Perwei memory perwei1 = Perwei(1, 100, address(this));
    assertEq(Harberger.taxPerBlock(perwei1, period1, 1 ether), 0.01 ether);

    Period memory period2 = Period(0, 2);
    Perwei memory perwei2 = Perwei(1, 100, address(this));
    assertEq(Harberger.taxPerBlock(perwei2, period2, 1 ether), 0.02 ether);

    Period memory period3 = Period(0, 100);
    Perwei memory perwei3 = Perwei(1, 100, address(this));
    assertEq(Harberger.taxPerBlock(perwei3, period3, 1 ether), 1 ether);

    Period memory period4 = Period(0, 2);
    Perwei memory perwei4 = Perwei(100, 100, address(this));
    assertEq(Harberger.taxPerBlock(perwei4, period4, 1 ether), 2 ether);

    Period memory period5 = Period(0, 1);
    Perwei memory perwei5 = Perwei(1, 1000, address(this));
    assertEq(Harberger.taxPerBlock(perwei5, period5, 1 ether), 0.001 ether);

    Period memory period6 = Period(0, 1);
    // NOTE: To test the precision up to 18 decimals, we're gonna simulate a
    // tax that is 1 WEI per block.
    Perwei memory perwei6 = Perwei(1, 1e18, address(this));
    assertEq(Harberger.taxPerBlock(perwei6, period6, 1 ether), 1 wei);
  }
}
