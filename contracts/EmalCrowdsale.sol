pragma solidity ^ 0.4 .24;

import "./SafeMath.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);

    function setStartTimeForTokenTransfers(uint _startTime) external;
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address _addr) public view returns(bool);
}


/**
 * EMAL Crowdsale smart contract for eMal ICO. Is a Finalizable, Timed, capped, pausable Crowdsale
 * This will collect funds from investors in ETH directly from the investor post which it will emit an event
 * The event will then be collected by eMal backend servers and based on the amount of ETH sent and ETH rate
 * in terms of DHS, the tokens to be allocated will be calculated by the backend server and then it will call
 * allocate tokens API for investors address.
 * In case the investment is not done through ETH, and directly through netbanking or on the public sale platform,
 * eMAl backend server will calculate the number of tokens to be allocated and then directly call the allocate
 * tokens API to allocate tokens to the investor.
 */

contract EmalCrowdsale {

    using SafeMath for uint256;
    using SafeMath for uint;

    // Start and end timestamps
    uint public startTime;
    uint public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

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

    // Investor contributions made in ether only
    mapping(address => uint256) public etherInvestments;

    mapping(address => uint256) public tokensSoldForEther;

    uint256 public totalEtherRaisedByCrowdsale = 0;

    uint256 public totalTokensSoldByEtherInvestments = 0;



    // Count of allocated tokens (not issued only allocated) for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of allocated tokens issued to each investor and bounty user.
    mapping(address => uint256) public amountOfAllocatedTokensGivenOut;

    uint256 public totalTokensAllocated = 0;


    // Amount of tokens that were sold to ether investors plus tokens allocated to investors by server for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated;

    // Soft cap in EMAL tokens
    uint256 constant public softCap = 29500000 * (10 ** 18);

    // Hard cap in EMAL tokens
    uint256 constant public hardCap = 295000000 * (10 ** 18);

    // Switched to true once token contract is notified of when to enable token transfers
    bool private isStartTimeSetForTokenTransfers = false;



    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

   /**
     * @dev Event for token purchase logging
     * @param purchaser Address that paid for the tokens
     * @param beneficiary Address that got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed purchaser, address indexed beneficiary, uint256 paidAmount, uint256 tokenCount);

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
     * @dev Event for refund logging
     * @param receiver The address that received the refund
     * @param amount The amount that is being refunded (in wei)
     */
    event Refund(address indexed receiver, uint256 amount);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier hasCrowdsaleEnded() {
        require(!(now >= startTime && now <= endTime) && (totalTokensSoldandAllocated < hardCap));
        _;
    }

    /* Pausable contract */

    event Pause();
    event Unpause();

    bool public paused = false;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

    function returnUnixTimeStamp() public view returns(uint256) {
        return now;
    }


    /**
     * _startTime Unix timestamp for the start of the token sale
     * _endTime Unix timestamp for the end of the token sale
     * @param _wallet Ethereum address to which the invested funds are forwarded
     * @param _token Address of the token that will be rewarded for the investors
     */
    // constructor(uint256 _startTime, uint256 _endTime, address _wallet, address _token, address _list) public {
    constructor(address _wallet, address _token, address _list) public {
        // require(_startTime >= now);
        // require(_endTime >= _startTime);
        require(_wallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = now;
        endTime = startTime + 4 hours;
        wallet = _wallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);

        // to allow refunds, ie: ether can be sent by _wallet
        // super.addToWhitelist(wallet);
        // add owner also to whitelist
        // super.addToWhitelist(msg.sender);
    }

   /** @dev Fallback function that can be used to buy tokens. Or in case of the
    *  owner, return ether to allow refunds.
    */
    function() external payable {
        if (msg.sender == wallet) {
            require(hasEnded() && totalTokensSoldandAllocated < softCap);
        } else {
            if (list.isWhitelisted(msg.sender)) {
                buyTokensUsingEther(msg.sender);
            } else {
                revert();
            }
        }
    }

   /** @dev Function for buying tokens
     * @param beneficiary The address that should receive bought tokens
     */
    function buyTokensUsingEther(address beneficiary) whenNotPaused public payable {
        require(beneficiary != address(0));
        require(validPurchase());
        require(list.isWhitelisted(beneficiary));

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
        etherInvestments[beneficiary] = etherInvestments[beneficiary].add(weiAmount);
        tokensSoldForEther[beneficiary] = tokensSoldForEther[beneficiary].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByCrowdsale = totalEtherRaisedByCrowdsale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


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


    function _postValidationUpdateTokenContract() internal {
       /** @dev If hard cap is reachde allow token transfers after two weeks
         * @dev Allow users to transfer tokens only after hardCap is reached
         * @dev Notiy token contract about startTime to start transfers
         */
        if (totalTokensSoldandAllocated == hardCap) {
            token.setStartTimeForTokenTransfers(now + 2 weeks);
        }

       /** @dev If its the first token sold or allocated then set s, allow after 2 weeks
         * @dev Allow users to transfer tokens only after ICO crowdsale ends.
         * @dev Notify token contract about sale end time
         */
        if (!isStartTimeSetForTokenTransfers) {
            isStartTimeSetForTokenTransfers = true;
            token.setStartTimeForTokenTransfers(endTime + 2 weeks);
        }
    }

    function setRate(uint256 _value) onlyOwner public {
        overridenRateValue = _value;
    }

    /**
     * @dev Internal function that is used to determine the current rate for token / ETH conversion
     * @dev there exists a case where rate cant be set to 0, which is fine.
     * @return The current token rate
     */
    function getRate() public constant returns(uint256) {
        if (overridenRateValue != 0) {
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

    function isCrowdsaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns ether to token holders in case soft cap is not reached.
     */
    function claimRefund() public onlyOwner {
        require(hasEnded());
        require(totalTokensSoldandAllocated < softCap);

        uint256 amount = etherInvestments[msg.sender];

        if (address(this).balance >= amount) {
            etherInvestments[msg.sender] = 0;
            if (amount > 0) {
                msg.sender.transfer(amount);
                emit Refund(msg.sender, amount);
            }
        }
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
    function allocateTokens(address beneficiary, uint256 tokenCount) onlyOwner whenNotPaused public returns(bool success) {
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
        totalTokensAllocated = totalTokensAllocated.add(tokenCount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokenCount);
        emit TokensAllocated(beneficiary, tokens);

        /* Update token contract. */
        // _postValidationUpdateTokenContract();
        return true;
    }

    function validAllocation(uint256 tokenCount) internal constant returns(bool) {
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
        totalTokensAllocated = totalTokensAllocated.sub(tokenCount);
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
    function claimAllocatedTokens() hasCrowdsaleEnded public returns(bool success) {
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
    function issueTokensToAllocatedUsers(address beneficiary) onlyOwner hasCrowdsaleEnded public returns(bool success) {
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

}
