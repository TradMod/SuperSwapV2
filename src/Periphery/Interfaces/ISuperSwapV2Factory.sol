// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface ISuperSwapV2Factory {
    function createPair(address, address) external;

    function getPair(address, address) external view returns(address);

    function totalPairs() external view returns(uint256);
}