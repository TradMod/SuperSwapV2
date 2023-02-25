// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {ISuperSwapV2Callee} from "./Interfaces/ISuperSwapV2Callee.sol";
import {SuperSwapV2} from "./SuperSwapV2.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "./Interfaces/IERC20.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";

contract SuperSwapV2Pair is SuperSwapV2 {
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    uint112 public reserveX;
    uint112 public reserveY;
    uint32 public lastBlockTimestamp;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    address public tokenX;
    address public tokenY;

    address public factory;

    bool private lock;

    modifier reentrancyLock {
        require(!lock, "Locked!");
        lock = true;
        _;
        lock = false;
    }

    error InvalidK();

    event Swap(address Swapper, uint256 AmountAout, uint256 AmountBout, address to);
    event Mint(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event Burn(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event ReservesUpdate(uint112 indexed ReserveX, uint112 indexed ReserveY, uint32 lastBlockTimestamp);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _tokenX, address _tokenY) public {
        require(msg.sender == factory, "Only Factory allowed");
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function mint(address to) public reentrancyLock returns(uint256){

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));

        uint256 amountX = balanceX - reserveX;
        uint256 amountY = balanceY - reserveY;

        uint256 liquidity;

        if(totalSupply == 0){
            liquidity = sqrt(amountX * amountY) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = min((amountX * totalSupply / reserveX), (amountY * totalSupply / reserveY));
        }

        require(liquidity > 0, "Insufficient Liquidity Minted");

        updateResrves(balanceX, balanceY);

        _mint(to, liquidity);

        emit Mint(to, liquidity);

        return liquidity;
    }

    function burn(address to) public reentrancyLock returns(uint256 amountX, uint256 amountY) {
        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];

        amountX = (balanceX * liquidity) / totalSupply;
        amountY = (balanceY * liquidity) / totalSupply;

        require(amountX > 0 && amountY > 0, "Insufficient Liquidity Burned");

        _burn(address(this), liquidity);

        _safeTransfer(tokenX, to, amountX);
        _safeTransfer(tokenY, to, amountY);

        balanceX = IERC20(tokenX).balanceOf(address(this));
        balanceY = IERC20(tokenY).balanceOf(address(this));
        
        updateResrves(balanceX, balanceY);

        emit Burn(to, liquidity);

        return (amountX, amountY);
    }


    function swap(uint256 amountXOut, uint256 amountYOut, address to, bytes calldata data ) public reentrancyLock {
        require(amountXOut > 0 && amountYOut > 0, "Insufficient OutputAmount");

        (uint112 reserveX_, uint112 reserveY_, ) = getReserves();

        require(amountXOut < reserveX_ && amountYOut < reserveY, "Insufficient Liquidity");

        if (amountXOut > 0) _safeTransfer(tokenX, to, amountXOut);
        if (amountYOut > 0) _safeTransfer(tokenY, to, amountYOut);
        if (data.length > 0) ISuperSwapV2Callee(to).superSwapV2Call(msg.sender, amountXOut, amountYOut, data );

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));

        uint256 amountXIn = balanceX > reserveX - amountXOut ? balanceX - (reserveX - amountXOut) : 0;
        uint256 amountYIn = balanceY > reserveY - amountYOut ? balanceY - (reserveY - amountYOut) : 0;

        require(amountXIn > 0 && amountYIn > 0, "InsufficientInputAmount");

        uint256 balanceXAdjusted = (balanceX * 1000) - (amountXIn * 5);
        uint256 balanceYAdjusted = (balanceY * 1000) - (amountYIn * 5);

        if (balanceXAdjusted * balanceYAdjusted < uint256(reserveX_) * uint256(reserveY_) * (1000**2) ) revert InvalidK();

        updateResrves(balanceX, balanceY);

        emit Swap(msg.sender, amountXOut, amountYOut, to);
    }

    function calculate(uint256 inputAmountA, uint256 reserveA, uint256 reserveB) internal pure returns(uint256 outputAmountB){
        uint256 numerator = reserveB * inputAmountA;
        uint256 denominator = reserveA + inputAmountA;
        return numerator / denominator;
    } 

    function updateResrves(
        uint256 balanceX,
        uint256 balanceY
    ) private {
        require(balanceX <= type(uint112).max && balanceY <= type(uint112).max, "Balance Overflow");

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - lastBlockTimestamp;

            if (timeElapsed > 0 && reserveX > 0 && reserveY > 0) {
                price0CumulativeLast +=
                    uint256(UQ112x112.encode(reserveY).uqdiv(reserveX)) *
                    timeElapsed;
                price1CumulativeLast +=
                    uint256(UQ112x112.encode(reserveX).uqdiv(reserveY)) *
                    timeElapsed;
            }
        }

        reserveX = uint112(balanceX);
        reserveY = uint112(balanceY);
        lastBlockTimestamp = uint32(block.timestamp);

        emit ReservesUpdate(reserveX, reserveY, uint32(block.timestamp));
    }

    function getReserves() public view returns(uint112, uint112, uint32){
        return (reserveX, reserveY, lastBlockTimestamp);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(
          abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Transfer Failed');
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

}