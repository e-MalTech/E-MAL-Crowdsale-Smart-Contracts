pragma solidity ^ 0.4 .24;

import "./SafeMath.sol";
import './StandardToken.sol';

contract EmalToken is StandardToken {

    using SafeMath for uint;

    string public constant symbol = "EMAL";
    string public constant name = "E-Mal Token";
    uint8 public constant decimals = 18;

    /* uint256 public constant TOTAL_SUPPLY = 10000000 * 1 ether; */

    uint256 public totalSupply_;
    uint256 private constant TOKEN_UNIT = 10 ** uint256(decimals);
    uint256 public constant privatePresaleAmount = 50000000 * TOKEN_UNIT; // Tokens early investors
    uint256 public constant publicCrowdsaleAmount = 100000000 * TOKEN_UNIT; // Tokens for public through crowdsale
    uint256 public constant totalVestingAmount = 50000000 * TOKEN_UNIT; // Tokens founders, advisors and developers.

    uint public startTimeForTransfers;
    address public crowdsaleAddress;
    address public presaleAddress;

    // Owner of the token
    address public owner;

    bool public mintingFinished = false;

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


    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    constructor() public {
        startTimeForTransfers = now + 365 days;
        totalSupply_ = 200000000 * TOKEN_UNIT;
        owner = msg.sender;
        balances[owner] = totalSupply_;
        emit Transfer(address(0), owner, balances[owner]);
    }

    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, publicCrowdsaleAmount));
    }

    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, privatePresaleAmount));
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
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public returns(bool) {
        // Only owner's tokens can be transferred before ICO ends
        if (now < startTimeForTransfers) {
            require(_from == owner);
        }

        return super.transferFrom(_from, _to, _value);
    }


    /**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount) hasMintPermission canMint public returns (bool) {
      totalSupply_ = totalSupply_.add(_amount);
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
       totalSupply_ = totalSupply_.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
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
