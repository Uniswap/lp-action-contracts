// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library SafeTransfer {
    error TransferUnsuccessful();
    error TransferFailed(bytes data);

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeCall(IERC20.transfer, (to, value)));
        if (!success) revert TransferUnsuccessful();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TransferFailed(data);
    }
}
