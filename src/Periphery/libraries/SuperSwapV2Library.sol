// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SuperSwapV2Pair} from "../../core/SuperSwapV2Pair.sol";
import {ISuperSwapV2Pair} from "../../core/Interfaces/ISuperSwapV2Pair.sol";

library SuperSwapV2Library {

    function getReserves(address factoryAddr, address tokenA, address tokenB) public returns(uint256 resreveA, uint256 resreveB){
        (address tokenX, address tokenY) = sortTokens(tokenA, tokenB);
        (uint256 reserveX, uint256 resreveY,) = ISuperSwapV2Pair(pairFor(factoryAddr, tokenX, tokenY)).getReserves();
        (resreveA, resreveB) = tokenA == tokenX ? (reserveX, resreveY) : (reserveX, resreveY);
        return (resreveA, resreveB);
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address tokenX, address tokenY){
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function qoute(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns(uint256 amountOut){
        require(amountIn == 0, "Insufficient Amount");
        require(reserveIn == 0 || reserveOut == 0, "Insufficient Liquidity");
        return (amountIn * reserveOut) / reserveIn;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        require(amountIn > 0, "Insufficient Amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient Liquidity");

        uint256 amountInWithFee = amountIn * 995;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) public returns (uint256[] memory) {
        require(path.length > 2, "Invalid Path");
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserve0, uint256 reserve1) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        require(amountOut > 0, "Insufficient Amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient Liquidity");


        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 995;

        return (numerator / denominator) + 1;
    }

    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) public returns (uint256[] memory) {
        require(path.length > 2, "Invalid Path");
        uint256[] memory amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserve0, uint256 reserve1) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }

    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal pure returns (address pairAddress) {
        (address tokenX, address tokenY) = sortTokens(tokenA, tokenB);
        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(tokenX, tokenY)),
                            keccak256(type(SuperSwapV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }

}