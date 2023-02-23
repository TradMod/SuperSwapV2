// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

    bool private lock;

    modifier reentrancyLock {
        require(!lock, "Locked!");
        lock = true;
        _;
        lock = false;
    }

    event Swap(address Swapper, uint256 AmountAout, uint256 AmountBout);
    event Mint(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event Burn(address indexed LiquidityProvider, uint256 indexed Liquidity);
    event ReservesUpdate(uint112 indexed ReserveX, uint112 indexed ReserveY, uint32 lastBlockTimestamp);

    constructor(address _tokenX, address _tokenY) {
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function mint() public reentrancyLock {

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

        _mint(msg.sender, liquidity);

        emit Mint(msg.sender, liquidity);
    }

    function burn(address to) public reentrancyLock {
        uint256 balanceX = IERC20(tokenX).balanceOf(address(this));
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this));
        uint256 liquidity = balanceOf[msg.sender];

        uint256 amountX = (balanceX * liquidity) / totalSupply;
        uint256 amountY = (balanceY * liquidity) / totalSupply;

        require(amountX > 0 && amountY > 0, "Insufficient Liquidity Burned");

        _burn(address(this), liquidity);

        _safeTransfer(tokenX, to, amountX);
        _safeTransfer(tokenY, to, amountY);

        balanceX = IERC20(tokenX).balanceOf(address(this));
        balanceY = IERC20(tokenY).balanceOf(address(this));
        
        updateResrves(balanceX, balanceY);

        emit Burn(to, liquidity);
    }

    function swap(address to, uint256 amountAout, uint256 amountBout) public reentrancyLock {
        require(amountAout > 0 || amountBout > 0, "Insufficient amount inputs");
        require(amountAout < reserveX || amountBout < reserveY, "Insufficient Liquidity");

        uint256 balanceX = IERC20(tokenX).balanceOf(address(this)) - amountAout;
        uint256 balanceY = IERC20(tokenY).balanceOf(address(this)) - amountBout;

        require(balanceX * balanceY > reserveX * reserveY, "!K: No Tokens sent");

        updateResrves(balanceX, balanceY);

        if (amountAout > 0) _safeTransfer(tokenX, to, amountAout);
        if (amountBout > 0) _safeTransfer(tokenY, to, amountBout);

        emit Swap(to, amountAout, amountBout);
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

    function getReserves() public view returns(uint112, uint112){
        return (reserveX, reserveY);
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