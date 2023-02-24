// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {SuperSwapV2Pair} from "./SuperSwapV2Pair.sol";
import {ISuperSwapV2Pair} from "./Interfaces/ISuperSwapV2Pair.sol";

contract SuperSwapV2Factory {

    address[] public allPairs;
    mapping(address => mapping (address => address)) public pairs;

    event PairCreated(address indexed TokenA, address indexed TokenB, address indexed Pair);

    constructor() {}

    function createPair(address tokenA, address tokenB) public {
        require(tokenA == address(0) && tokenB == address(0), "Address Zero");
        require(tokenA != tokenB, "Identical Tokens Address");

        (address tokenX, address tokenY) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(pairs[tokenX][tokenY] == address(0), "Pair already exists");

        address pair;

        bytes memory bytecode = type(SuperSwapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenX, tokenY));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        ISuperSwapV2Pair(pair).initialize(tokenX, tokenY);

        pairs[tokenX][tokenY] = pair;
        pairs[tokenY][tokenX] = pair;
        allPairs.push(pair);

        emit PairCreated(tokenX, tokenY, pair);
    }

    function getPair(address tokenA, address tokenB) public view returns(address){
        return pairs[tokenA][tokenB];
    }

    function totalPairs() public view returns(uint256){
        return allPairs.length;
    }

}