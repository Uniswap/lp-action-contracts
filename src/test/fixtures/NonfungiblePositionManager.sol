// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {INonfungiblePositionManager} from '../../interfaces/external/INonfungiblePositionManager.sol';

import {UniswapV3FactoryFixture} from './UniswapV3Factory.sol';
import {NonfungiblePositionManager} from '../utils/Constants.sol';
import {Test} from '../utils/Test.sol';

abstract contract NonfungiblePositionManagerFixture is UniswapV3FactoryFixture, Test {
    INonfungiblePositionManager internal nonfungiblePositionManager;

    function setUp() public virtual override(UniswapV3FactoryFixture, Test) {
        bytes memory creationCodeWithConstructorArguments = bytes.concat(
            NonfungiblePositionManager,
            abi.encode(
                address(factory),
                address(0), // _WETH9 not required
                address(0) // _tokenDescriptor_ not required
            )
        );
        address nonfungiblePositionManagerAddress;
        assembly {
            nonfungiblePositionManagerAddress := create(
                0,
                add(creationCodeWithConstructorArguments, 32),
                mload(creationCodeWithConstructorArguments)
            )

            if iszero(nonfungiblePositionManagerAddress) {
                revert(0, 0)
            }
        }
        nonfungiblePositionManager = INonfungiblePositionManager(nonfungiblePositionManagerAddress);
    }

    function testNonfungiblePositionManagerFactory() public {
        assertEq(nonfungiblePositionManager.factory(), address(factory));
    }
}
