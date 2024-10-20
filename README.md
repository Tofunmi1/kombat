## Kombat Smart Contracts

### Base sepolia


- `kombat : 0x6b89252fe6490AE1F61d59b7D07C93E45749eb62`
- `usdc base sepolia : 0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5`

## Built with foundry

install with

```bash
curl -L https://foundry.paradigm.xyz | bash
```

### Mint test USDC for interacting with Kombat

Run this command to mint test usdc for interacting with Kombat

```bash
forge script script/DeployUSDcPermit2.sol:MintUSDT --private-key $PRIVATE_KEY --broadcast --rpc-url $BASE_SEPOLIA_URL --slow -vvvvv
```

after editing the mintTo address in `script/DeployUSDCPermit2.sol`

```solidity
contract MintUSDc is Script {
    USDC internal usdc;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        usdc = USDC(0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5);
        usdc.mintTo(address(0xb13c76987B43674d3905eF1c1EdEBcA5CC18A6b4), 899 * 1e18);
        vm.stopBroadcast();
    }
}
```

## Test

```
forge test --mt `<test_name>` -vvvv --decode-internal
```

and run all tests with

```
forge test -vvvv
```
