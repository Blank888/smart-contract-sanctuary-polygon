/**
 *Submitted for verification at polygonscan.com on 2022-02-11
*/

/**
 *Submitted for verification at polygonscan.com on 2022-02-03
*/

/**
 *Submitted for verification at snowtrace.io on 2021-12-08
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


pragma solidity ^0.7.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


pragma solidity ^0.7.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


pragma solidity ^0.7.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPresaleHom {
    function mint(address account_, uint256 amount_) external;
}

contract DAIHOMPresale is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount; // Amount DAI deposited by user
        uint256 debt; // total HOM claimed thus pHOM debt
        bool claimed; // True if a user has claimed HOM
    }

    // Tokens to raise (DAI) and for offer (pHOM) which can be swapped for (HOM)
    IERC20 public DAI; // for user deposits
    IERC20 public pHOM;
    IERC20 public HOM;

    address public DAO; // Multisig treasury to send proceeds to

    uint256 public firstPhasePrice = 20 * 1e18; // 25 DAI per pHOM

    uint256 public secondPhasePrice = 40 * 1e18; // 50 DAI per pHOM

    uint256 public cap = 1500 * 1e18; // 1500 DAI cap per firstPhasewhitelisted user

    uint256 public minCap = 500 * 1e18; // 1500 DAI cap per firstPhasewhitelisted user

    uint256 public totalRaisedDAI; // total DAI raised by sale

    uint256 public totalDebt; // total pHOM and thus HOM owed to users

    bool public started; // true when sale is started

    bool public ended; // true when sale is ended

    bool public isPublic; // true when presale is public

    bool public claimable; // true when sale is claimable

    bool public claimPresale; // true when pHOM is claimable

    bool public contractPaused; // circuit breaker

    mapping(address => UserInfo) public userInfo;

    mapping(address => bool) public firstPhasewhitelisted; // True if user is firstPhasewhitelisted

    mapping(address => bool) public secondPhasewhitelisted; // True if user is secondPhasewhitelisted

    mapping(address => uint256) public homClaimable; // amount of hom claimable by address

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address token, address indexed who, uint256 amount);
    event Mint(address token, address indexed who, uint256 amount);
    event SaleStarted(uint256 block);
    event SaleEnded(uint256 block);
    event SalePublished(uint256 block);
    event ClaimUnlocked(uint256 block);
    event ClaimPresaleUnlocked(uint256 block);
    event AdminWithdrawal(address token, uint256 amount);

    constructor(
        address _pHOM,
        address _HOM,
        address _USDC,
        address _DAO
    ) {
        require(_pHOM != address(0));
        pHOM = IERC20(_pHOM);
        require(_HOM != address(0));
        HOM = IERC20(_HOM);
        require(_USDC != address(0));
        DAI = IERC20(_USDC);
        require(_DAO != address(0));
        DAO = _DAO;
        isPublic = false;

        firstPhasewhitelisted[msg.sender] = true;
    }

    //* @notice modifer to check if contract is paused
    modifier checkIfPaused() {
        require(contractPaused == false, "contract is paused");
        _;
    }

    /**
     *  @notice set Hom Token
     *  @param _HOM: address of HOM
     */
    function setHom(address _HOM) external onlyOwner {
        require(_HOM != address(0));
        HOM = IERC20(_HOM);
    }

    /**
     *  @notice set pHOM Token
     *  @param _pHOM: address of pHOM
     */
    function setpHOM(address _pHOM) external onlyOwner {
        require(_pHOM != address(0));
        pHOM = IERC20(_pHOM);
    }

    /**
     *  @notice set firstPhasePrice for pHOM
     *  @param _price: firstPhasePrice for pHOM
     */
    function setFirstPhasePrice(uint256 _price) external onlyOwner {
        require(!started, "Sale has already started");
        firstPhasePrice = _price;
    }

    /** 
     *  @notice set secondPhasePrice for pHOM
     *  @param _price: secondPhasePrice for pHOM
     */
    function setSecondPhasePrice(uint256 _price) external onlyOwner {
        require(!started, "Sale has already started");
        secondPhasePrice = _price;
    }

    /**
     *  @notice set DAI cap per user
     *  @param _cap: DAI cap per user
     */
    function setCap(uint256 _cap) external onlyOwner {
        require(!started, "Sale has already started");
        cap = _cap;
    }

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to firstPhasewhitelist
     */
    function addFirstPhaseWhitelist(address _address) external onlyOwner {
        firstPhasewhitelisted[_address] = true;
    }

   /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to secondPhasewhitelist
     */

    function addSecondPhaseWhitelist(address _address) external onlyOwner {
        secondPhasewhitelisted[_address] = true;
    }



    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to firstPhasewhitelist
     */
    function addFirstPhaseMultipleWhitelist(address[] calldata _addresses)
        external
        onlyOwner
    {
        require(_addresses.length <= 100, "too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            firstPhasewhitelisted[_addresses[i]] = true;
        }
    }

  /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to secondPhasewhitelist
     */
    function addSecondPhaseMultipleWhitelist(address[] calldata _addresses)
        external
        onlyOwner
    {
        require(_addresses.length <= 400, "too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            secondPhasewhitelisted[_addresses[i]] = true;
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from firstPhasewhitelisted
     */
    function removeFirstPhaseWhitelist(address _address) external onlyOwner {
        firstPhasewhitelisted[_address] = false;
    }

        /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from secondPhasewhitelisted
     */
    function removeSecondPhaseWhitelist(address _address) external onlyOwner {
        secondPhasewhitelisted[_address] = false;
    }

    // @notice Starts the sale
    function start() external onlyOwner {
        require(!started, "Sale has already started");
        started = true;
        emit SaleStarted(block.number);
    }

    // @notice set public
    function setPublic() external onlyOwner {
        require(!ended, "Sale has already ended");
        isPublic = true;
        emit SalePublished(block.number);
    }

    // @notice Ends the sale
    function end() external onlyOwner {
        require(started, "Sale has not started");
        require(!ended, "Sale has already ended");
        ended = true;
        emit SaleEnded(block.number);
    }

    // @notice lets users claim HOM
    // @dev send sufficient HOM before calling
    function claimUnlock() external onlyOwner {
        require(ended, "Sale has not ended");
        require(!claimable, "Claim has already been unlocked");
        require(
            HOM.balanceOf(address(this)) >= totalDebt,
            "not enough HOM in contract"
        );
        claimable = true;
        emit ClaimUnlocked(block.number);
    }

    // @notice lets users claim pHOM
    function claimPresaleUnlock() external onlyOwner {
        require(claimable, "Claim has not been unlocked");
        require(!claimPresale, "Claim Presale has already been unlocked");
        claimPresale = true;
        emit ClaimPresaleUnlocked(block.number);
    }

    // @notice lets owner pause contract
    function togglePause() external onlyOwner returns (bool) {
        contractPaused = !contractPaused;
        return contractPaused;
    }

    /**
     *  @notice transfer ERC20 token to DAO multisig
     *  @param _token: token address to withdraw
     *  @param _amount: amount of token to withdraw
     */
    function adminWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);
        emit AdminWithdrawal(_token, _amount);
    }

    /**
     *  @notice it deposits DAI for the sale
     *  @param _amount: amount of DAI to deposit to sale (18 decimals)
     */
    function deposit(uint256 _amount) external checkIfPaused {
        require(started, "Sale has not started");
        require(!ended, "Sale has ended");
        require(
            firstPhasewhitelisted[msg.sender] == true || secondPhasewhitelisted[msg.sender] == true || isPublic,
            "msg.sender is not whitelisted user"
        );
        require(minCap <= _amount, "min amount is 500 DAI");
        
        uint256 price;
        
        if(firstPhasewhitelisted[msg.sender] == true) {
            price = firstPhasePrice;
        }
        else if(secondPhasewhitelisted[msg.sender] == true){
            price = secondPhasePrice;
        }   
        
        UserInfo storage user = userInfo[msg.sender];

        require(cap >= user.amount.add(_amount), "new amount above user limit");

        user.amount = user.amount.add(_amount);
        totalRaisedDAI = totalRaisedDAI.add(_amount);

        uint256 payout = _amount.mul(1e18).div(price).div(1e9); // pHOM to mint for _amount

        totalDebt = totalDebt.add(payout);

        DAI.safeTransferFrom(msg.sender, DAO, _amount);

        IPresaleHom(address(pHOM)).mint(msg.sender, payout);

        emit Deposit(msg.sender, _amount);
    }

      /**
     *  @notice set DAI cap per user
     *  @param _cap: DAI cap per user
     */
    function setMinCap(uint256 _cap) external onlyOwner {
        require(!started, "Sale has already started");
        minCap = _cap;
    }
    /**
     *  @notice it deposits pHOM to withdraw HOM from the sale
     *  @param _amount: amount of pHOM to deposit to sale (9 decimals)
     */
    function withdraw(uint256 _amount) external checkIfPaused {
        require(claimable, "HOM is not yet claimable");
        require(_amount > 0, "_amount must be greater than zero");

        UserInfo storage user = userInfo[msg.sender];

        user.debt = user.debt.add(_amount);

        totalDebt = totalDebt.sub(_amount);

        pHOM.safeTransferFrom(msg.sender, address(this), _amount);

        HOM.safeTransfer(msg.sender, _amount);

        emit Mint(address(pHOM), msg.sender, _amount);
        emit Withdraw(address(HOM), msg.sender, _amount);
    }

    // @notice it checks a users DAI allocation remaining
    function getUserRemainingAllocation(address _user)
        external
        view
        returns (uint256)
    {
        UserInfo memory user = userInfo[_user];
        return cap.sub(user.amount);
    }

    // @notice it is listed on whitelist
    function getPriceForThisAddress(address _user) external view returns (uint256)
    {
        
        if(firstPhasewhitelisted[_user])
        {
            return firstPhasePrice;
        }
        else if(secondPhasewhitelisted[_user]) {
            return secondPhasePrice;
        }
        else 
        return 0;

    }

    // @notice it claims pHOM back from the sale
    function claimPresaleHom() external checkIfPaused {
        require(claimPresale, "pHOM is not yet claimable");

        UserInfo storage user = userInfo[msg.sender];

        require(user.debt > 0, "msg.sender has not participated");
        require(!user.claimed, "msg.sender has already claimed");

        user.claimed = true;

        uint256 payout = user.debt;
        user.debt = 0;

        pHOM.safeTransfer(msg.sender, payout);

        emit Withdraw(address(pHOM), msg.sender, payout);
    }
}