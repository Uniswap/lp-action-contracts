// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'ds-test/test.sol';

import '../libraries/RemoveAndSwapDecoder.sol';

contract Decoder {
    using RemoveAndSwapDecoder for bytes;

    function decode(bytes calldata data) external pure returns (RemoveAndSwapDecoder.Params memory) {
        return data.decode();
    }
}

contract RemoveAndSwapDecoderTest is DSTest {
    Decoder decoder;

    function setUp() public {
        decoder = new Decoder();
    }

    function testDecode() public {
        uint256 deadline = 1;
        address recipient = address(1);
        uint256 amount0Min = 1;
        uint256 amount1Min = 1;
        bool swapToken0 = true;
        RemoveAndSwapDecoder.V2ExactInput[] memory v2ExactInputs = new RemoveAndSwapDecoder.V2ExactInput[](1);
        IERC20[] memory path = new IERC20[](1);
        path[0] = IERC20(address(1));
        v2ExactInputs[0] = RemoveAndSwapDecoder.V2ExactInput({
            amountInBips: 1,
            amountOutMin: 1,
            path: path,
            to: address(1)
        });
        RemoveAndSwapDecoder.V3ExactInputSingle[]
            memory v3ExactInputSingles = new RemoveAndSwapDecoder.V3ExactInputSingle[](1);
        v3ExactInputSingles[0] = RemoveAndSwapDecoder.V3ExactInputSingle({
            tokenIn: IERC20(address(1)),
            tokenOut: IERC20(address(1)),
            fee: 1,
            recipient: address(1),
            amountInBips: 1,
            amountOutMinimum: 1
        });
        RemoveAndSwapDecoder.V3ExactInput[] memory v3ExactInputs = new RemoveAndSwapDecoder.V3ExactInput[](1);
        v3ExactInputs[0] = RemoveAndSwapDecoder.V3ExactInput({
            path: hex'01',
            recipient: address(1),
            amountInBips: 1,
            amountOutMinimum: 1
        });
        bytes[] memory otherCalls = new bytes[](1);
        otherCalls[0] = hex'01';

        bytes memory data = abi.encode(
            RemoveAndSwapDecoder.Params({
                deadline: deadline,
                recipient: recipient,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                swapToken0: swapToken0,
                v2ExactInputs: v2ExactInputs,
                v3ExactInputSingles: v3ExactInputSingles,
                v3ExactInputs: v3ExactInputs,
                otherCalls: otherCalls
            })
        );

        RemoveAndSwapDecoder.Params memory params = decoder.decode(data);

        assertEq(params.deadline, deadline);
        assertEq(params.recipient, recipient);
        assertEq(params.amount0Min, amount0Min);
        assertEq(params.amount1Min, amount1Min);
        assertTrue(params.swapToken0);
        assertTrue(swapToken0);
        assertEq(keccak256(abi.encode(params.v2ExactInputs)), keccak256(abi.encode(v2ExactInputs)));
        assertEq(keccak256(abi.encode(params.v3ExactInputSingles)), keccak256(abi.encode(v3ExactInputSingles)));
        assertEq(keccak256(abi.encode(params.v3ExactInputs)), keccak256(abi.encode(v3ExactInputs)));
        assertEq(keccak256(abi.encode(params.otherCalls)), keccak256(abi.encode(otherCalls)));
    }
}
