Inspired by https://twitter.com/dhof/status/1566823568616333316

Code provided as-is, not audited, not even fully functional. Still work-in-progress. Use at your own risk.

CC0 - do whatever you want with the source code.

[Install Foundry](https://book.getfoundry.sh/getting-started/installation) to run the tests.

Made by [@w1nt3r_eth](https://twitter.com/w1nt3r_eth)

How it works (so far):

- Players join the game by staking the access pass NFT
- After enough joined, the game can be started
- During the first 18 hours players submit hashes of their moves, it's recorded on chain
- During the next 18 hours players submit their moves:
  - A move is ABI encoded call into one of the available functions
  - Each move needs a random nonce to avoid opponents guessing what the move is
  - The hash of the (nonce, move) needs to match the commitment
- After 36 hours since the turn begin, the order of moves is determined:
  - A dice is rolled to get a random number (Chainlink)
  - An off-chain agent hashes each player's address with the random number and sorts the hashes (off-chain to save gas)
- Processing moves
  - Reduces the size of the field if needed
  - Goes over each player's move, calls the inner function
  - Each function can change player's state
  - Joining an alliance is implemented via the alliance leader signing an off-chain message

Next steps:

- Figure out how to store the map
  - Need a gas efficient way of knowing who's occupying the same tile
    - Start a fight between players
  - Spawning resources and initial player locations (could use VRF for this as well)
- Implement basic upgrades
- Ending the game
  - Return staked NFT
  - Distribute loot between the winners
