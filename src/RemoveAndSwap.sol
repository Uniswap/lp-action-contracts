// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import './interfaces/external/ISwapRouter.sol';
import './interfaces/external/INonfungiblePositionManager.sol';

import './libraries/SafeApprove.sol';
import './libraries/SafeTransfer.sol';
import './libraries/RemoveAndSwapDecoder.sol';

contract RemoveAndSwap is IERC721Receiver {
    error UnsupportedNFT(address caller);
    error NoLiquidity();

    using SafeApprove for IERC20;
    using SafeTransfer for IERC20;
    using RemoveAndSwapDecoder for bytes;

    ISwapRouter immutable swapRouter;
    INonfungiblePositionManager immutable nonfungiblePositionManager;

    constructor(ISwapRouter _swapRouter, INonfungiblePositionManager _nonfungiblePositionManager) {
        swapRouter = _swapRouter;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

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

        if (liquidity == 0) revert NoLiquidity();

        RemoveAndSwapDecoder.Params memory params = data.decode();

        bytes[] memory nonfungiblePositionManagerData = new bytes[](2);

        // encode decreaseLiquidity
        nonfungiblePositionManagerData[0] = abi.encodeCall(
            nonfungiblePositionManager.decreaseLiquidity,
            (
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
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

        // call the nonfungiblePositionManager
        bytes[] memory nonfungiblePositionManagerResults = nonfungiblePositionManager.multicall(
            nonfungiblePositionManagerData
        );

        (uint256 amount0, uint256 amount1) = abi.decode(nonfungiblePositionManagerResults[1], (uint256, uint256));

        // approve the swapRouter for the tokens to be swapped and transfer the others
        uint256 amount;
        uint256 amountRemaining;
        if (params.swapToken0) {
            IERC20(token0).safeApprove(address(swapRouter), amount = amountRemaining = amount0);
            IERC20(token1).safeTransfer(params.recipient, amount1);
        } else {
            IERC20(token1).safeApprove(address(swapRouter), amount = amountRemaining = amount1);
            IERC20(token0).safeTransfer(params.recipient, amount0);
        }

        bytes[] memory swapRouterData = new bytes[](
            params.v2ExactInputs.length +
                params.v3ExactInputSingles.length +
                params.v3ExactInputs.length +
                params.otherCalls.length
        );
        uint256 swapRouterDataIndex;

        // encode swapExactTokensForTokens
        for (uint256 i = 0; i < params.v2ExactInputs.length; i++) {
            uint256 amountIn = swapRouterDataIndex == swapRouterData.length - params.otherCalls.length - 1
                ? amountRemaining
                : (params.v2ExactInputs[i].amountInBips * amount) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeWithSelector(
                    ISwapRouter.swapExactTokensForTokens.selector,
                    amountIn,
                    params.v2ExactInputs[i].amountOutMin,
                    params.v2ExactInputs[i].path,
                    params.v2ExactInputs[i].to
                );
            }
        }

        // encode exactInputSingle
        for (uint256 i = 0; i < params.v3ExactInputSingles.length; i++) {
            uint256 amountIn = swapRouterDataIndex == swapRouterData.length - params.otherCalls.length - 1
                ? amountRemaining
                : (params.v3ExactInputSingles[i].amountInBips * amount) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeWithSelector(
                    ISwapRouter.exactInputSingle.selector,
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(params.v3ExactInputSingles[i].tokenIn),
                        tokenOut: address(params.v3ExactInputSingles[i].tokenOut),
                        fee: params.v3ExactInputSingles[i].fee,
                        recipient: params.v3ExactInputSingles[i].recipient,
                        amountIn: amountIn,
                        amountOutMinimum: params.v3ExactInputSingles[i].amountOutMinimum,
                        sqrtPriceLimitX96: 0
                    })
                );
            }
        }

        // encode exactInput
        for (uint256 i = 0; i < params.v3ExactInputs.length; i++) {
            uint256 amountIn = swapRouterDataIndex == swapRouterData.length - params.otherCalls.length - 1
                ? amountRemaining
                : (params.v3ExactInputs[i].amountInBips * amount) / 1e4;

            amountRemaining -= amountIn;

            unchecked {
                swapRouterData[swapRouterDataIndex++] = abi.encodeWithSelector(
                    ISwapRouter.exactInput.selector,
                    ISwapRouter.ExactInputParams({
                        path: params.v3ExactInputs[i].path,
                        recipient: params.v3ExactInputs[i].recipient,
                        amountIn: amountIn,
                        amountOutMinimum: params.v3ExactInputs[i].amountOutMinimum
                    })
                );
            }
        }

        unchecked {
            for (uint256 i = 0; i < params.otherCalls.length; i++) {
                swapRouterData[swapRouterDataIndex++] = params.otherCalls[i];
            }
        }

        swapRouter.multicall(swapRouterData);

        return IERC721Receiver.onERC721Received.selector;
    }
}
