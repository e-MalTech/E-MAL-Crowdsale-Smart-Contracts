/* solium-disable security/no-block-members */

pragma solidity ^0.4.24;

import './StandardTokenVesting.sol';


/** @notice Factory is a software design pattern for creating instances of a class.
  * Using this pattern simplifies creating new vesting contracts and saves
  * transaction costs (“gas”). Instead of deploying a new TokenVesting contract
  * for each team member, we deploy a single instance of TokenVestingFactory
  * that ensures the creation of new token vesting contracts.
  */

contract EmalTokenVestingFactory {

    mapping (address => address) vestingContractAddresses;

    // Owner of the token
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    event CreatedStandardVestingContract(StandardTokenVesting vesting);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }


    function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration) onlyOwner public returns (StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, _start, _cliff, _duration, true);

        vestingContractAddresses[_beneficiary] = vesting;
        emit CreatedStandardVestingContract(vesting);
        /** @dev Deploy EmalTokenVestingFactory, and use it to create vesting contracts
          * for founders, advisors and developers. after creation transfer Emal tokens
          * to those addresses and vesting vaults will be initialised.
          */
        return vesting;
    }

    function getVestingContractAddress() public view returns (address){
        // require(vestingContractAddresses[msg.sender]);

        return vestingContractAddresses[msg.sender];
    }
}
