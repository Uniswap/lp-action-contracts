// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {INonfungiblePositionManager} from '../interfaces/external/INonfungiblePositionManager.sol';
import {RemoveAndSwap} from '../RemoveAndSwap.sol';
import {RemoveAndSwapDecoder} from '../libraries/RemoveAndSwapDecoder.sol';

import {Test} from './utils/Test.sol';
import {UniswapV3FactoryFixture} from './fixtures/UniswapV3Factory.sol';
import {NonfungiblePositionManagerFixture} from './fixtures/NonfungiblePositionManager.sol';
import {SwapRouter02Fixture} from './fixtures/SwapRouter02.sol';
import {ERC20Fixture} from './fixtures/ERC20.sol';

contract RemoveAndSwapIntegration is Test, NonfungiblePositionManagerFixture, SwapRouter02Fixture, ERC20Fixture {
    ERC20 token0;
    ERC20 token1;
    RemoveAndSwap removeAndSwap;

    uint256 tokenId;

    function setUp() public override(Test, NonfungiblePositionManagerFixture, SwapRouter02Fixture) {
        UniswapV3FactoryFixture.setUp();
        NonfungiblePositionManagerFixture.setUp();
        SwapRouter02Fixture.setUp();

        removeAndSwap = new RemoveAndSwap(swapRouter, nonfungiblePositionManager);

        token0 = createToken(1_000_000e18);
        token1 = createToken(1_000_000e18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);

        nonfungiblePositionManager.createAndInitializePoolIfNecessary(address(token0), address(token1), 3000, 2**96);
        token0.approve(address(nonfungiblePositionManager), 1_000 * 2);
        token1.approve(address(nonfungiblePositionManager), 1_000 * 2);
        // we'll remove and swap this nft
        (tokenId, , , ) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 3000,
                tickLower: -60,
                tickUpper: 60,
                amount0Desired: 1_000,
                amount1Desired: 1_000,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max
            })
        );
        // ...and use this one just to ensure there's more liquidity to swap against
        nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: 3000,
                tickLower: -60,
                tickUpper: 60,
                amount0Desired: 1_000,
                amount1Desired: 1_000,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max
            })
        );
    }

    function testWorks() public {
        RemoveAndSwapDecoder.V3ExactInputSingle[]
            memory v3ExactInputSingles = new RemoveAndSwapDecoder.V3ExactInputSingle[](1);
        v3ExactInputSingles[0] = RemoveAndSwapDecoder.V3ExactInputSingle({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: 3000,
            recipient: address(this),
            amountInBips: 1e4,
            amountOutMinimum: 0
        });
        bytes[] memory otherCalls = new bytes[](0);

        uint256 token0BalanceBefore = token0.balanceOf(address(this));
        uint256 token1BalanceBefore = token1.balanceOf(address(this));

        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            address(removeAndSwap),
            tokenId,
            abi.encode(
                RemoveAndSwapDecoder.Params({
                    deadline: type(uint256).max,
                    recipient: address(this),
                    amount0Min: 0,
                    amount1Min: 0,
                    swapToken0: true,
                    swapEntireAmount: true,
                    v2ExactInputs: new RemoveAndSwapDecoder.V2ExactInput[](0),
                    v3ExactInputSingles: v3ExactInputSingles,
                    v3ExactInputs: new RemoveAndSwapDecoder.V3ExactInput[](0),
                    otherCalls: otherCalls
                })
            )
        );

        uint256 token0BalanceAfter = token0.balanceOf(address(this));
        uint256 token1BalanceAfter = token1.balanceOf(address(this));

        assertEq(token0BalanceAfter, token0BalanceBefore);
        assertEq(token1BalanceAfter, token1BalanceBefore + 999 + 993);
    }
}
