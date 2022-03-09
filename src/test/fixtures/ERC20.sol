// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor(uint256 totalSupply) ERC20('TestERC20', 'TEST') {
        _mint(msg.sender, totalSupply);
    }
}

abstract contract ERC20Fixture {
    function createToken(uint256 totalSupply) internal returns (ERC20) {
        return new TestERC20(totalSupply);
    }
}
