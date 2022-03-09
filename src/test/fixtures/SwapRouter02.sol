// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ISwapRouter02} from '../../interfaces/external/ISwapRouter02.sol';

import {UniswapV3FactoryFixture} from './UniswapV3Factory.sol';
import {SwapRouter02} from '../utils/Constants.sol';
import {Test} from '../utils/Test.sol';

abstract contract SwapRouter02Fixture is UniswapV3FactoryFixture, Test {
    ISwapRouter02 internal swapRouter;

    function setUp() public virtual override(UniswapV3FactoryFixture, Test) {
        bytes memory creationCodeWithConstructorArguments = bytes.concat(
            SwapRouter02,
            abi.encode(
                address(0), // _factoryV2 not required
                address(factory),
                address(0), // _positionManager not required
                address(0) // _WETH9 not required
            )
        );
        address swapRouterAddress;
        assembly {
            swapRouterAddress := create(
                0,
                add(creationCodeWithConstructorArguments, 32),
                mload(creationCodeWithConstructorArguments)
            )

            if iszero(swapRouterAddress) {
                revert(0, 0)
            }
        }
        swapRouter = ISwapRouter02(swapRouterAddress);
    }

    function testSwapRouter02Factory() public {
        assertEq(swapRouter.factory(), address(factory));
    }
}
