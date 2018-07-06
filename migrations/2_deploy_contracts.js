var StandardToken = artifacts.require("./StandardToken.sol");
var EmalToken = artifacts.require("./EmalToken.sol");

module.exports = function(deployer) {
  deployer.deploy(StandardToken);
  deployer.link(StandardToken, EmalToken);
  deployer.deploy(EmalToken);
};
