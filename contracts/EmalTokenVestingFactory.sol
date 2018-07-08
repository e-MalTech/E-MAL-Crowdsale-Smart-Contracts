/* solium-disable security/no-block-members */

pragma solidity ^0.4.24;

import './StandardTokenVesting.sol';


/** @notice Factory is a software design pattern for creating instances of a class.
  * Using this pattern simplifies creating new vesting contracts and saves
  * transaction costs (“gas”). Instead of deploying a new TokenVesting contract
  * for each team member, we deploy a single instance of TokenVestingFactory
  * that ensures the creation of new token vesting contracts.
  */

contract EmalTokenVestingFactory is Ownable {
    event CreatedStandardVestingContract(StandardTokenVesting vesting);



    function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration) onlyOwner public returns (StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, _start, _cliff, _duration, true);
        emit CreatedStandardVestingContract(vesting);
        return vesting;
    }
    /** @dev Deploy EmalTokenVestingFactory, and use it to create vesting contracts
      * for founders, advisors and developers. after creation transfer Emal tokens
      * to those addresses and vesting vaults will be initialised.
      */
}
