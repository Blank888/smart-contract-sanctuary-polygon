/**
 *Submitted for verification at polygonscan.com on 2022-02-03
*/

/**
 *Submitted for verification at polygonscan.com on 2022-02-01
*/

/**
 *Submitted for verification at polygonscan.com on 2022-02-01
*/

/**
 *Submitted for verification at polygonscan.com on 2022-01-31
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IBEP20 {
  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() external view returns (uint256);
  
  function burnToken() external view returns (uint256);

  /**
   * @dev Returns the token decimals.
   */
  function decimals() external view returns (uint8);

  /**
   * @dev Returns the token symbol.
   */
  function symbol() external view returns (string memory);

  /**
  * @dev Returns the token name.
  */
  function name() external view returns (string memory);

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() external view returns (address);

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
  function allowance(address _owner, address spender) external view returns (uint256);

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
contract Context {
  // Empty internal constructor, to prevent people from mistakenly deploying
  // an instance of this contract, which should be used via inheritance.
  constructor ()  { }

  function _msgSender() internal view returns (address payable) {
    return payable(msg.sender);
  }

  function _msgData() internal view returns (bytes memory) {
    this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    return msg.data;
  }
}

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
   * @dev Returns the addition of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `+` operator.
   *
   * Requirements:
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
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity's `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  /**
   * @dev Returns the multiplication of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `*` operator.
   *
   * Requirements:
   * - Multiplication cannot overflow.
   */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, errorMessage);
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts with custom message when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
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
contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor ()  {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   */
  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

contract BlackListed is Ownable {
    mapping(address=>bool) isBlacklisted;

    function blackList(address _user) public onlyOwner {
        require(!isBlacklisted[_user], "user already blacklisted");
        isBlacklisted[_user] = true;
        // emit events as well
    }
    
    function removeFromBlacklist(address _user) public onlyOwner {
        require(isBlacklisted[_user], "user already whitelisted");
        isBlacklisted[_user] = false;
        // emit events as well
    }
   
}
contract Whitelist is BlackListed {
    mapping(address => bool) whitelist;
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);

    modifier onlyWhitelisted() {
        require(isWhitelisted(msg.sender));
        _;
    }

    function addToWhiteList(address [] memory _address) public onlyOwner {
      for(uint256 i=0;i<_address.length;i++){

        whitelist[_address[i]] = true;
        emit AddedToWhitelist(_address[i]);
      }
    }

    function removeToWhiteList(address [] memory _address) public onlyOwner {
      for(uint256 i=0;i<_address.length;i++){
        whitelist[_address[i]] = false;
        emit RemovedFromWhitelist(_address[i]);
      }
    }

    function isWhitelisted(address _address) public view returns(bool) {
        return whitelist[_address];
    }
}

