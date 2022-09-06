// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/DomStrategyGame.sol";

contract DomStrategyGameTest is Test {
    DomStrategyGame public game;
    Loot public loot;

    function setUp() public {
        loot = new Loot();
        game = new DomStrategyGame(loot);
    }

    function testConnect() public {
        loot.mint(address(this), 1);
        loot.setApprovalForAll(address(game), true);

        game.connect{value: 1 ether}(1);
    }
}

contract Loot is ERC721 {
    constructor() ERC721("Loot", "Loot") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
