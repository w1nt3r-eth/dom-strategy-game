// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/DomStrategyGame.sol";

contract DomStrategyGameTest is Test {
    DomStrategyGame public game;
    Loot public loot;

    address w1nt3r = 0x1E79b045Dc29eAe9fdc69673c9DCd7C53E5E159D;
    address dhof = 0xF296178d553C8Ec21A2fBD2c5dDa8CA9ac905A00;

    function setUp() public {
        loot = new Loot();
        game = new DomStrategyGame(loot);

        vm.deal(w1nt3r, 1 ether);
        vm.deal(dhof, 1 ether);
    }

    function testGame() public {
        vm.startPrank(w1nt3r);
        loot.mint(w1nt3r, 1);
        loot.setApprovalForAll(address(game), true);
        game.connect{value: 1 ether}(1);
        vm.stopPrank();

        vm.startPrank(dhof);
        loot.mint(dhof, 2);
        loot.setApprovalForAll(address(game), true);
        game.connect{value: 1 ether}(2);
        vm.stopPrank();

        game.start();

        bytes32 nonce1 = hex"01";
        bytes32 nonce2 = hex"02";
        uint256 turn = 1;

        bytes memory call1 = abi.encodeWithSelector(
            DomStrategyGame.rest.selector
        );
        vm.prank(w1nt3r);
        game.submit(1, keccak256(abi.encodePacked(turn, nonce1, call1)));

        bytes memory call2 = abi.encodeWithSelector(
            DomStrategyGame.move.selector,
            uint8(3)
        );
        vm.prank(dhof);
        game.submit(1, keccak256(abi.encodePacked(turn, nonce2, call2)));

        vm.warp(block.timestamp + 19 hours);

        vm.prank(w1nt3r);
        game.reveal(turn, nonce1, call1);

        vm.prank(dhof);
        game.reveal(turn, nonce2, call2);
    }
}

contract Loot is ERC721 {
    constructor() ERC721("Loot", "Loot") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
