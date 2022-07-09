// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {Counters} from "openzeppelin-contracts/utils/Counters.sol";

import {Perwei, Period, Harberger} from "./Harberger.sol";
import {ERC4907} from "./ERC4907.sol";

struct Assessment {
  address seller;
  uint256 startBlock;
  uint256 collateral;
  Perwei taxRate;
}

abstract contract PluralProperty is ERC4907 {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  mapping(uint256 => Assessment) private _assessments;
  mapping(uint256 => string) private _tokenURIs;

  constructor(
    string memory name_,
    string memory symbol_
  ) ERC4907(name_, symbol_) {}

  function _setTokenURI(
    uint256 _tokenId,
    string memory _tokenURI
  ) internal virtual {
    require(_exists(_tokenId), "_setTokenURI: token doesn't exist");
    _tokenURIs[_tokenId] = _tokenURI;
  }

  function tokenURI(
    uint256 tokenId
  ) public view virtual override returns (string memory) {
    require(_exists(tokenId), "tokenURI: token doesn't exist");
    return _tokenURIs[tokenId];
  }

  function getAssessment(
    uint256 tokenId
  ) public view virtual returns (Assessment memory assessment) {
    require(_exists(tokenId), "getAssessment: token doesn't exist");
    assessment = _assessments[tokenId];
  }

  function setTaxRate(uint256 tokenId, Perwei memory nextTaxRate) external {
    Assessment memory assessment = getAssessment(tokenId);
    require(
      msg.sender == assessment.taxRate.beneficiary,
      "setTaxRate: only beneficiary"
    );
    require(
      nextTaxRate.beneficiary != address(0),
      "setTaxRate: beneficiary not set"
    );
    assessment.taxRate = nextTaxRate;
    _assessments[tokenId] = assessment;
  }

  function getPrice(
    uint256 tokenId
  ) external view virtual returns (uint256 price, uint256 taxes) {
    require(_exists(tokenId), "getPrice: token doesn't exist");
    Assessment memory assessment = _assessments[tokenId];

    (price, taxes) = Harberger.getNextPrice(
      assessment.taxRate,
      Period(assessment.startBlock, block.number),
      assessment.collateral
    );
  }

  function mint(
    Perwei memory taxRate,
    string calldata uri
  ) external payable virtual returns (uint256) {
    require(msg.value > 0, "mint: not enough ETH");
    require(taxRate.beneficiary != address(0), "mint: beneficiary not set");

    uint256 tokenId = _tokenIds.current();
    _mint(address(this), tokenId);
    _setTokenURI(tokenId, uri);
    _tokenIds.increment();
    // this errors as `setUser` assumes the transaction's caller to be the
    // owner. So we probably have to restructure this contract somewhat and
    // separate the auction house operator from the token itself.
    setUser(tokenId, msg.sender, 0);

    Assessment memory assessment = Assessment(
      msg.sender,
      block.number,
      msg.value,
      taxRate
    );
    _assessments[tokenId] = assessment;

    return tokenId;
  }

  function _settleTaxes(
    uint256 tokenId
  ) internal virtual returns (Assessment memory, uint256) {
    Assessment memory assessment = getAssessment(tokenId);
    (uint256 nextPrice, uint256 taxes) = Harberger.pay(
      assessment.taxRate,
      Period(assessment.startBlock, block.number),
      assessment.collateral
    );

    payable(assessment.taxRate.beneficiary).transfer(taxes);

    return (assessment, nextPrice);
  }

  function topup(uint256 tokenId) external virtual payable {
    require(msg.value > 0, "topup: must send eth");
    (
      Assessment memory assessment,
      uint256 nextPrice
    ) = _settleTaxes(tokenId);
    require(msg.value > nextPrice, "topup: msg.value too low");
    require(assessment.seller == msg.sender, "topup: only seller");

    Assessment memory nextAssessment = Assessment(
      msg.sender,
      block.number,
      msg.value + nextPrice,
      assessment.taxRate
    );
    _assessments[tokenId] = nextAssessment;
  }

  function withdraw(uint256 tokenId, uint256 amount) external virtual {
    (
      Assessment memory assessment,
      uint256 nextPrice
    ) = _settleTaxes(tokenId);

    require(assessment.seller == msg.sender, "withdraw: only seller");
    require(amount <= nextPrice, "withdraw: amount too big");

    Assessment memory nextAssessment = Assessment(
      msg.sender,
      block.number,
      nextPrice - amount,
      assessment.taxRate
    );
    _assessments[tokenId] = nextAssessment;

    payable(assessment.seller).transfer(amount);
  }

  function buy(
    uint256 tokenId
  ) external virtual payable {
    require(msg.value > 0, "buy: must send eth");
    (
      Assessment memory assessment,
      uint256 nextPrice
    ) = _settleTaxes(tokenId);
    require(msg.value > nextPrice, "buy: msg.value too low");

    Assessment memory nextAssessment = Assessment(
      msg.sender,
      block.number,
      msg.value,
      assessment.taxRate
    );
    _assessments[tokenId] = nextAssessment;

    setUser(tokenId, msg.sender, 0);
    emit Transfer(assessment.seller, msg.sender, tokenId);

    payable(assessment.seller).transfer(nextPrice);
  }
}
