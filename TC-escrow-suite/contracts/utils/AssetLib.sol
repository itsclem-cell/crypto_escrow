// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library AssetLib {
    using SafeERC20 for IERC20;

    address internal constant NATIVE_ASSET = address(0);

    function isNative(address asset) internal pure returns (bool) {
        return asset == NATIVE_ASSET;
    }

    function transferOut(address asset, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (isNative(asset)) {
            (bool success, ) = payable(to).call{ value: amount }("");
            require(success, "Native transfer failed");
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }
}
