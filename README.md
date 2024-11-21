# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
# Getting started:
```shell
git clone https://github.com/njdamstra/dynamic-NFT.git
cd dynamic-NFT
npm install // installs dependencies
touch .env // set up Environment Variables
npx hardhat compile // try to compile the contract
```
# What I've done so far:
Installed essential Packages:
1. Hardhat: npm install --save-dev hardhat
2. Ethers.js (for interacting with Ethereum): npm install --save-dev @nomiclabs/hardhat-ethers ethers
3. Dotenv (for environment variables): npm install dotenv

Set up Hardhat Project: npx hardhat --> sample JavaScript project

Set up .env file for Environment Variables

Set up Testing: npm install --save-dev mocha chai
- in each test file, include at the top: const { expect } = require("chai"); 

Installing additional dependencies as needed:
* OpenZeppelin contracts (provides secure smart contract templates): npm install @openzeppelin/contracts 
* Hardhat Plugins:
  * Hardhat-gas-report: npm install --save-dev hardhat-gas-reporter
  * solidity-coverage: npm install --save-dev solidity-coverage

Upgrading Plugins: npm install --save-dev _PLUGIN_NAME_/hardhat-upgrade (_PLUGIN_NAME_ = @openzeppelin)

Created a workflow in workflows/ci.yml using chatGPT which sets up Continuous Integration (CI)



# Handling errors with npm installations caused by dependencies:
![Screenshot 2024-11-20 at 5.31.18 PM.png](..%2F..%2F..%2F..%2F..%2Fvar%2Ffolders%2Fmz%2F5hpg9g8501s0v7gh8_ns8_f00000gn%2FT%2FTemporaryItems%2FNSIRD_screencaptureui_sCKwIQ%2FScreenshot%202024-11-20%20at%205.31.18%E2%80%AFPM.png)
General upstream dependency conflict error message for chai and hardhat-gas-reporter:
* npm error code ERESOLVE
* npm error ERESOLVE could not resolve
* npm error While resolving: _ROOT_USUALLY_IN_node_modules_/_PLUGIN_OR_DEPENDENCY_@_VERSION_ // has a requirement
  * While resolving: @nomicfoundation/hardhat-chai-matchers@2.0.8
  * While resolving: @nomicfoundation/hardhat-toolbox@5.0.0
* npm error Found: _DEPENDENCY@_CURR_VERSION_ // what's installed in our project
  * Found: chai@5.1.2
  * Found: hardhat-gas-reporter@2.2.1
* npm error Could not resolve dependency:
* npm error peer _DEPENDENCY@"^_NEEDED_VERSION_" from {While resolving:}
  * peer chai@"^4.2.0" from @nomicfoundation/hardhat-chai-matchers@2.0.8 // requires chai@^4.2.0
  * peer hardhat-gas-reporter@"^1.0.8" from @nomicfoundation/hardhat-toolbox@5.0.0 // requires hardhat-gas-reporter@^1.0.8
* npm error Conflicting peer dependency: _DEPENDENCY@_VERSION_
  * Conflicting peer dependency: chai@4.5.0
  * Conflicting peer dependency: hardhat-gas-reporter@1.0.10
* npm error Fix the upstream dependency conflict

Summary of error:
chai upstream dependency conflict: @nomicfoundation/hardhat-chai-matchers@2.0.8 requires chai@^4.2.0 who's parent is chai@4.5.0 but found chai@5.1.2
gas report dependency conflict: @nomicfoundation/hardhat-toolbox@5.0.0 requires hardhat-gas-reporter@^1.0.8 who's parent is @1.0.10 but found: hardhat-gas-reporter@2.2.1

Solution:
* npm uninstall _DEPENDENCY_ // uninstall current version of the dependency
  * chai
  * hardhat-gas-reporter
* npm install --save-dev _DEPENDENCY@^_REQUIRED_VERSION_ // install the correct dependency
  * chai@^4.2.0
  * hardhat-gas-reporter@^1.0.8
* npm list _DEPENDENCY_ // verify installed versions (the parent is usually what'll get installed)
* If you're still running into issues:
  * rm -rf node_modules 
  * rm package-lock.json // remove both these folders 
  * npm install // install those folders again
  * verify installed versions again
