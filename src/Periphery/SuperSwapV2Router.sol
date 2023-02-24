// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SuperSwapV2Library} from "./libraries/SuperSwapV2Library.sol";
import {ISuperSwapV2Factory} from "./Interfaces/ISuperSwapV2Factory.sol";

contract SuperSwapV2Router {

    ISuperSwapV2Factory public factory;

    constructor(address _factory) {
        factory = ISuperSwapV2Factory(_factory);
    }

}