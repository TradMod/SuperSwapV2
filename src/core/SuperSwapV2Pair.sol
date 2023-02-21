// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "./Libraries/Math.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "./Interfaces/IERC20.sol";

contract SuperSwapV2Pair is ERC20, Math {

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    uint256 public reserveX;
    uint256 public reserveY;

    address public tokenX;
    address public tokenY;

    event Mint(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event Burn(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event ReservesUpdate(uint256 indexed reserveX, uint256 indexed reserveY);

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
            liquidity = Math.sqrt(amountX * amountY) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amountX * totalSupply / reserveX), (amountY * totalSupply / reserveY));
        }

        require(liquidity > 0, "Insufficient Liquidity Minted");

        updateResrves(balanceX, balanceY);

        _mint(msg.sender, liquidity);

        emit Mint(msg.sender, liquidity);
    }

    function burn() public {
        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];

        uint256 amountX = (balanceX * liquidity) / totalSupply;
        uint256 amountY = (balanceY * liquidity) / totalSupply;

        require(amountX > 0 && amountY > 0, "Insufficient Liquidity Burned");

        _burn(msg.sender, liquidity);

        IERC20(tokenX).transfer(msg.sender, amountX);
        IERC20(tokenY).transfer(msg.sender, amountY);

        balanceX = IERC20(tokenX).balanceOf(address(this));
        balanceY = IERC20(tokenY).balanceOf(address(this));
        
        updateResrves(balanceX, balanceY);

        emit Burn(msg.sender, liquidity);
    }

    function updateResrves(uint256 _balanceX, uint256 _balanceY) private {
        reserveX = _balanceX;
        reserveY = _balanceY;

        emit ReservesUpdate(reserveX, reserveY);
    }

    function getReserves() public view returns(uint256, uint256){
        return (reserveX, reserveY);
    }

}