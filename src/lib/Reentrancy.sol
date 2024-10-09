// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

struct tuint256 {
    uint256 __placeholder;
}

abstract contract ReentrancyGuard {
    using TransientPrimitivesLib for tuint256;

    tuint256 private _lockState;

    uint256 internal constant DEFAULT_UNLOCKED = 0;
    uint256 internal constant LOCKED = 1;

    error Reentering();

    modifier nonReentrant() {
        if (_lockState.get() != DEFAULT_UNLOCKED) revert Reentering();
        _lockState.set(LOCKED);
        _;
        _lockState.set(DEFAULT_UNLOCKED);
    }
}

using TransientPrimitivesLib for tuint256 global;

library TransientPrimitivesLib {
    error ArithmeticOverflowUnderflow();

    function get(tuint256 storage ptr) internal view returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(ptr.slot)
        }
    }

    function set(tuint256 storage ptr, uint256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }
}
