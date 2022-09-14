// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "./mocks/MockVRFCoordinatorV2.sol";
import "../../script/HelperConfig.sol";
import "../DomStrategyGame.sol";
import "../Loot.sol";

contract MockBAYC is ERC721 {
    using Strings for uint256;

    string baseURI;
    
    error NonExistentTokenUri();
    constructor() ERC721("Bored Ape Yacht Club", "BAYC") {

    }
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenUri();
        }

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}

contract DomStrategyGameTest is Test {
    using stdStorage for StdStorage;

    DomStrategyGame public game;
    Loot public loot;
    MockBAYC public bayc;

    address w1nt3r = 0x1E79b045Dc29eAe9fdc69673c9DCd7C53E5E159D;
    address dhof = 0xF296178d553C8Ec21A2fBD2c5dDa8CA9ac905A00;

    HelperConfig helper = new HelperConfig();
    MockVRFCoordinatorV2 vrfCoordinator;

    function setUp() public {
        (
            ,
            ,
            ,
            address link,
            ,
            ,
            ,
            ,
            bytes32 keyHash
        ) = helper.activeNetworkConfig();

        vrfCoordinator = new MockVRFCoordinatorV2();
        uint64 subscriptionId = vrfCoordinator.createSubscription();
        uint96 FUND_AMOUNT = 1000 ether;
        vrfCoordinator.fundSubscription(subscriptionId, FUND_AMOUNT);

        bayc = new MockBAYC();
        loot = new Loot();
        game = new DomStrategyGame(loot, address(vrfCoordinator), link, subscriptionId, keyHash);

        vrfCoordinator.addConsumer(subscriptionId, address(game));

        vm.deal(w1nt3r, 1 ether);
        vm.deal(dhof, 100 ether);
    }

    function connect() public {
        vm.startPrank(w1nt3r);

        loot.mint(w1nt3r, 1);
        loot.setApprovalForAll(address(game), true);
        game.connect{value: 1 ether}(1, address(loot));
        vm.stopPrank();

        vm.startPrank(dhof);
        
        bayc.mint(dhof, 1);
        bayc.setApprovalForAll(address(game), true);
        game.connect{value: 6.9 ether}(1, address(bayc));
        vm.stopPrank();
    }

    function testConnect() public {
        connect();
        (,,,,,,,,uint256 x_w1nt3r,uint256 y_w1nt3r,,) = game.players(w1nt3r);
        (,,,,,,,,uint256 x_dhof,uint256 y_dhof,,) = game.players(dhof);

        require(game.spoils(w1nt3r) > 0, "Cannot play with 0 spoils, pleb.");
        require(game.spoils(dhof) > 0, "Cannot play with 0 spoils, pleb.");
        require(address(game).balance == 7.9 ether, "Game contract should escrow all the spoils.");
        require(x_w1nt3r == 0 && y_w1nt3r == 0, "First connector should occupy (0, 0)");
        require(x_dhof == 2 && y_dhof == 0, "Second connector should occupy (2, 0)");
    }

    function testGame() public {
        connect();
        
        game.start();

        bytes32 nonce1 = hex"01";
        bytes32 nonce2 = hex"02";
        uint256 turn = 1;

        // To make a move, you submit a hash of the intended move with the current turn, a nonce, and a call to either move or rest. Everyone's move is collected and then revealed at once after 18 hours
        vm.prank(w1nt3r);
        bytes memory call1 = abi.encodeWithSelector(
            DomStrategyGame.rest.selector,
            w1nt3r
        );
        game.submit(1, keccak256(abi.encodePacked(turn, nonce1, call1)));
        
        vm.prank(dhof);
        bytes memory call2 = abi.encodeWithSelector(
            DomStrategyGame.move.selector,
            dhof,
            int8(4)
        );
        game.submit(1, keccak256(abi.encodePacked(turn, nonce2, call2)));

        // every 18 hours all players need to reveal their respective move for that turn.
        vm.warp(block.timestamp + 19 hours);

        vm.prank(w1nt3r);
        game.reveal(turn, nonce1, call1);

        vm.prank(dhof);
        game.reveal(turn, nonce2, call2);
        
        // N.B. this should be done offchain IRL
        address[] memory sortedAddrs = new address[](2);
        sortedAddrs[0] = dhof;
        sortedAddrs[1] = w1nt3r;

        game.rollDice(turn);
        vrfCoordinator.fulfillRandomWords(
            game.vrf_requestId(),
            address(game)
        );
        
        game.resolve(turn, sortedAddrs);

        (,,,,,,uint256 hp_w1nt3r,,uint256 x_w1nt3r,uint256 y_w1nt3r,bytes32 pendingMoveCommitment_w1nt3r,) = game.players(w1nt3r);
        (,,,,,,uint256 hp_dhof,,uint256 x_dhof,uint256 y_dhof,bytes32 pendingMoveCommitment_dhof,) = game.players(dhof);

        require(x_w1nt3r == 0 && y_w1nt3r == 0, "W1nt3r should have remained in place from rest()");
        require(x_dhof == 3 && y_dhof == 0, "Dhof should have moved right one square from move(4)");
        require(hp_dhof == 1000, "W1nt3r should have recovered 2 hp from rest()");
        require(hp_w1nt3r == 1002, "Dhof should have same hp remaining as before from move()");
        require(pendingMoveCommitment_dhof == "" && pendingMoveCommitment_w1nt3r == "", "Pending move commitment for both should be cleared after resolution.");
    }
}
