# E-MAL SMARTCONTRACT v2.0


- Existing smart contracts: https://github.com/teche-mal/e-MalToken
- Sails API communicating with the contracts: contains documentation and setup readme: https://bitbucket.org/audacellc/emal-smartcontracts-sails-api
- Update all contracts to latest solidity version ^0.4.24 and fix compatibility issues.


### TOKEN SMART CONTRACTS

REFERENCE URLs:

- https://openzeppelin.org/api/docs/token_ERC20_StandardToken.html
- https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729


CHANGELOG:

- [x] Splitting Token contracts into StandardToken and EmalToken, deployment will take more gas, but allows flexibility to upgrade ERC20 function definitions for token. [Not changed]
- [x] Added division functionality to SafeMath, will need in VestingContract token where percentages of time periods will be calculated by the smart contract.
- [x] Mapping ‘allowed’ should be internal. [Not Changed]
- [x] Added more documentation in StandardToken.sol [Todo @tushar]
- [x] Updated transfer event in transferFrom() as msg.sender won't always be from address, and divided require statements to reduce gas costs.
- [x] Approve the passed address to spend the specified amount of tokens on behalf of msg.sender. Changing an allowance with this method brings the risk that someone may use both the old and the new allowance by unfortunate transaction ordering. To mitigate this race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards. Removed adding functionality in approve() function.
- [x] Allowed flexibility to increase and decrease allowance, without having to make two separate calls, saving gas.
- [x] Added Approval events as per ERC20 interface.
- [x] Set crowdsale addresses from token contract, define public ico tokens
- [x] Allow ownership transfer of token contract.
- [ ] Add minting functionality
- [ ] Add token burning functionality


### EMAL WHITELIST CONTRACT

REFERENCE URLs:

- https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/access/Whitelist.sol

CHANGELOG:

- [x] Updated Code documentation
- [x] Added access roles so that only admin can add and remove from Emal’s whitelist. This is done because the each investor has to complete their KYC procedure with Emal then only they are allowed to buy tokens. Prevent normal people from calling addtowhitelist directly.
- [x] Added a modifier onlyIfWhitelisted for easier access in function definition.
- [ ] Share same whitelist contract between presale and crowdsale.
- [ ] Add events to whitelist contract.


### EMAL CROWDSALE CONTRACT

REFERENCE URLs:

- https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/access/Whitelist.sol

CHANGELOG:

- [x] Made EmalCrowdsale of type Ownable
- [x] Updated code documentation.
- [x] Addition of new variables:
- [x] address public wallet: Address where funds are collected, Emal’s Ethereum wallet account where ether from investors are forwarded to.
- [x] uint256 public rate: How many token units an investor gets per wei.The rate is the conversion between wei and the smallest and indivisible token unit.
```
1 ether = 460 EmalTokens
10^18 wei = 460 EmalTokens
1 EmalTokens = 2,164,502,164,502,164 wei is the price of token
Rate = 0.00000000000000462
```
- [x] uint256 public weiRaised: amount raised by ether investments.
- [x] Contract constructor now initialises wallet address(where ether has to be forwarded to), token rate value and EmalToken contract address, but still the setToken() can be called at later stages hence preserving functionality and reducing complexity during the time when token address is not associated with the crowdsale contract.
- [x] Removed owner = msg.sender from constructor as owner already set.
- [x] Made parametres in Events indexed so that we are able to query the Event log with those variables as search terms.
- [x] Updated fallback function, can be used to buy tokens (provided present in whitelist) can also be used to return ether to allow refunds. revert payments if not in whitelist0.
- [x] Implemented contract states.
- [x] Internal rate calculation function to allow for discounts based on time.
- [x] uint256 public totalTokensSoldandAllocated: Amount of tokens that were sold to ether investors plus tokens allocated to investors by server for fiat and btc investments.
- [x] claimRefund() has been made callable by onlyOwner (might be changed in future)
- [x] softCap and hardCap limiting implemented
- [x] Time based crowdsale implemented.
- [x] mapping(address => uint256) etherInvestments: Investor contributions made in ether only.
- [x] Storing ether in smartcontract (coming from fallback function) is a really bad idea and has to be moved to Emal Business wallet.


### EMAL PRESALE

- [x] Same as EMALCrowdsale except no soft cap and refund functionality
- [x] Doesnt set start time for token transfers after presale goals, hardcap or time ended.

### EMAL VESTING FACTORY AND CONTRACT

- [x] StandardTokenVesting: A token holder contract that can release its token balance gradually like a typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
- [x] Factory is a software design pattern for creating instances of a class. Using this pattern simplifies creating new vesting contracts and saves transaction costs (“gas”). Instead of deploying a new TokenVesting contract for each team member, we deploy a single instance of TokenVestingFactory that ensures the creation of new token vesting contracts.
- [ ] Update vesting factory with more functionality.

![alt text](https://github.com/AudaceLLC/E-MAL-Crowdsale-Smart-Contracts/blob/master/VestingFactoryLayout.PNG?raw=true)
