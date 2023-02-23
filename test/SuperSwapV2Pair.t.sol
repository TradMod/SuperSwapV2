// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./mocks/MockERC20.sol";
import "../src/core/SuperSwapV2Pair.sol";

contract SuperSwapV2PairTest is Test {

    MockERC20 public tokenX;
    MockERC20 public tokenY;
    SuperSwapV2Pair public pair;
    
    function setUp() public {
        tokenX = new MockERC20("TokenX", "TX");
        tokenY = new MockERC20("TokenY", "TY");
        pair = new SuperSwapV2Pair(address(tokenX), address(tokenY));

        tokenX.mint(address(this), 10 ether);
        tokenY.mint(address(this), 10 ether);
    }

    function assertReserves(uint256 expectedReserveX, uint256 expectedReserveY)
        internal
    {
        (uint256 reserveX, uint256 reserveY) = pair.getReserves();
        assertEq(reserveX, expectedReserveX, "unexpected reserveX");
        assertEq(reserveY, expectedReserveY, "unexpected reserveY");
    }

    function testMint() public {
        tokenX.transfer(address(pair), 1 ether);
        tokenY.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWithLiquidity() public {
        tokenX.transfer(address(pair), 1 ether);
        tokenY.transfer(address(pair), 1 ether);

        pair.mint(); // +1

        tokenX.transfer(address(pair), 2 ether);
        tokenY.transfer(address(pair), 2 ether);

        pair.mint(); // +2

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
    }

    function testMintWithUnbalancedLiquidity() public {
        tokenX.transfer(address(pair), 1 ether);
        tokenY.transfer(address(pair), 1 ether);

        pair.mint(); // +1

        tokenX.transfer(address(pair), 2 ether);
        tokenY.transfer(address(pair), 1 ether);

        pair.mint(); // +2

        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
        assertEq(pair.totalSupply(), 2 ether);
    }

    function testFailZeroLiquidity() public {
        tokenX.transfer(address(pair), 1000);
        tokenY.transfer(address(pair), 1000);
        
        pair.mint();

        vm.expectRevert("Insufficient Liquidity Minted");
    }

    function testBurn() public {
        testMint(); // +1

        pair.burn(); // -1
        assertEq(pair.balanceOf(address(this)), 0);
    }

    function testFailBurn() public {
        vm.expectRevert("Insufficient Liquidity Burned");
    }

}
