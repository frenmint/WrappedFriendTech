// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IFriendtech.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

/**
 * @title Friendtech share wrapper contract.
 * @author J.Page | kp (ppmoon69.eth)
 * @notice Wrap your Friendtech shares to enable their usage in other apps.
 */
contract WrappedFriendtech is Ownable, ERC1155 {
    using LibString for uint256;
    using SafeTransferLib for address;

    // Used when converting token IDs to hex strings in `uri`.
    uint256 private constant _ADDR_BYTE_LENGTH = 20;

    // Official Friendtech contract: https://basescan.org/address/0xcf205808ed36593aa40a44f10c7f7c2f67d4a4d4.
    // Friendtech contract on Base Sepolia: https://sepolia.basescan.org/address/0xCa3908C45A90006Be94386F1f01ca6de7BC695De
    IFriendtech public constant FRIENDTECH =
        IFriendtech(0xCa3908C45A90006Be94386F1f01ca6de7BC695De);

    mapping(uint256 => string) tokenURI;

    // Tracks the wrapped token supply for each FT account.
    mapping(address sharesSubject => uint256 supply) public totalSupply;

    error ZeroAmount();

    // For receiving ETH from share sales.
    receive() external payable {}

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    // Overridden to enforce 2-step ownership transfers.
    function transferOwnership(address) public payable override {}

    // Overridden to enforce 2-step ownership transfers.
    function renounceOwnership() public payable override {}

    /**
     * @notice Set TokenURI for id.
     * @param  _id       uint256  Token ID.
     * @param  _tokenURI    string   Token URI.
     */
    function setTokenURI(uint256 _id, string memory _tokenURI) internal {
        tokenURI[_id] = _tokenURI;
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given token.
     * @param  id   uint256  Token ID.
     * @return      string   A JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
     */
    function uri(uint256 id) public view override returns (string memory) {
        return tokenURI[id];
    }

    /**
     * @notice Mints wrapped FT shares.
     * @dev    Follows the checks-effects-interactions pattern to prevent reentrancy.
     * @dev    Emits the `TransferSingle` event as a result of calling `_mint`.
     * @param  sharesSubject  address  Friendtech user address.
     * @param  amount         uint256  Shares amount.
     * @param  data           bytes    Arbitrary data to send in call to `onERC1155Received` on `msg.sender`.
     * @param  token_uri      string   Token URI.
     */
    function wrap(
        address sharesSubject,
        uint256 amount,
        bytes calldata data,
        string memory token_uri
    ) external payable {
        if (amount == 0) revert ZeroAmount();

        // Can overflow but the tx will revert since there isn't enough ETH to purchase that many FT shares.
        unchecked {
            totalSupply[sharesSubject] += amount;
        }
        uint256 id = uint256(uint160(sharesSubject));
        string memory _uri = tokenURI[id];
        if (keccak256(bytes(_uri)) != keccak256(bytes(token_uri))) {
            setTokenURI(id, token_uri);
        }

        uint256 price = FRIENDTECH.getBuyPriceAfterFee(sharesSubject, amount);

        FRIENDTECH.buyShares{value: price}(sharesSubject, amount);

        // Calls `onERC1155Received` on `msg.sender` if they're a contract account.
        // Trustworthiness of FT > `msg.sender` which is why we have this here.
        _mint(msg.sender, id, amount, data);

        if (msg.value > price) {
            // Will not underflow since `msg.value` is greater than `price`.
            unchecked {
                msg.sender.forceSafeTransferETH(msg.value - price);
            }
        }
    }

    /**
     * @notice Burns wrapped FT shares.
     * @dev    Follows the checks-effects-interactions pattern to prevent reentrancy.
     * @dev    Emits the `TransferSingle` event as a result of calling `_burn`.
     * @param  sharesSubject  address  Friendtech user address.
     * @param  amount         uint256  Shares amount.
     */
    function unwrap(address sharesSubject, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        _burn(msg.sender, uint256(uint160(sharesSubject)), amount);

        // Will not underflow if `_burn` did not throw.
        unchecked {
            totalSupply[sharesSubject] -= amount;
        }

        // Throws if `sharesSubject` is the zero address.
        FRIENDTECH.sellShares(sharesSubject, amount);

        // Transfer the contract's ETH balance since it should only have ETH from the share sale.
        msg.sender.forceSafeTransferETH(address(this).balance);
    }
}
