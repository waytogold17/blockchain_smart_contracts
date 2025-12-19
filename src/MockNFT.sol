// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MemberNFT", "MNFT") {}

    // Une fonction simple pour créer des NFTs pour nos tests
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}