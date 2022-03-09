// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {UniswapV3Factory} from '../utils/Constants.sol';
import {ITest} from '../utils/Test.sol';

abstract contract UniswapV3FactoryFixture is ITest {
    IUniswapV3Factory internal factory;

    function setUp() public virtual {
        bytes memory creationCode = UniswapV3Factory;
        address factoryAddress;
        assembly {
            factoryAddress := create(0, add(creationCode, 32), mload(creationCode))

            if iszero(factoryAddress) {
                revert(0, 0)
            }
        }
        factory = IUniswapV3Factory(factoryAddress);
    }
}
