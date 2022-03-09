// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {INonfungiblePositionManager} from '../interfaces/external/INonfungiblePositionManager.sol';

import {Test} from './utils/Test.sol';
import {UniswapV3FactoryFixture} from './fixtures/UniswapV3Factory.sol';
import {NonfungiblePositionManagerFixture} from './fixtures/NonfungiblePositionManager.sol';
import {ERC20Fixture} from './fixtures/ERC20.sol';

contract RemoveAndSwapIntegration is Test, NonfungiblePositionManagerFixture, ERC20Fixture {
    ERC20 token0;
    ERC20 token1;

    function setUp() public override(Test, NonfungiblePositionManagerFixture) {
        NonfungiblePositionManagerFixture.setUp();

        token0 = createToken(1_000_000e18);
        token1 = createToken(1_000_000e18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);

        nonfungiblePositionManager.createAndInitializePoolIfNecessary(address(token0), address(token1), 3000, 2**96);
        token0.approve(address(nonfungiblePositionManager), 1_000);
        token1.approve(address(nonfungiblePositionManager), 1_000);
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
}
