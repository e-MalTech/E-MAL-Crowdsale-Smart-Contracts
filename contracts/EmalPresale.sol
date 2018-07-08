pragma solidity ^ 0.4 .24;

import "./SafeMath.sol";
import './EmalWhitelist.sol';

// for mist wallet compatibility
contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
}


/**
 * EMAL Presale smart contract for eMal ICO. Is a FinalizableCrowdsale
 * This will collect funds from investors in ETH directly from the investor post which it will emit an event
 * The event will then be collected by eMal backend servers and based on the amount of ETH sent and ETH rate
 * in terms of DHS, the tokens to be allocated will be calculated by the backend server and then it will call
 * allocate tokens API for investors address.
 * In case the investment is not done through ETH, and directly through netbanking or on the public sale platform,
 * eMAl backend server will calculate the number of tokens to be allocated and then directly call the allocate
 * tokens API to allocate tokens to the investor.
 */

contract EmalPresale is EmalWhitelist {

    using SafeMath
    for uint256;

    // Start and end timestamps
    uint public startTime;
    uint public endTime;

    // The token being sold
    EmalToken public token;

    // Owner of the token
    address public owner;

    // Address where funds are collected
    address public wallet;

    /**
     * How many token units an investor gets per wei.
     * The rate is the conversion between wei and the smallest and indivisible token unit.
     * 1 ether = 460 EmalTokens
     * 10^18 wei = 460 EmalTokens
     * 1 EmalTokens = 2,164,502,164,502,164 wei
     */
    uint256 public overridenRateValue = 0;

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors by server for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated;

    // Investor contributions made in ether only
    mapping(address => uint256) etherInvestments;

    // Total ether invested during the crowdsale
    uint256 public totalEtherRaisedByPresale = 0;

    // Count of allocated tokens (not issued only allocated) for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of allocated tokens issued to each investor and bounty user.
    mapping(address => uint256) public amountOfAllocatedTokensGivenOut;

    // Hard cap in EMAL tokens
    uint256 constant public hardCap = 100000000 * (10 ** 18);


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Event for token purchase logging
     * @param purchaser Address that paid for the tokens
     * @param beneficiary Address that got the tokens
     * @param value The amount that was paid (in wei)
     * @param amount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * @dev Event fired when tokens are allocated to an investor account
     * @param beneficiary Address that is allocated tokens
     * @param tokenCount The amount of tokens that were allocated
     */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);

    /**
     * @dev Event fired when tokens are sent to the main crodsale for an investor
     * @param beneficiary Address where the allocated tokens were sent
     * @param tokenCount The amount of tokens that were sent
     */
    event IssuedAllocatedTokens(address indexed beneficiary, uint256 tokenCount);

    /**
     * @param _startTime Unix timestamp for the start of the token sale
     * @param _endTime Unix timestamp for the end of the token sale
     * @param _wallet Ethereum address to which the invested funds are forwarded
     * @param _token Address of the token that will be rewarded for the investors
     */
    constructor(uint256 _startTime, uint256 _endTime, address _wallet, address _token) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_wallet != address(0));
        require(_token != address(0));

        startTime = _startTime;
        endTime = _endTime;
        wallet = _wallet;
        owner = msg.sender;
        token = EmalToken(_token);

        // to allow refunds, ie: ether can be sent by _wallet
        super.addToWhitelist(wallet);
        // add owner also to whitelist
        super.addToWhitelist(msg.sender);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier hasPresaleEnded() {
      require(!(now >= startTime && now <= endTime) && (totalTokensSoldandAllocated < hardCap));
      _;
    }

    /**
     * @dev Fallback function that can be used to buy tokens.
     */
    function() external payable {
        if (isWhitelisted(msg.sender)) {
            buyTokensUsingEther(msg.sender);
        } else {
            /* Do not accept ETH */
            revert();
        }
    }

    /**
     * @dev Function for buying tokens
     * @param beneficiary The address that should receive bought tokens
     */
    function buyTokensUsingEther(address beneficiary) onlyIfWhitelisted(beneficiary) public payable {
        require(beneficiary != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // Retrieve the current token rate
        uint256 rate = getRate();

        // Calculate token amount to be transferred
        uint256 tokens = weiAmount.mul(rate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(rate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        etherInvestments[beneficiary] = etherInvestments[beneficiary].add(weiAmount);
        totalEtherRaisedByPresale = totalEtherRaisedByPresale.add(weiAmount);


        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokenPurchasedUsingEther(msg.sender, beneficiary, weiAmount, tokens);

        // Forward funds
        wallet.transfer(weiAmount);

        // Update token contract.
        _postValidationUpdateTokenContract();

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }


    function _postValidationUpdateTokenContract() pure internal {
      /** @dev Do nothing for now
        */
    }

    /**
     * @dev Adds an investor to whitelist
     * @param _addr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function addWhitelistInvestor(address _addr) onlyOwner public returns(bool success) {
        addToWhitelist(_addr);
        return true;
    }

    /**
     * @dev Removes an investor's address from whitelist
     * @param _addr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function removeWhitelistInvestor(address _addr) onlyOwner public returns(bool success) {
        removeFromWhitelist(_addr);
        return true;
    }

    function setRate(uint256 _value) onlyOwner public {
        overridenRateValue = _value;
    }

    /**
     * @dev Internal function that is used to determine the current rate for token / ETH conversion
     * @dev there exists a case where rate cant be set to 0, which is fine.
     * @return The current token rate
     */
    function getRate() internal constant returns(uint256) {
        if ( overridenRateValue!=0 ) {
            return overridenRateValue;

        } else {
            if (now < (startTime + 1 weeks)) {
                return 6000;
            }

            if (now < (startTime + 2 weeks)) {
                return 5500;
            }

            if (now < (startTime + 3 weeks)) {
                return 5250;
            }
            return 5000;
        }
    }

    /**
     * @dev Internal function that is used to check if the incoming purchase should be accepted.
     * @return True if the transaction can buy tokens
     */
    function validPurchase() internal constant returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && nonZeroPurchase && hardCapNotReached;
    }

    /**
     * @return True if crowdsale event has ended
     */
    function hasEnded() public constant returns(bool) {
        return now > endTime || totalTokensSoldandAllocated >= hardCap;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOfEtherInvestor(address _owner) external constant returns(uint256 balance) {
        return etherInvestments[_owner];
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }


    /**
     * BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
     * ALSO HANDLES TOKEN ALLOCATION FOR BOUNTY USERS
     * functions are automatically called by ICO Sails.js app.
     */


    /**
     * @dev Allocates tokens to an investor or bounty user
     * @param beneficiary The address of the investor or the bounty user
     * @param tokenCount The number of tokens to be allocated to this address
     */
    function allocateTokens(address beneficiary, uint256 tokenCount) onlyOwner public returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        /* Number of tokens to return to sender if hardcap gets reached inbetween*/
        uint256 returnToSender = 0;
        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            returnToSender = tokenCount.sub(tokens);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokenCount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokenCount);
        emit TokensAllocated(beneficiary, tokens);

        /* Update token contract. */
        _postValidationUpdateTokenContract();
        return true;
    }

    function validAllocation( uint256 tokenCount ) internal constant returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = tokenCount != 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && nonZeroPurchase && hardCapNotReached;
    }


    /**
     * @dev A=Remove tokens from an investors or bounty user's allocation.
     * @dev Used in game based bounty allocation, automatically called from the Sails app
     * @param beneficiary The address of the investor or the bounty user
     * @param tokenCount The number of tokens to be deallocated to this address
     */
    function deductAllocatedTokens(address beneficiary, uint256 tokenCount) onlyOwner public returns(bool success) {
        /* Tokens to be allocated must be more than 0 */
        /* The address must has at least the number of tokens to be deducted */
        require(tokenCount > 0 && allocatedTokens[beneficiary] > tokenCount);

        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].sub(tokenCount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.sub(tokenCount);
        return true;
    }

    /**
     * @dev Getter function to check the amount of allocated tokens
     * @param beneficiary address of the investor or the bounty user
     */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        return allocatedTokens[beneficiary];
    }

    /**
     * @dev Public function that KYC beneficiaries can use to claim the tokens allocated to them,
     * @dev after the Crowdsale has ended to their address
     */
    function claimAllocatedTokens() hasPresaleEnded public returns(bool success) {
        /* investments of the investor or bounty alocated okens for bounty users, should be greater than 0 */
        require(allocatedTokens[msg.sender] > 0);

        uint256 tokensToSend = allocatedTokens[msg.sender];

        allocatedTokens[msg.sender] = 0;
        amountOfAllocatedTokensGivenOut[msg.sender] = amountOfAllocatedTokensGivenOut[msg.sender].add(tokensToSend);

        // assert implies it should never fail
        assert(token.transferFrom(owner, msg.sender, tokensToSend));

        emit IssuedAllocatedTokens(msg.sender, tokensToSend);
        return true;
    }

    /**
     * @dev Investors and bounty users will be issured Tokens by the sails api,
     * @dev Users who claimed already wont be issued any more tokens
     * @dev after the Crowdsale has ended to their address
     * @param beneficiary address of the investor or the bounty user
     */
    function issueTokensToAllocatedUsers(address beneficiary) onlyOwner hasPresaleEnded public returns(bool success) {
        /* investments of the investor or bounty alocated okens for bounty users, should be greater than 0 */
        require(beneficiary != address(0));
        require(allocatedTokens[beneficiary] > 0);

        uint256 tokensToSend = allocatedTokens[beneficiary];

        allocatedTokens[beneficiary] = 0;
        amountOfAllocatedTokensGivenOut[beneficiary] = amountOfAllocatedTokensGivenOut[beneficiary].add(tokensToSend);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokensToSend));

        emit IssuedAllocatedTokens(beneficiary, tokensToSend);
        return true;
    }

    /* @dev Set the target token */
    function setToken(EmalToken token_addr) onlyOwner public returns (bool success){
        token = token_addr;
        return true;
    }
}