contract METAREA is Context, IBEP20, Whitelist {
  using SafeMath for uint256;
  
  mapping (address => uint256) private _balances;
  mapping (address => uint256) private _depositedBalances;

  mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;
    uint256 private _burnToken=0;
    bool private hasStart=false;
    bool private hasStartWhiteListed=false;
    uint256 public soldToken;
    uint256 public soldTokenWhiteListed;
    uint256 public airDropTokens;
    uint256 public rate = 1*(10**15);
    uint256 public rateWhiteListed = 1*(10**15);
    uint256 public airdrop = 10;
    uint256 public rewards=5; 
    address[]  public _airaddress;
    uint256 public startDate=0;
    uint256 public minimumDeposite;
    uint256 public maximumDeposite;
    uint256 public maxDepositePerUser;
    uint256 public startDateWhiteListed=0;
    uint256 public minimumDepositeWhiteListed;
    uint256 public maximumDepositeWhiteListed;

    uint256 public burnFee=1;
    uint256 public marketingFee=1;
    uint256 public LPFee=1;
    address public marketingAddress=0x2cdA25C0657d7622E6301bd93B7EC870a56fE500;
    address public LPAddress=0x2cdA25C0657d7622E6301bd93B7EC870a56fE500;
    address[]  public excludedAddresses;
    bool private isInternelCall=false;
    
  constructor()  {
    _name = "METAREA";
    _symbol = "MAA";
    _decimals = 18;
    _totalSupply = 200000000000 * 10**18;
    _balances[msg.sender] = _totalSupply;

    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  /**
   * @dev Returns the token decimals.
   */
  function decimals() override external view returns (uint8) {
    return _decimals;
  }
  
  /**
   * @dev Start the sale.
   */
  function startSale(uint256 _rate,uint256 _minimumDeposite,uint256 _maximumDeposite) external onlyOwner returns (bool){
        startDate=block.timestamp;
        minimumDeposite=_minimumDeposite;
        maximumDeposite=_maximumDeposite;
        rate = _rate;
        hasStart=true;
        soldToken=0;
        return true;
  }
  /**
   * @dev Start the sale for WhitedListed .
   */
  function startSaleWhiteListed(uint256 _rate,uint256 _minimumDeposite,uint256 _maximumDeposite) external onlyOwner returns (bool){
        startDateWhiteListed=block.timestamp;
        minimumDepositeWhiteListed=_minimumDeposite;
        maximumDepositeWhiteListed=_maximumDeposite;
        rateWhiteListed = _rate;
        hasStartWhiteListed=true;
        soldTokenWhiteListed=0;
        return true;
  }
  /**
   * @dev Pause the sale.
   */
   
  function pauseSale() external onlyOwner returns (bool){
      hasStart=false;
      return true;
  }
  function getOwner()  override external view returns (address) {
    return owner();
  }
  /**
   * @dev Returns the bep token owner.
   */
 function buyToken() public payable{
       require(hasStart==true,"Sale is not started");
       require(!isBlacklisted[msg.sender], "caller is backlisted"); 
       require(soldToken<=(_totalSupply.mul(10)).div(100),"Token Out Of stock");
       require(msg.value>=minimumDeposite,"Minimum Amount Not reached");
       require(msg.value<=maximumDeposite,"maximum Amount reached");

       require(msg.value+_depositedBalances[msg.sender]<=maxDepositePerUser,"Maximum deposite amount reached");
       require(_depositedBalances[msg.sender]<=maxDepositePerUser,"You have reached your deposite limit");


       uint256 numberOfTokens=(((msg.value*(10**18))/rate));
       require((soldToken+numberOfTokens)<=(_totalSupply.mul(10)).div(100),"Not Enough Tokens Left");
       payable(owner()).transfer(msg.value);
       uint256 depositedAmount=0;
       depositedAmount = _depositedBalances[msg.sender];
       _depositedBalances[msg.sender]= depositedAmount.add(msg.value);

       // call internal 
        isInternelCall=true;

       _transfer(owner(),msg.sender,numberOfTokens);
       soldToken=soldToken+numberOfTokens;
   }
    /**
   * @dev Returns the bep token owner.
   */
    function buyTokenWhiteListed() public payable{
       require(hasStartWhiteListed==true,"Sale is not started");
       require(!isBlacklisted[msg.sender], "caller is backlisted"); 
       require(isWhitelisted(msg.sender), "caller is Not WhitedListed"); 
       require(soldTokenWhiteListed<=(_totalSupply.mul(10)).div(100),"Token Out Of stock");
       require(msg.value>=minimumDepositeWhiteListed,"Minimum Amount Not reached");
       require(msg.value<=maximumDepositeWhiteListed,"maximum Amount reached");

       require(msg.value+_depositedBalances[msg.sender]<=maxDepositePerUser,"Maximum deposite amount reached");
       require(_depositedBalances[msg.sender]<=maxDepositePerUser,"You have reached your deposite limit");

       uint256 numberOfTokens=(((msg.value*(10**18))/rateWhiteListed));
       require((soldToken+numberOfTokens)<=(_totalSupply.mul(10)).div(100),"Not Enough Tokens Left");
       payable(owner()).transfer(msg.value);

       uint256 depositedAmount=0;
       depositedAmount = _depositedBalances[msg.sender];
       _depositedBalances[msg.sender]= depositedAmount.add(msg.value);
        
        // call internal 
        isInternelCall=true;
        
       _transfer(owner(),msg.sender,numberOfTokens);        
       soldTokenWhiteListed=soldTokenWhiteListed+numberOfTokens;
   }
   
   function setDrop(uint256 _airdrop, uint256 _rewards) onlyOwner public returns(bool){
        airdrop = _airdrop;
        rewards = _rewards;
        delete _airaddress;
        return true;
    }
    
    function airdropTokens(address ref_address) public returns(bool){
        require(airdrop!=0, "No Airdrop started yet");
        require(airDropTokens<(_totalSupply.mul(30)).div(100),"Air Drop Tokens Finished");
        bool _isExist = false;
        for (uint8 i=0; i < _airaddress.length; i++) {
                if(_airaddress[i]==msg.sender){
                    _isExist = true;
                }
            }
        require(_isExist==false, "Already Dropped");
        // call internal 
        isInternelCall=true;        
        _transfer(owner(), msg.sender, airdrop*(10**18));
        _transfer(owner(), ref_address, ((airdrop*(10**18)*rewards)/100));
        _airaddress.push(msg.sender);
        airDropTokens=airDropTokens+(airdrop*(10**18));
        return true;
    }


    // SET AND SHOW BURN FEE PERCENTEAGE
    function setBurnFees (uint256 _fee) public onlyOwner returns (bool) {
        
        burnFee=_fee;
        return true;
    }


    // SET AND SHOW MARKETING FEE
    function setMarktingFees (uint256 _fee) public onlyOwner returns (bool) {
        
        marketingFee = _fee;
        return true;
    }


    // SET AND SHOW LP FEE
    function setLPFees (uint256 _fee) public onlyOwner returns (bool) {
        
        LPFee = _fee;
        return true;
    }

    // SET Marketing address
    function setMarketingAddress(address _address) public onlyOwner returns(bool){
      marketingAddress = _address;
      return true;
    }

    // SET LP address
    function setLPAddress(address _address) public onlyOwner returns(bool){
      LPAddress = _address;
      return true;
    }

    //SET THE ADDRESS 
    function setExcludedAddress(address[] memory _address) public onlyOwner returns(bool){
      for(uint256 i=0;i<_address.length;i++){
        excludedAddresses.push(_address[i]);
      }        
      return true;
    }   

    //SET DEPOSITE PER USER 

    function setMaxDepositePerUser(uint256 _amount) public onlyOwner returns(bool){
        maxDepositePerUser = _amount;
        return true;
    }  
    
  /**
   * @dev Returns the token symbol.
   */
  function symbol()  override external view returns (string memory) {
    return _symbol;
  }

  /**
  * @dev Returns the token name.
  */
  function name() override external view returns (string memory) {
    return _name;
  }

  /**
   * @dev See {BEP20-totalSupply}.
   */
  function totalSupply() override external view returns (uint256) {
    return _totalSupply;
  }
  
  function burnToken() override external view returns (uint256) {
    return _burnToken;
  }

  /**
   * @dev See {BEP20-balanceOf}.
   */
  function balanceOf(address account) override external view returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) override external returns (bool) {
       require(soldToken<=(_totalSupply.mul(40)).div(100),"Token Out Of stock");
       require((soldToken+amount)<=(_totalSupply.mul(40)).div(100),"Not Enough Tokens Left");
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev See {BEP20-allowance}.
   */
  function allowance(address owner, address spender) override external view returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) override external returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev See {BEP20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {BEP20};
   *
   * Requirements:
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for `sender`'s tokens of at least
   * `amount`.
   */
  function transferFrom(address sender, address recipient, uint256 amount) override public returns (bool) {
      require(soldToken<=(_totalSupply.mul(40)).div(100),"Token Out Of stock");
      require((soldToken+amount)<=(_totalSupply.mul(40)).div(100),"Not Enough Tokens Left");
      
      // bool isExist = false;
      // for (uint8 i=0; i < excludedAddresses.length; i++) {
      //     if(excludedAddresses[i]==msg.sender){
      //         isExist = true;
      //     }
      // }

      // if(isExist){
      //     _transfer(sender,recipient,amount);
      // }else{
      //     uint256 burnTokens = amount.mul(burnFee).div(100);
      //     uint256 marketingTokens = amount.mul(marketingFee).div(100);
      //     uint256 LPAmount = amount.mul(LPFee).div(100);

      //     uint256 totalDeductedAmount = burnTokens.add(marketingTokens).add(LPAmount);
      //     uint256 transferableAmount = amount.sub(totalDeductedAmount);
      //     _transfer(sender,marketingAddress,marketingTokens);
      //     _transfer(sender,LPAddress,LPAmount);
      //     _transfer(sender,0x000000000000000000000000000000000000dEaD,burnTokens);
      //     _transfer(sender,msg.sender,transferableAmount);            
      // }
      _transfer(sender,recipient,amount);
      _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
      return true;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  /**
   * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
   * the total supply.
   *
   * Requirements
   *
   * - `msg.sender` must be the token owner
   */


  /**
   * @dev Burn `amount` tokens and decreasing the total supply.
   */
  function burn(uint256 amount) public onlyOwner returns (bool) {
    _burn(_msgSender(), amount);
    _burnToken=amount+_burnToken;
    return true;
  }

  /**
   * @dev Moves tokens `amount` from `sender` to `recipient`.
   *
   * This is internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");

    if(isInternelCall){
      _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
      _balances[recipient] = _balances[recipient].add(amount);  
      isInternelCall=false;
      emit Transfer(sender, recipient, amount);    
    }else{

      bool isExist = false;
      for (uint8 i=0; i < excludedAddresses.length; i++) {
          if(excludedAddresses[i]==msg.sender){
              isExist = true;
          }
      }

      if(isExist){
          _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
          _balances[recipient] = _balances[recipient].add(amount);         
          isInternelCall=false;         
          emit Transfer(sender, recipient, amount);
      }else{
        uint256 burnTokens = amount.mul(burnFee).div(100);
        uint256 marketingTokens = amount.mul(marketingFee).div(100);
        uint256 LPAmount = amount.mul(LPFee).div(100);

        uint256 totalDeductedAmount = burnTokens.add(marketingTokens).add(LPAmount);
        uint256 transferableAmount = amount.sub(totalDeductedAmount);

        _balances[marketingAddress] = _balances[marketingAddress].add(marketingTokens);
        _balances[LPAddress] = _balances[LPAddress].add(LPAmount);
        // burn tokens
        _balances[0x000000000000000000000000000000000000dEaD]=_balances[0x000000000000000000000000000000000000dEaD].add(burnTokens);
        _balances[sender] = _balances[sender].sub(transferableAmount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(transferableAmount);

        isInternelCall=false;
        emit Transfer(sender, marketingAddress, marketingTokens);
        emit Transfer(sender, LPAddress, LPAmount);
        emit Transfer(sender, 0x000000000000000000000000000000000000dEaD, burnTokens);
        emit Transfer(sender, recipient, transferableAmount);           
      }
    }

    // _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
    // _balances[recipient] = _balances[recipient].add(amount);
    // emit Transfer(sender, recipient, amount);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements
   *
   * - `to` cannot be the zero address.
   */


  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
   *
   * This is internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
   * from the caller's allowance.
   *
   * See {_burn} and {_approve}.
   */
  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
  }
}