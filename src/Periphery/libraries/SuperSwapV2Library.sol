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