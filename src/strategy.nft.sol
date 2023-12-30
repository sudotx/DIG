// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import solady for everything. including ownership, tokens(erc20, erc721)

import {ERC721} from "solady/tokens/ERC721.sol";

contract Strat is ERC721 {
    /// @dev Returns the token collection name.
    function name() public view override returns (string memory) {
        return "TEST NFT";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public view override returns (string memory) {
        return "TEST";
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(id, ""));
    }
}
