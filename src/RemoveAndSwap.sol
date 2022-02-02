// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import './interfaces/external/INonfungiblePositionManager.sol';

import './libraries/RemoveAndSwapDecoder.sol';

contract RemoveAndSwap is IERC721Receiver {
  INonfungiblePositionManager immutable nonfungiblePositionManager;

  error UnsupportedNFT(address caller);

  constructor(INonfungiblePositionManager _nonfungiblePositionManager) {
    nonfungiblePositionManager = _nonfungiblePositionManager;
  }

  function onERC721Received(
    address,
    address,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    if (msg.sender != address(nonfungiblePositionManager))
      revert UnsupportedNFT(msg.sender);
    RemoveAndSwapDecoder.Params memory params = RemoveAndSwapDecoder.decode(
      data
    );

    (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
      .positions(tokenId);

    if (liquidity > 0) {
      nonfungiblePositionManager.decreaseLiquidity(
        INonfungiblePositionManager.DecreaseLiquidityParams({
          tokenId: tokenId,
          liquidity: liquidity,
          amount0Min: params.amount0Min,
          amount1Min: params.amount1Min,
          deadline: params.deadline
        })
      );
    }

    (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
      INonfungiblePositionManager.CollectParams({
        tokenId: tokenId,
        recipient: address(this),
        amount0Max: type(uint128).max,
        amount1Max: type(uint128).max
      })
    );

    // TODO have to handle approvals, slippage adjustments, split routes, etc. here

    // TODO have to handle swap(s) + other swap actions here

    return IERC721Receiver.onERC721Received.selector;
  }
}
