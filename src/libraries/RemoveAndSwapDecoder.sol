// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

library RemoveAndSwapDecoder {
    struct V2ExactInput {
        // percentage of the input allocated to this swap, in bips
        uint256 amountInBips;
        // swap params
        uint256 amountOutMin;
        address[] path;
        address to;
    }

    struct V3ExactInputSingle {
        // percentage of the input allocated to this swap, in bips
        uint256 amountInBips;
        // swap params
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOutMinimum;
    }

    struct V3ExactInput {
        // percentage of the input allocated to this swap, in bips
        uint256 amountInBips;
        // swap params
        bytes path;
        address recipient;
        uint256 amountOutMinimum;
    }

    struct Params {
        // parameters relevant to the entire remove + swap
        uint256 deadline;
        address recipient;
        // parameters relevant to the remove portion
        uint256 amount0Min;
        uint256 amount1Min;
        // parameters relevant to the swap portion
        bool swapToken0;
        bool swapEntireAmount;
        V2ExactInput[] v2ExactInputs;
        V3ExactInputSingle[] v3ExactInputSingles;
        V3ExactInput[] v3ExactInputs;
        bytes[] otherCalls;
    }

    function decode(bytes calldata data) internal pure returns (Params memory) {
        return abi.decode(data, (Params));
    }
}
