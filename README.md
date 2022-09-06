Inspired by https://twitter.com/dhof/status/1566823568616333316

Code provided as-is, not audited, not even fully functional. Still work-in-progress. Use at your own risk.

CC0 - do whatever you want with the source code.

[Install Foundry](https://book.getfoundry.sh/getting-started/installation) to run the tests.

Made by [@w1nt3r_eth](https://twitter.com/w1nt3r_eth)

## Specs

#### Participating

- 1 NFT = 1 Player
- Pay entry free to create player. Entry fee goes to the player's "spoils," and ETH Balance attached to your player. Game takes nothing.
- If you defeat a player, you win all their accumulated spoils. If you are defeated, you lose all your spoils.
- Spils cannot be withdrawn till end of game

#### Turns

- Turn based, 1 turn every 36 hours (**editor's commment**: 36 hours eh? seems not very engaging...also a game gonna take fucking forever...also will need notifications so 90% of players don't just disappear after a couple moves)
  - Submit stage (18 hours): Make your move and submit a hash of it to initiall hide from other players
  - Reveal stage (18 hours); Submit plaintext version of your move and its password to reveal it
    - If you don't rewveal your move you are penalized heavily (TBD what is the penalty, needs to outweigh not revealing move)
  - Resolution (instant-ish): All moves are process, and next submit stage begins

#### Moving

- Players are initially spawned on 2D grid map in random starting spots. All starting spots are equidistant from one another.
- You can initall [MOVE] to one adjacent grid spot per turn. You can also [REST] in the grid spot you currently occupy.
- Grid spots can reveal two things the firs time they are encountered:
  - **Resources** which are picked up immediately and can be used to level up and train the character
  - **Effects** which are either continuous (Passive AOE), or triggered (provies additional [ABILITY] that can be used during a turn).
- Once a grid spot is revealed it is revealed to all players

#### Battles

- When 2 players occupy the same grid slot, a battle occurs. Battles are resolved by a series of calculations (simple comparison of stats like att/def/HP/etc. with rock-paper-sissors specialization) along with a dice roll.
- Losing player is removed from map, permanently loses spoils to the winner
- If more than 2 on same grid slot, random 2 are chosen for battle. (**editor's comment**: possibly multiples of 2 can be chosen and the lucky(?) odd one sits out)

#### Alliances

- Players can choose to form alliances or apply to alliances.
- The player who forms the alliances is the **leader** and has sole rights over accepting or ignoring applications. (**editor's comment**: might be an interesting place to attach a mini-dao like structure to vote in / kick members)
- Players in an alliance will not attack each other then occupying the same slot.
- If an alliance wins, all of the spoils between the players in the alliance are split evenly (**editors'comment**: are battles fought with a representative of the alliance or the cumulative stats of the alliance?)
- Players can only be in 1 alliance
- Alliances have a max membership count (TBD, based on intended total number of players)
- N.B. Pseudo "superalliances" can still be formed outside of the game through social contracts or smart contracts. But cannot guarantee there won't be betrayals. (**editor's comment** Strategic/Tactical betrayal is a fun component of any good strategy game :D)

#### Win Condition

- Last player/alliance standing
- At this point the winers may withdraw their spoils
- (**editor's comment**: In order to add more chaos and tact in choosing your allies, if an alliance is the last standing, they could anonymously vote to continue as FFA, or be satisfied with splitting the spoils.)

#### Miscellaneous

- Every 5 turns (a little over a week), the play field is reduced in size (Battle Royale/Fortnite,Warzone, etc.) to force more battles over time and push towards a win.
