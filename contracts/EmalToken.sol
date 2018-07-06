pragma solidity ^ 0.4 .24;

import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import './StandardToken.sol';

contract EmalToken is StandardToken {

    using SafeMath for uint;

    string public constant symbol = "EMAL";
    string public constant name = "E-Mal Token";
    uint8 public constant decimals = 18;

    /* uint256 public constant TOTAL_SUPPLY = 10000000 * 1 ether; */

    uint256 public constant totalSupply_;
    uint256 private constant TOKEN_UNIT = 10 ** uint256(decimals);
    uint256 public constant publicAmount = 100000000 * TOKEN_UNIT; // Tokens for public

    uint public startTime;
    address public crowdsaleAddress;

    // Owner of the token
    address public owner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    constructor() public {
        startTime = now + 365 days;
        totalSupply_ = 200000000 * TOKEN_UNIT;
        owner = msg.sender;
        balances[owner] = totalSupply_;
        emit Transfer(address(0), owner, balances[owner]);
    }

    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, publicAmount));
    }

    function setStartTime(uint _startTime) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTime < startTime) {
            startTime = _startTime;
        }
    }

    function transfer(address _to, uint _value) public returns(bool) {
        // Only possible after ICO ends
        require(now >= startTime);
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public returns(bool) {
        // Only owner's tokens can be transferred before ICO ends
        if (now < startTime) {
            require(_from == owner);
        }

        return super.transferFrom(_from, _to, _value);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        super.transferOwnership(newOwner);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }

    /* Owner can transfer out any accidentally sent ERC20 tokens */
    function transferAnyERC20Token(address _tokenAddress, uint _tokens) public onlyOwner returns(bool success) {
        return ERC20(_tokenAddress).transfer(owner, _tokens);
    }
}
