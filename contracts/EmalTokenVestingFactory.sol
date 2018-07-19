/* solium-disable security/no-block-members */
pragma solidity ^ 0.4.24;

import './StandardTokenVesting.sol';


// // for mist wallet compatibility
// contract EmalToken {
//     // add function prototypes of only those used here
//     function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
//     function setStartTimeForTokenTransfers(uint _startTime) external;
// }




/** @notice Factory is a software design pattern for creating instances of a class.
 * Using this pattern simplifies creating new vesting contracts and saves
 * transaction costs ("gas"). Instead of deploying a new TokenVesting contract
 * for each team member, we deploy a single instance of TokenVestingFactory
 * that ensures the creation of new token vesting contracts.
 */

contract EmalTokenVestingFactory {

    mapping(address => StandardTokenVesting) vestingContractAddresses;

    // The token being sold
    EmalToken public token;

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

    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = EmalToken(_token);
    }

   /** @dev Deploy EmalTokenVestingFactory, and use it to create vesting contracts
     * for founders, advisors and developers. after creation transfer Emal tokens
     * to those addresses and vesting vaults will be initialised.
     */
    function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, uint256 noOfTokens) onlyOwner public returns(StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, _start, _cliff, _duration, true);

        vestingContractAddresses[_beneficiary] = vesting;
        emit CreatedStandardVestingContract(vesting);
        assert(token.transferFrom(owner, vesting, noOfTokens));

        return vesting;
    }

    function getVestingContractAddress(address _beneficiary) public view returns(address) {
        require(_beneficiary != address(0));
        require(vestingContractAddresses[_beneficiary] != address(0));

        return vestingContractAddresses[_beneficiary];
    }

    function releasableAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress( _beneficiary) != address(0));
        StandardTokenVesting vesting = StandardTokenVesting(getVestingContractAddress(_beneficiary));

        return vesting.releasableAmount(token);
    }

    function vestedAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        StandardTokenVesting vesting = StandardTokenVesting(getVestingContractAddress(_beneficiary));

        return vesting.vestedAmount(token);
    }

    function release(address _beneficiary) public returns(bool) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        StandardTokenVesting vesting = StandardTokenVesting(getVestingContractAddress(_beneficiary));

        return vesting.release(token);
    }


}
