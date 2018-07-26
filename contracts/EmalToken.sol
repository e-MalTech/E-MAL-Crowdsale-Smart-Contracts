pragma solidity ^0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract EmalToken is StandardToken, Ownable {

    using SafeMath for uint;
    using SafeMath for uint256;

    string public constant symbol = "EMAL";
    string public constant name = "E-Mal Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 1 BILLION EML tokens.
    //uint256 private constant mintingCappedAmount = 1000000000 * 10 ** uint256(decimals);

    // 24% of initial supply
    uint256 constant presaleAmount = 120000000 * 10 ** uint256(decimals);
    // 60% of inital supply
    uint256 constant crowdsaleAmount = 300000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256  constant vestingAmount = 40000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256 constant bountyAmount = 40000000 * 10 ** uint256(decimals);
    // Total initial supply of tokens to be given away initially. Rested is minted. Should be 500M tokens.
    uint256 private initialSupply = presaleAmount.add(crowdsaleAmount.add(vestingAmount.add(bountyAmount)));

    address public presaleAddress;
    address public crowdsaleAddress;
    address public vestingAddress;
    address public bountyAddress;



    /** @dev Defines the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    uint public startTimeForTransfers;

    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of EML tokens and to comply with Anti
      * Money laundering regulations EML tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);


    constructor() public {
        startTimeForTransfers = now + 5 minutes;

        _totalSupply = initialSupply;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    /** @dev Basic setters and getters to allocate tokens for vesting factory, presale
      * crowdsale and bounty this is done so that no need of actually transferring EML
      * tokens to sale contracts and hence preventing EML tokens from the risk of being
      * locked out in future inside the subcontracts.
      */
    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, presaleAmount));
    }
    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, crowdsaleAmount));
    }
    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vestingAmount));
    }
    function setBountyAddress(address _bountyAddress) external onlyOwner {
        bountyAddress = _bountyAddress;
        assert(approve(bountyAddress, bountyAmount));
    }

    function getPresaleAmount() public pure returns(uint256) {
        return presaleAmount;
    }
    function getCrowdsaleAmount() public pure returns(uint256) {
        return crowdsaleAmount;
    }
    function getVestingAmount() public pure returns(uint256) {
        return vestingAmount;
    }
    function getBountyAmount() public pure returns(uint256) {
        return bountyAmount;
    }

    /** @dev Sets the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    function setStartTimeForTokenTransfers(uint _startTimeForTransfers) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTimeForTransfers < startTimeForTransfers) {
            startTimeForTransfers = _startTimeForTransfers;
        }
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      */
    function transfer(address _to, uint _value) public returns(bool) {
        require(now >= startTimeForTransfers);
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        return super.transfer(_to, _value);
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of EML is allocated to owners acc and later
      * distributed to various subcontracts.
      */
    function transferFrom(address _from, address _to, uint _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
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


    /** @dev Function to mint tokens
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

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() onlyOwner canMint public returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
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
}
