// SPDX-License-Identifier: CC0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/v0.8/VRFConsumerBaseV2.sol";

import "./Loot.sol";

struct Player {
    // TODO: Pack this struct once we know all the fields
    address addr;
    address nftAddress;
    uint256 balance;
    uint256 tokenId;
    uint256 lastMoveTimestamp;
    uint256 allianceId;
    uint256 hp;
    uint256 attack;
    uint256 x;
    uint256 y;
    bytes32 pendingMoveCommitment;
    bytes pendingMove;
}

contract DomStrategyGame is IERC721Receiver, VRFConsumerBaseV2 {
    Loot public loot;
    mapping(address => Player) players;
    mapping(uint256 => address) allianceAdmins;
    mapping(address => uint256) public spoils;

    // bring your own NFT kinda
    // BAYC, Sappy Seal, Pudgy Penguins, Azuki, Doodles
    // address[] allowedNFTs = [
    //     0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D, 0x364C828eE171616a39897688A831c2499aD972ec, 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8, 0xED5AF388653567Af2F388E6224dC7C4b3241C544, 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e
    // ];

    uint256 public currentTurn;
    uint256 public currentTurnStartTimestamp;
    uint256 public activePlayers;
    uint256 public randomness;
    uint256 public randomnessRequestId;
    uint256 public fieldSize;

    event Joined(address indexed addr);
    event TurnStarted(uint256 indexed turn, uint256 timestamp);
    event Submitted(
        address indexed addr,
        uint256 indexed turn,
        bytes32 commitment
    );
    event Revealed(
        address indexed addr,
        uint256 indexed turn,
        bytes32 nonce,
        bytes data
    );
    event BadMovePenalty(
        uint256 indexed turn,
        address indexed player,
        bytes details
    );

    event AllianceCreated(
        address indexed admin,
        uint256 indexed allianceId,
        string name
    );
    event AllianceMemberJoined(
        uint256 indexed allianceId,
        address indexed player
    );
    event AllianceMemberLeft(
        uint256 indexed allianceId,
        address indexed player
    );

    constructor(Loot _loot)
        // TODO: Take Chainlink address in constructor
        VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D)
    {
        loot = _loot;
        fieldSize = 100;
    }

    function connect(uint256 tokenId, address byoNft) external payable {
        require(currentTurn == 0, "Already started");
        require(players[msg.sender].balance == 0, "Already joined");
        require(msg.value > 0, "Send some eth");

        // prove ownership of one of the NFTs in the allowList
        uint256 nftBalance = IERC721(byoNft).balanceOf(msg.sender);
        require(nftBalance > 0, "You dont own this NFT you liar");

        IERC721(byoNft).safeTransferFrom(msg.sender, address(this), tokenId, "");

        Player memory player = Player({
            addr: msg.sender,
            nftAddress: byoNft == address(0) ? address(loot) : byoNft,
            balance: msg.value,
            tokenId: tokenId,
            lastMoveTimestamp: block.timestamp,
            allianceId: 0,
            hp: 1000,
            attack: 10,
            x: 0,
            y: 0,
            pendingMoveCommitment: bytes32(0),
            pendingMove: ""
        });
        spoils[msg.sender] = msg.value;
        players[msg.sender] = player;
        activePlayers += 1;

        emit Joined(msg.sender);
    }
    // TODO: Somebody needs to call this, maybe make this a Keeper managed Cron job?
    function start() external {
        require(currentTurn == 0, "Already started");
        require(activePlayers > 1, "No players");

        currentTurn = 1;
        currentTurnStartTimestamp = block.timestamp;

        emit TurnStarted(currentTurn, currentTurnStartTimestamp);
    }

    function submit(uint256 turn, bytes32 commitment) external {
        require(currentTurn > 0, "Not started");
        require(turn == currentTurn, "Stale tx");
        require(block.timestamp <= currentTurnStartTimestamp + 18 hours);

        players[msg.sender].pendingMoveCommitment = commitment;

        emit Submitted(msg.sender, currentTurn, commitment);
    }

    function reveal(
        uint256 turn,
        bytes32 nonce,
        bytes calldata data
    ) external {
        require(turn == currentTurn, "Stale tx");
        require(block.timestamp > currentTurnStartTimestamp + 18 hours);
        require(block.timestamp < currentTurnStartTimestamp + 36 hours);

        bytes32 commitment = players[msg.sender].pendingMoveCommitment;
        bytes32 proof = keccak256(abi.encodePacked(turn, nonce, data));
        require(commitment == proof, "No cheating");

        players[msg.sender].pendingMove = data;

        emit Revealed(msg.sender, currentTurn, nonce, data);
    }

    function rollDice(uint256 turn) external {
        require(turn == currentTurn, "Stale tx");
        require(randomness == 0, "Already rolled");
        require(randomnessRequestId == 0, "Already rolling");
        require(block.timestamp > currentTurnStartTimestamp + 36 hours);

        randomnessRequestId = VRFCoordinatorV2Interface(
            0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
        ).requestRandomWords(
                0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15,
                1,
                3,
                40_000,
                1
            );
    }

    // The turns are processed in random order. The contract offloads sorting the players
    // list off-chain to save gas
    function resolve(uint256 turn, address[] calldata sortedAddrs) external {
        require(turn == currentTurn, "Stale tx");
        require(randomness != 0, "Roll the die first");
        require(sortedAddrs.length == activePlayers, "Not enough players");
        require(block.timestamp > currentTurnStartTimestamp + 36 hours);

        if (turn % 5 == 0) {
            fieldSize -= 1;
        }

        bytes32 lastHash = 0;
        // TODO: this will exceed block gas limit eventually, need to split `resolve`
        // in a way that it can be called incrementally
        for (uint256 i; i < sortedAddrs.length; i++) {
            address addr = sortedAddrs[i];
            Player storage player = players[addr];

            bytes32 currentHash = keccak256(abi.encodePacked(addr, randomness));
            require(currentHash > lastHash, "Not sorted");
            lastHash = currentHash;

            (bool success, bytes memory err) = address(this).call(
                abi.encodePacked(addr, player.pendingMove)
            );

            if (!success) {
                // Player submitted a bad move
                player.balance -= 0.05 ether;
                emit BadMovePenalty(turn, addr, err);
            }

            // Outside the field, apply storm damage
            if (player.x > fieldSize || player.y > fieldSize) {
                // TODO: Check for underflow, emit event
                player.hp -= 10;
            }
        }

        randomness = 0;
        currentTurn += 1;
        currentTurnStartTimestamp = block.timestamp;

        emit TurnStarted(currentTurn, currentTurnStartTimestamp);
    }

    // Possible game moves

    function move(address player, int8 direction) public {
        require(msg.sender == address(this), "Only via submit/reveal");
        // Change x & y depending on direction
    }

    function rest(address player) public {
        require(msg.sender == address(this), "Only via submit/reveal");
        players[player].hp += 2;
    }

    function createAlliance(address player, string calldata name) public {
        require(msg.sender == address(this), "Only via submit/reveal");
        require(players[player].allianceId == 0, "Already in alliance");
        uint256 allianceId = uint256(keccak256(abi.encodePacked(name)));

        players[player].allianceId = allianceId;
        allianceAdmins[allianceId] = player;

        emit AllianceCreated(player, allianceId, name);
    }

    function joinAlliance(
        address player,
        uint256 allianceId,
        bytes calldata signature
    ) public {
        require(msg.sender == address(this), "Only via submit/reveal");

        // Admin must sign the application off-chain. Applications are per-move based, so the player
        // can't reuse the application from the previous move
        bytes memory application = abi.encodePacked(currentTurn, allianceId);
        bytes32 hash = ECDSA.toEthSignedMessageHash(keccak256(application));
        address admin = ECDSA.recover(hash, signature);

        require(allianceAdmins[allianceId] == admin, "Not signed by admin");
        players[player].allianceId = allianceId;

        emit AllianceMemberJoined(players[player].allianceId, player);
    }

    function leaveAlliance(address player) public {
        require(msg.sender == address(this), "Only via submit/reveal");
        require(players[player].allianceId != 0, "Not in alliance");

        uint256 allianceId = players[player].allianceId;
        players[player].allianceId = 0;

        emit AllianceMemberLeft(allianceId, player);
    }

    // Callbacks

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        require(randomnessRequestId == requestId);

        randomness = randomWords[0];
        randomnessRequestId = 0;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external view returns (bytes4) {
        // require(msg.sender == address(loot) || msg.sender == address(bayc));
        return IERC721Receiver.onERC721Received.selector;
    }
}
