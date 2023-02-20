// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "solmate/tokens/ERC20.sol";
import "./Interfaces/IERC20.sol";

contract SuperSwapV2Pair is ERC20 {
    
    uint256 public reserveX;
    uint256 public reserveY;

    address public tokenX;
    address public tokenY;

    event Mint(
        address LiquidityProvider,
        uint256 Liquidity
    );

    constructor(address _tokenX, address _tokenY) ERC20("SuperSwapV2", "SUPER 2.0", 18) {
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function mint() public {

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));

        uint256 amountX = balanceX - reserveX;
        uint256 amountY = balanceY - reserveY;

        uint256 liquidity;

        if(totalSupply == 0){
            liquidity = amountX * amountY / 2;
        } else {
            liquidity = 5;
        }

        _mint(msg.sender, liquidity);

        emit Mint(msg.sender, liquidity);
    }

}