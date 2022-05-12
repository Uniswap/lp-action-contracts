// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {ISwapRouter02} from './interfaces/external/ISwapRouter02.sol';
import {INonfungiblePositionManager} from './interfaces/external/INonfungiblePositionManager.sol';

import {SafeApprove} from './libraries/SafeApprove.sol';
import {SafeTransfer} from './libraries/SafeTransfer.sol';
import {RemoveAndSwapDecoder} from './libraries/RemoveAndSwapDecoder.sol';

contract RemoveAndSwap is IERC721Receiver {
    using SafeApprove for IERC20;
    using SafeTransfer for IERC20;
    using RemoveAndSwapDecoder for bytes;

    error UnsupportedNFT(address caller);

    ISwapRouter02 immutable swapRouter;
    INonfungiblePositionManager immutable nonfungiblePositionManager;

    constructor(ISwapRouter02 _swapRouter, INonfungiblePositionManager _nonfungiblePositionManager) {
        swapRouter = _swapRouter;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    /// @dev The liquidity of the token must be greater than 0.
    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        if (msg.sender != address(nonfungiblePositionManager)) revert UnsupportedNFT(msg.sender);

        (, , address token0, address token1, , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(
            tokenId
        );

        RemoveAndSwapDecoder.Params memory params = data.decode();

        bytes[] memory nonfungiblePositionManagerData = new bytes[](3);

        // encode decreaseLiquidity
        nonfungiblePositionManagerData[0] = abi.encodeCall(
            nonfungiblePositionManager.decreaseLiquidity,
            (
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity, // call will fail if liquidity is 0
                    amount0Min: params.amount0Min,
                    amount1Min: params.amount1Min,
                    deadline: params.deadline
                })
            )
        );

        // encode collect
        nonfungiblePositionManagerData[1] = abi.encodeCall(
            nonfungiblePositionManager.collect,
            (
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            )
        );

        nonfungiblePositionManagerData[2] = abi.encodeCall(nonfungiblePositionManager.burn, (tokenId));

        // call the nonfungiblePositionManager
        bytes[] memory nonfungiblePositionManagerResults = nonfungiblePositionManager.multicall(
            nonfungiblePositionManagerData
        );

        (uint256 amount0, uint256 amount1) = abi.decode(nonfungiblePositionManagerResults[1], (uint256, uint256));

        uint256 amount;
        uint256 amountRemaining;
        amountRemaining = amount = (params.swapToken0 ? amount0 : amount1);

        bytes[] memory swapRouterData;
        unchecked {
            swapRouterData = new bytes[](
                params.v2ExactInputs.length +
                    params.v3ExactInputSingles.length +
                    params.v3ExactInputs.length +
                    params.otherCalls.length
            );
        }
        // the current index of swapRouterData
        uint256 swapRouterDataIndex;

        // this is a somewhat fragile hack to save gas - if the user wants to swap the entire amount,
        // then the last of their swaps needs to ignore accumulated rounding error associated
        // with using bips, and specify the entire remaining amount. the first part of this
        // ternary calculates the index of the last swap for that purpose. if not, then the
        // index is set to an unreachable value, so that the index never matches
        // and the exact (rounded) swap amounts are used.
        uint256 lastSwapIndex = params.swapEntireAmount
            ? swapRouterData.length - params.otherCalls.length - 1
            : type(uint256).max;

        // encode swapExactTokensForTokens
        for (uint256 i = 0; i < params.v2ExactInputs.length; i++) {
            uint256 amountIn = swapRouterDataIndex == lastSwapIndex
                ? amountRemaining
                : (amount * params.v2ExactInputs[i].amountInBips) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeCall(
                    ISwapRouter02.swapExactTokensForTokens,
                    (
                        amountIn,
                        params.v2ExactInputs[i].amountOutMin,
                        params.v2ExactInputs[i].path,
                        params.v2ExactInputs[i].to
                    )
                );
            }
        }

        // encode exactInputSingle
        for (uint256 i = 0; i < params.v3ExactInputSingles.length; i++) {
            uint256 amountIn = swapRouterDataIndex == lastSwapIndex
                ? amountRemaining
                : (amount * params.v3ExactInputSingles[i].amountInBips) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeCall(
                    ISwapRouter02.exactInputSingle,
                    (
                        ISwapRouter02.ExactInputSingleParams({
                            tokenIn: address(params.v3ExactInputSingles[i].tokenIn),
                            tokenOut: address(params.v3ExactInputSingles[i].tokenOut),
                            fee: params.v3ExactInputSingles[i].fee,
                            recipient: params.v3ExactInputSingles[i].recipient,
                            amountIn: amountIn,
                            amountOutMinimum: params.v3ExactInputSingles[i].amountOutMinimum,
                            sqrtPriceLimitX96: 0
                        })
                    )
                );
            }
        }

        // encode exactInput
        for (uint256 i = 0; i < params.v3ExactInputs.length; i++) {
            uint256 amountIn = swapRouterDataIndex == lastSwapIndex
                ? amountRemaining
                : (amount * params.v3ExactInputs[i].amountInBips) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeCall(
                    ISwapRouter02.exactInput,
                    (
                        ISwapRouter02.ExactInputParams({
                            path: params.v3ExactInputs[i].path,
                            recipient: params.v3ExactInputs[i].recipient,
                            amountIn: amountIn,
                            amountOutMinimum: params.v3ExactInputs[i].amountOutMinimum
                        })
                    )
                );
            }
        }

        unchecked {
            for (uint256 i = 0; i < params.otherCalls.length; i++) {
                swapRouterData[swapRouterDataIndex++] = params.otherCalls[i];
            }
        }

        // approve the swapRouter for the token to be swapped
        unchecked {
            IERC20(params.swapToken0 ? token0 : token1).safeApprove(address(swapRouter), amount - amountRemaining);
        }

        swapRouter.multicall(swapRouterData);

        // send the other token to the recipient and optionally any remainder
        if (params.swapToken0) {
            IERC20(token1).safeTransfer(params.recipient, amount1);
            if (amountRemaining > 0) {
                IERC20(token0).safeTransfer(params.recipient, amountRemaining);
            }
        } else {
            IERC20(token0).safeTransfer(params.recipient, amount0);
            if (amountRemaining > 0) {
                IERC20(token1).safeTransfer(params.recipient, amountRemaining);
            }
        }

        return IERC721Receiver.onERC721Received.selector;
    }
}
