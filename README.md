# amulet-contracts

[![Build Status](https://travis-ci.com/chentschel/amulet-contracts.svg?branch=master)](https://travis-ci.com/chentschel/amulet-contracts)

ERC721 Amulet based on forged CryptoKitties genes.

## Game

The game revolves around the [`AmuletToken`](https://github.com/chentschel/amulet-contracts/blob/master/contracts/AmuletToken.sol) contract.

`AmuletToken` allows the forge of several amount of CryptoKitties into a new Amulet, that get its power value based on the different kitties genes forged.

The `AmuletToken`s themselves are ERC721 tokens, and can therefore be freely traded.

## Dependencies
- [npm](https://www.npmjs.com/): v5.8.0.
- [zos](https://www.npmjs.com/package/zos): v1.0.0
You can check if the dependencies are installed correctly by running the following command:

```
$ npm --version
5.8.0
$ zos --version
1.0.0
```

## Build and Test
After installing the dependencies previously mentioned, clone the project repository and enter the root directory:

```
$ git clone git@github.com:chentschel/amulet-contracts.git
$ cd amulet-contracts
```

Next, build the project dependencies:

`$ npm install`

To make sure everything is set up correctly, the tests should be run:

`$ npm run test`