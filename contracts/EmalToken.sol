pragma solidity ^ 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';

contract EmalToken is StandardToken {

    using SafeMath for uint;
    using SafeMath for uint256;

    string public constant symbol = "EMAL";
    string public constant name = "E-Mal Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 1 BILLION EML tokens.
    //uint256 private constant mintingCappedAmount = 1000000000 * 10 ** uint256(decimals);

    // 23% of initial supply
    // Tokens early investors. 13% for Presale 1. + 10% for bonuses.
    uint256 public constant privatePresaleAmount = 115000000 * 10 ** uint256(decimals);

    // 59% of inital supply
    // Tokens for public through crowdsale. 57% Crowdsale and 2% bounties.
    uint256 public constant publicCrowdsaleAmount = 295000000 * 10 ** uint256(decimals);

    // 18% of inital supply.
    // Tokens for partners and advisors and project team. 18% of inital supply.
    uint256 public constant vestingAmount = 90000000 * 10 ** uint256(decimals);

    // Total initial supply of tokens to be given away initially. Rested is minted. Should be 500M tokens.
    uint256 private initialSupply = privatePresaleAmount.add(publicCrowdsaleAmount.add(vestingAmount));


    uint public startTimeForTransfers;

    address public presaleAddress;
    address public crowdsaleAddress;
    address public vestingAddress;

    // Owner of the token
    address public owner;

    bool public mintingFinished = false;

    mapping (address => bool) public frozenAccount;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier canMint() {
      require(!mintingFinished);
      _;
    }

    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() public {
        //actual constructor initialisation value
        startTimeForTransfers = now + 365 days;

        _totalSupply = initialSupply;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, privatePresaleAmount));
    }

    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, publicCrowdsaleAmount));
    }

    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vestingAmount));
    }

    function setStartTimeForTokenTransfers(uint _startTimeForTransfers) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTimeForTransfers < startTimeForTransfers) {
            startTimeForTransfers = _startTimeForTransfers;
        }
    }

    function transfer(address _to, uint _value) public returns(bool) {
        // Only possible after ICO ends
        require(now >= startTimeForTransfers);
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public returns(bool) {
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        // Only owner's tokens can be transferred before ICO ends
        if (now < startTimeForTransfers) {
            require(_from == owner);
        }

        return super.transferFrom(_from, _to, _value);
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount) hasMintPermission canMint public returns (bool) {
      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /**
     * @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() onlyOwner canMint public returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /**
      * @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }

    function transferOwnership(address newOwner) public onlyOwner {
      require(newOwner != address(0));
      emit OwnershipTransferred(owner, newOwner);
      owner = newOwner;
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }
}
