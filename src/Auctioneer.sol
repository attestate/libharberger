// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC4907} from "ERC4907/IERC4907.sol";

//struct Assessment {
//  address collection;
//  address user;
//  uint256 startBlock;
//  uint256 collateral;
//  Perwei taxRate;
//}

contract Auctioneer is ERC721Holder {
  function ingest(address collection, uint256 tokenId) external {
    IERC4907 token = IERC4907(collection);
    require(
      token.supportsInterface(type(IERC4907).interfaceId),
      "ingest: must be ERC4907 compatible"
    );
  }
}
