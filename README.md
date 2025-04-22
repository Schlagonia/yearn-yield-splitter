# Yearn Yield Splitter

Earn your yield in your favorite shite coin or have your shite coins earn some real dough

### Build the project

```sh
make build
```

Run tests

```sh
make test
```

## Testing

Due to the nature of the BaseStrategy utilizing an external contract for the majority of its logic, the default interface for any tokenized strategy will not allow proper testing of all functions. Testing of your Strategy should utilize the pre-built [IStrategyInterface](https://github.com/yearn/tokenized-strategy-foundry-mix/blob/master/src/interfaces/IStrategyInterface.sol) to cast any deployed strategy through for testing, as seen in the Setup example. You can add any external functions that you add for your specific strategy to this interface to be able to test all functions with one variable.

Example:

```solidity
Strategy _strategy = new Strategy(asset, name);
IStrategyInterface strategy =  IStrategyInterface(address(_strategy));
```

Due to the permissionless nature of the tokenized Strategies, all tests are written without integration with any meta vault funding it. While those tests can be added, all V3 vaults utilize the ERC-4626 standard for deposit/withdraw and accounting, so they can be plugged in easily to any number of different vaults with the same `asset.`

Tests run in fork environment, you need to complete the full installation and setup to be able to run these commands.

```sh
make test
```

Run tests with traces (very useful)

```sh
make trace
```

Run specific test contract (e.g. `test/StrategyOperation.t.sol`)

```sh
make test-contract contract=StrategyOperationsTest
```

Run specific test contract with traces (e.g. `test/StrategyOperation.t.sol`)

```sh
make trace-contract contract=StrategyOperationsTest
```

See here for some tips on testing [`Testing Tips`](https://book.getfoundry.sh/forge/tests.html)

When testing on chains other than mainnet you will need to make sure a valid `CHAIN_RPC_URL` for that chain is set in your .env. You will then need to simply adjust the variable that RPC_URL is set to in the Makefile to match your chain.

To update to a new API version of the TokenizeStrategy you will need to simply remove and reinstall the dependency.

### Test Coverage

Run the following command to generate a test coverage:

```sh
make coverage
```

To generate test coverage report in HTML, you need to have installed [`lcov`](https://github.com/linux-test-project/lcov) and run:

```sh
make coverage-html
```

The generated report will be in `coverage-report/index.html`.

### Deployment

#### Contract Verification

Once the Strategy is fully deployed and verified, you will need to verify the TokenizedStrategy functions. To do this, navigate to the /#code page on Etherscan.

1. Click on the `More Options` drop-down menu
2. Click "is this a proxy?"
3. Click the "Verify" button
4. Click "Save"

This should add all of the external `TokenizedStrategy` functions to the contract interface on Etherscan.

## CI

This repo uses [GitHub Actions](.github/workflows) for CI. There are three workflows: lint, test and slither for static analysis.

To enable test workflow you need to add the `ETH_RPC_URL` secret to your repo. For more info see [GitHub Actions docs](https://docs.github.com/en/codespaces/managing-codespaces-for-your-organization/managing-encrypted-secrets-for-your-repository-and-organization-for-github-codespaces#adding-secrets-for-a-repository).

If the slither finds some issues that you want to suppress, before the issue add comment: `//slither-disable-next-line DETECTOR_NAME`. For more info about detectors see [Slither docs](https://github.com/crytic/slither/wiki/Detector-Documentation).

### Coverage

If you want to use [`coverage.yml`](.github/workflows/coverage.yml) workflow on other chains than mainnet, you need to add the additional `CHAIN_RPC_URL` secret.

Coverage workflow will generate coverage summary and attach it to PR as a comment. To enable this feature you need to add the [`GH_TOKEN`](.github/workflows/coverage.yml#L53) secret to your Github repo. Token must have permission to "Read and Write access to pull requests". To generate token go to [Github settings page](https://github.com/settings/tokens?type=beta). For more info see [GitHub Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
