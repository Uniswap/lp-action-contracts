// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library RemoveAndSwapDecoder {
    struct V2ExactInput {
        uint256 amountInBips;
        uint256 amountOutMin;
        IERC20[] path;
        address to;
    }

    struct V3ExactInputSingle {
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountInBips;
        uint256 amountOutMinimum;
    }

    struct V3ExactInput {
        bytes path;
        address recipient;
        uint256 amountInBips;
        uint256 amountOutMinimum;
    }

    struct Params {
        // parameters relevant to the action as a whole
        uint256 deadline;
        address recipient;
        // parameters relevant to decreaseLiquidity
        uint256 amount0Min;
        uint256 amount1Min;
        // parameters relevant to swaps
        bool swapToken0;
        V2ExactInput[] v2ExactInputs;
        V3ExactInputSingle[] v3ExactInputSingles;
        V3ExactInput[] v3ExactInputs;
        bytes[] otherCalls;
    }

    function decode(bytes calldata data) internal pure returns (Params memory) {
        return abi.decode(data, (Params));
    }
}
