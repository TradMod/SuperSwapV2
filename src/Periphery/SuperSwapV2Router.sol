// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "../core/Interfaces/IERC20.sol";
import {SuperSwapV2Library} from "./libraries/SuperSwapV2Library.sol";
import {ISuperSwapV2Factory} from "./Interfaces/ISuperSwapV2Factory.sol";
import {ISuperSwapV2Pair} from "../core/./Interfaces/ISuperSwapV2Pair.sol";

contract SuperSwapV2Router {

    ISuperSwapV2Factory public factory;

    constructor(address _factory) {
        factory = ISuperSwapV2Factory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountAdesired,
        uint256 amountBdesired,
        uint256 amountAmin,
        uint256 amountBmin,
        address to
        ) public
        returns(
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity){

        if (factory.getPair(tokenA, tokenB) == address(0)){
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = calculateLiquidity(
            tokenA, 
            tokenB, 
            amountAdesired, 
            amountBdesired, 
            amountAmin, 
            amountBmin
        );

        address pair = SuperSwapV2Library.pairFor(address(factory), tokenA, tokenB);

        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = ISuperSwapV2Pair(pair).mint(to);
    }

    function removeLiquidity(
            address tokenA,
            address tokenB,
            uint256 liquidity,
            uint256 amountAmin,
            uint256 amountBmin,
            address to
        ) public {
        require(ISuperSwapV2Factory(factory).getPair(tokenA, tokenB) != address(0), "Tokens pair not exists");

        address pair = SuperSwapV2Library.pairFor(address(factory), tokenA, tokenB);
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amountA, uint256 amountB) = ISuperSwapV2Pair(pair).burn(to);

        require(amountA >= amountAmin && amountB >= amountBmin, "Insufficient Amounts");
    }

    function calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountAdesired,
        uint256 amountBdesired,
        uint256 amountAmin,
        uint256 amountBmin
        ) internal returns(uint256 amountA, uint256 amountB){
            (uint256 reserveA, uint256 reserveB) = SuperSwapV2Library.getReserves(address(factory), tokenA, tokenB);
            if(reserveA == 0 && reserveB == 0){
                (amountA, amountB) = (amountAdesired, amountBdesired);
            } else {
                uint256 amountBoptimal = SuperSwapV2Library.qoute(amountAdesired, reserveA, reserveB);
                if(amountBoptimal <= amountBdesired){
                    require(amountBoptimal > amountBmin, "Insufficient Amount");
                    (amountA, amountB) = (amountAdesired, amountBoptimal);
                } else {
                    uint256 amountAoptimal = SuperSwapV2Library.qoute(amountBdesired, reserveB, reserveA);
                    require(amountAoptimal <= amountAdesired);
                    require(amountAoptimal > amountAmin, "Insufficient Amount");
                    (amountA, amountB) = (amountAoptimal, amountBdesired);
                }
            }
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                to,
                value
            )
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Transfer Failed');
    }

}